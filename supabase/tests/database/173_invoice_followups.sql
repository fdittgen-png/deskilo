-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2440: what an invoice states about an exemption and about a correction.
--   * the exemption reason of the seller's own exempt (E) 0 % rate is
--     frozen on the E total (BT-120 per category) and lifts
--     `vat_treatment_unreviewed`; a blank reason, two different reasons
--     and a buyer's own exemption do not;
--   * a Spanish replacement refuses without R1-R5 and freezes the code in
--     the parties; a first invoice stores none.
-- Rolled back.
begin;
select plan(14);

-- A French seller (VAT-registered) with a 20 % default and the E rates in
-- `reasons` (one 0 % E rate per entry; '' = a rate with no reason).
create or replace function pg_temp.seller(cc text, tag text, reasons text[] default null) returns uuid
language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid; r text; n int := 0;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@fu2440.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@fu2440.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags)
   values ('FU 2440 ' || tag, cc, 'EUR', 'Europe/Paris', uo, '1 Synthetic Street', 'Capital', '1000',
           'vat_registered', cc || '123456789', 'REG-' || cc, '{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','consumer') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Synthetic standard',20,true);
  foreach r in array coalesce(reasons, array[]::text[]) loop
    n := n + 1;
    insert into public.vat_rates(workspace_id,label,percent,category,group_key,exemption_reason)
     values (ws,'Synthetic exempt ' || n,0,'E','zero',r);
  end loop;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name='Synthetic',last_name='Customer',company='Customer Ltd',
         country_code=cc,street='2 Synthetic Street',city='Capital',postal_code='1000'
   where id = um;
  if reasons is not null then
    insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
     values (ws,mm,'charge','adjustment',1000,'Training','2026-09',0);
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;

create or replace function pg_temp.ws(mm uuid) returns uuid language sql as $q$
  select workspace_id from public.members where id = mm;
$q$;
-- Act as the owner of the member's space.
create or replace function pg_temp.act(mm uuid) returns void language sql as $q$
  select set_config('request.jwt.claims', json_build_object('sub',
    (select o.user_id from public.members o join public.members m on m.workspace_id = o.workspace_id
      where m.id = mm and o.is_owner limit 1), 'role','authenticated')::text, true) is null;
$q$;
create or replace function pg_temp.missing(mm uuid, reason text default '', repl uuid default null)
returns text[] language sql as $q$
  select public.invoice_issue_readiness(pg_temp.ws(mm), mm, '2026-09', 'full', repl, reason);
$q$;

-- ── exemption per rate ────────────────────────────────────────────────
select is(pg_temp.missing(pg_temp.seller('FR','e1',array['Formation professionnelle (art. 261 CGI)'])),
          '{}'::text[], 'a 0 % rate in the E category with its reason issues');
do $t$ declare mm uuid; begin
  mm := pg_temp.seller('FR','e2',array['Formation professionnelle (art. 261 CGI)']);
  perform public.create_invoice(pg_temp.ws(mm), mm, '2026-09');
  perform set_config('t.vt', (select vat_totals::text from public.invoices where member_id = mm), true);
end $t$;
select ok(current_setting('t.vt')::jsonb @> '[{"category":"E","percent":0,"exemption_reason":"Formation professionnelle (art. 261 CGI)"}]',
          'the reason is frozen on the E total');
select ok(not (current_setting('t.vt')::jsonb @> '[{"category":"S","exemption_reason":""}]')
          and not exists (select 1 from jsonb_array_elements(current_setting('t.vt')::jsonb) t
                           where t ->> 'category' = 'S' and t ? 'exemption_reason'),
          'the taxed total carries no reason');
select ok('vat_treatment_unreviewed' = any(pg_temp.missing(pg_temp.seller('FR','e3',array['']))),
          'an E rate with a blank reason stays unreviewed');
select ok('vat_treatment_unreviewed' = any(pg_temp.missing(pg_temp.seller('FR','e4',array['Art. 261 CGI','Art. 262 CGI']))),
          'two different reasons cannot be attributed to the line: unreviewed');
select ok('vat_treatment_unreviewed' = any(pg_temp.missing(pg_temp.seller('FR','e5',array['Art. 261 CGI','']))),
          'a second E rate without reason cannot be attributed either');
do $t$ declare mm uuid; begin
  mm := pg_temp.seller('FR','e6',array['Art. 261 CGI']);
  update public.members set vat_treatment = 'exempt', vat_exemption_reason = 'Buyer exempt' where id = mm;
  perform set_config('t.m6', mm::text, true);
end $t$;
select ok('vat_treatment_unreviewed' = any(pg_temp.missing(current_setting('t.m6')::uuid)),
          'a buyer''s own exemption never takes the rate''s reason: unreviewed');

-- ── the Spanish correction reason ─────────────────────────────────────
-- Spain waits for its national channel (0410), so the essentials are
-- stubbed here to see the correction rule on its own: what remains is
-- exactly the keys create_invoice itself adds.
create or replace function public.invoice_essentials_missing(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb, p_vat_totals jsonb)
returns text[] language sql as $stub$ select '{}'::text[] $stub$;
do $t$ declare mm uuid; begin
  -- the last seller seeded is the acting owner: es2 first
  perform set_config('t.es_first', pg_temp.seller('ES','es2')::text, true);
  mm := pg_temp.seller('ES','es1');
  perform set_config('t.es_mm', mm::text, true);
  perform set_config('t.es_orig', public.create_invoice(pg_temp.ws(mm), mm, '2026-09')::text, true);
end $t$;
select is(pg_temp.missing(current_setting('t.es_mm')::uuid, '', current_setting('t.es_orig')::uuid),
          array['correction_reason'], 'a Spanish replacement without a reason is refused');
select is(pg_temp.missing(current_setting('t.es_mm')::uuid, 'R9', current_setting('t.es_orig')::uuid),
          array['correction_reason'], 'a code outside R1-R5 is refused');
select is(pg_temp.missing(current_setting('t.es_mm')::uuid, 'r3', current_setting('t.es_orig')::uuid),
          '{}'::text[], 'R3 (lower case accepted) satisfies the rule');
select pg_temp.act(current_setting('t.es_first')::uuid);
select is(pg_temp.missing(current_setting('t.es_first')::uuid), '{}'::text[],
          'a first Spanish invoice is no correction: no reason asked');
select pg_temp.act(current_setting('t.es_mm')::uuid);
do $t$ declare r uuid; ws uuid; mm uuid := current_setting('t.es_mm')::uuid; begin
  ws := pg_temp.ws(mm);
  begin
    perform public.create_invoice(ws, mm, '2026-09', current_setting('t.es_orig')::uuid);
    perform set_config('t.es_refused', 'no', true);
  exception when sqlstate 'DKI01' then
    perform set_config('t.es_refused', 'yes', true);
  end;
  r := public.create_invoice(ws, mm, '2026-09', current_setting('t.es_orig')::uuid, false, 'full', false, '', '', 'R2');
  perform set_config('t.es_parties', (select parties::text from public.invoices where id = r), true);
end $t$;
select is(current_setting('t.es_refused'), 'yes', 'the replacement itself raises without a reason');
select is(current_setting('t.es_parties')::jsonb ->> 'correction_reason', 'R2',
          'the reason is frozen in the parties of the replacement');
select ok((select not (parties ? 'correction_reason') from public.invoices where id = current_setting('t.es_orig')::uuid),
          'the original invoice carries none');

select * from finish();
rollback;
