-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2356: a 0 % line of a VAT-registered seller is what its own 0 % rate
-- says (Z zero-rated, E exempt), not O; a credit note takes the series the
-- owner saved for it; a rate in force while an invoice was issued changes
-- only as a new version. Real create_invoice runs, rolled back.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000235601';
  um uuid := '00000000-0000-4000-8000-000000235602';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@content2356.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@content2356.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Content 2356','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
           'vat_registered','FR12345678901','{"invoicing":true,"numberSequences":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','consumer') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Synthetic standard',20,true);
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name='Synthetic',last_name='Client',country_code='FR',
         street='2 rue du Test',city='Pézenas',postal_code='34120'
   where id = um;
  -- September: the subscription at 20 % and a supply priced at 0 %.
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',1000,'Zero-rated supply','2026-09',0);
  -- July and August: more money received than supplied — credit notes.
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period)
   values (ws,mm,'credit','payment',5000,'Advance','2026-07'),
          (ws,mm,'credit','payment',5000,'Advance','2026-08');
  perform set_config('deskilo.s.ws', ws::text, false);
  perform set_config('deskilo.s.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

-- ── the zero category ─────────────────────────────────────────────────
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'not_subject', '2026-09-30'),
          'O', 'a seller outside the scope: O');
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'exempt', '2026-09-30'),
          'E', 'an exempt seller: E');
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'vat_registered', '2026-09-30'),
          'O', 'a registered seller without a 0 % rate: O, which issuing refuses');

set local role authenticated;
select ok('vat_line_zero_unexplained' = any(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-09')),
          'no 0 % rate: the 0 % line is unexplained, as before');
reset role;

insert into public.vat_rates(workspace_id,label,percent,category,group_key)
 values (current_setting('deskilo.s.ws')::uuid,'Synthetic zero',0,'Z','zero');
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'vat_registered', '2026-09-30'),
          'Z', 'a registered seller with a zero-rated rate: Z');

insert into public.vat_rates(workspace_id,label,percent,category,group_key,exemption_reason)
 values (current_setting('deskilo.s.ws')::uuid,'Synthetic exempt',0,'E','exempt','Art. 261 CGI');
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'vat_registered', '2026-09-30'),
          'O', 'Z and E both at 0 %: the line cannot say which, so it is not guessed');
update public.vat_rates set valid_from = '2027-01-01'
 where workspace_id = current_setting('deskilo.s.ws')::uuid and label = 'Synthetic exempt';
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'vat_registered', '2026-09-30'),
          'Z', 'a rate not yet in force on the tax point does not count');
select is(public.vat_zero_category(current_setting('deskilo.s.ws')::uuid, 'vat_registered', '2027-01-31'),
          'O', 'from its first day it does');
update public.vat_rates set active = false
 where workspace_id = current_setting('deskilo.s.ws')::uuid and label = 'Synthetic exempt';

-- ── Z reaches the issued invoice ──────────────────────────────────────
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-09'), '{}'::text[],
          'a zero-rated line is explained by its rate');
select lives_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-09')$$, 'the month is issued');
reset role;
select is((select array_agg(t->>'category' order by (t->>'percent')::numeric desc) from public.invoices i,
             jsonb_array_elements(i.vat_totals) t
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-09'),
          array['S', 'Z'], 'vat_totals: S at 20 %, Z at 0 %');
select is((select l->>'vat_category' from public.invoices i, jsonb_array_elements(i.lines) l
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-09'
              and l->>'kind' = 'adjustment'),
          'Z', 'the 0 % line itself says Z');
select ok((select number like 'INV-%' from public.invoices
            where member_id = current_setting('deskilo.s.m')::uuid and period = '2026-09'),
          'an invoice takes the invoice series');

-- ── the credit-note series ────────────────────────────────────────────
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-07')$$, 'a credit note is issued');
reset role;
select ok((select total_cents < 0 and number like 'INV-%' from public.invoices
            where member_id = current_setting('deskilo.s.m')::uuid and period = '2026-07'),
          'no credit-note series saved: it takes an invoice number, as before');
insert into public.number_sequences(workspace_id, journal, prefix, date_part, reset)
 values (current_setting('deskilo.s.ws')::uuid, 'credit_note', 'AV-', 'year', 'yearly');
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-08')$$, 'the next credit note is issued');
reset role;
select ok((select total_cents < 0 and number like 'AV-%' from public.invoices
            where member_id = current_setting('deskilo.s.m')::uuid and period = '2026-08'),
          'the saved credit-note series numbers it');

-- ── a rate in force changes as a new version ──────────────────────────
set local role authenticated;
select throws_ok($$select public.set_vat_rates(current_setting('deskilo.s.ws')::uuid,
          (select jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label,
                    'percent', case when r.percent = 20 then 21 else r.percent end,
                    'category', r.category, 'group_key', r.group_key, 'is_default', r.is_default))
             from public.vat_rates r
            where r.workspace_id = current_setting('deskilo.s.ws')::uuid and r.active))$$,
          'DKV01', null, 'a percent on issued invoices is not edited in place');
select lives_ok($$select public.set_vat_rates(current_setting('deskilo.s.ws')::uuid,
          (select jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label || ' (renamed)',
                    'percent', r.percent,
                    'category', r.category, 'group_key', r.group_key, 'is_default', r.is_default))
             from public.vat_rates r
            where r.workspace_id = current_setting('deskilo.s.ws')::uuid and r.active))$$,
          'a rename is not a new value');
reset role;
insert into public.vat_rates(workspace_id,label,percent,valid_from,valid_to)
 values (current_setting('deskilo.s.ws')::uuid,'Synthetic old',19,'2020-01-01','2021-01-01');
set local role authenticated;
select lives_ok($$select public.set_vat_rates(current_setting('deskilo.s.ws')::uuid,
          (select jsonb_agg(jsonb_build_object('id', r.id, 'label', r.label,
                    'percent', case when r.label = 'Synthetic old' then 18 else r.percent end,
                    'category', r.category, 'group_key', r.group_key, 'is_default', r.is_default,
                    'valid_from', r.valid_from, 'valid_to', r.valid_to))
             from public.vat_rates r
            where r.workspace_id = current_setting('deskilo.s.ws')::uuid and r.active))$$,
          'a version no invoice was issued under is still corrected in place');
reset role;

select * from finish();
rollback;
