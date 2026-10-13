-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2360 (0420-0422): a Swiss workspace issues. One real create_invoice per
-- scene against a CH seller in francs: a package taxed at 8.1 % (the UID
-- with its MWST suffix and the letting frozen on the invoice), a bare
-- letting exempt with the art. 21 reason, the same letting taxed by the
-- option of art. 22, and the refusals (a UID of the wrong shape or check
-- digit, euros, a bare letting with no exempt rate). Then a credit note and
-- the return: compute_vat_return keeps the credit note on its own line and
-- the tax is that of both. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.seller(
  tag text, currency text, vat_id text, legal jsonb, with_exempt boolean default false,
  named_buyer boolean default true, amount int default 10000
) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@ch2360g.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@ch2360g.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags,invoice_legal)
   values ('CH 2360g ' || tag, 'CH', currency, 'Europe/Zurich', uo, 'Rue du Lac 1', 'Biel', '2501',
           'vat_registered', vat_id, 'CHE-109.322.551', '{"invoicing":true}', legal)
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Normal 8,1 %',8.1,true);
  insert into public.vat_rates(workspace_id,label,percent,category,group_key) values (ws,'Zero 0 %',0,'Z','zero');
  if with_exempt then
    insert into public.vat_rates(workspace_id,label,percent,category,group_key,exemption_reason)
     values (ws,'Ausgenommen (Vermietung)',0,'E','exempt','Von der Steuer ausgenommen (Art. 21 Abs. 2 Ziff. 21 MWSTG)');
  end if;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name = case when named_buyer then 'Synthetic' else '' end,
         last_name = case when named_buyer then 'Customer' else '' end,
         company = case when named_buyer then 'Customer Ltd' else '' end,
         country_code='CH', street = case when named_buyer then 'Grosse Marktgasse 28' else '' end,
         city = case when named_buyer then 'Rorschach' else '' end, postal_code='9400'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',amount,'Desk licence','2026-09',8.1);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;

create or replace function pg_temp.issue(mm uuid) returns text language plpgsql as $q$
begin
  perform public.create_invoice((select workspace_id from public.members where id = mm), mm, '2026-09');
  return '';
exception when others then
  return coalesce(sqlerrm, '') || ' ' || coalesce(
    (select '[' || string_agg(x, ',') || ']' from unnest(public.invoice_issue_readiness(
       (select workspace_id from public.members where id = mm), mm, '2026-09')) x), '');
end;
$q$;

create or replace function pg_temp.invoice_of(mm uuid) returns public.invoices language sql as $q$
  select i.* from public.invoices i where i.member_id = mm and i.period = '2026-09';
$q$;

-- ── a package, taxed ──────────────────────────────────────────────────
select set_config('ch.pkg', pg_temp.seller('pkg', 'CHF', 'CHE-109.322.551 MWST', '{}'::jsonb)::text, true);
select is(pg_temp.issue(current_setting('ch.pkg')::uuid), '', 'a Swiss seller with a package issues');
select is((pg_temp.invoice_of(current_setting('ch.pkg')::uuid)).currency, 'CHF', 'in francs');
select ok(exists (select 1 from jsonb_array_elements((pg_temp.invoice_of(current_setting('ch.pkg')::uuid)).vat_totals) t
                   where t ->> 'category' = 'S' and (t ->> 'percent')::numeric = 8.1),
          'the desk package carries 8.1 % MWST');
select is((pg_temp.invoice_of(current_setting('ch.pkg')::uuid)).legal_snapshot -> 'land_taxation' ->> 'bare_letting',
          'false', 'the letting it was issued under is frozen on the invoice');
select is((pg_temp.invoice_of(current_setting('ch.pkg')::uuid)).legal_snapshot ->> 'seller_country', 'CH',
          'the seller country is frozen');

-- ── the credit note and the return ────────────────────────────────────
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name,
                             signature, kind, issued_at, vat_totals, legal_snapshot)
select i.workspace_id, i.member_id, i.member_id, 'CN-CH-1', 'Credit',
       '[{"label": "Refund", "amount_cents": -2400, "vat_percent": 8.1}]',
       -2400, 'CHF', 'M', 'CH', 'M', 's', 'full', '2026-09-20 10:00+00',
       '[{"percent": 8.1, "category": "S"}]', i.legal_snapshot
  from public.invoices i where i.member_id = current_setting('ch.pkg')::uuid and i.period = '2026-09';
select is((select count(*)::int from public.compute_vat_return(
             (select workspace_id from public.members where id = current_setting('ch.pkg')::uuid),
             '2026-01-01', '2099-12-31') where direction = 'output' and credit_note),
          1, 'the credit note is on its own line of the return');
select is((select sum(vat_cents)::int from public.compute_vat_return(
             (select workspace_id from public.members where id = current_setting('ch.pkg')::uuid),
             '2026-01-01', '2099-12-31') where direction = 'output' and not credit_note),
          (select sum((t ->> 'vat_cents')::int)::int from jsonb_array_elements(
             (pg_temp.invoice_of(current_setting('ch.pkg')::uuid)).vat_totals) t),
          'the return carries the tax the invoice states');
select ok((select sum(vat_cents) from public.compute_vat_return(
             (select workspace_id from public.members where id = current_setting('ch.pkg')::uuid),
             '2026-01-01', '2099-12-31') where direction = 'output' and credit_note) < 0,
          'and the credit note takes tax off it');

-- ── a bare letting, exempt; opted, taxed ──────────────────────────────
select set_config('ch.bare', pg_temp.seller('bare', 'CHF', 'CHE-109.322.551 MWST',
  '{"letting_kind":"bare"}'::jsonb, with_exempt => true)::text, true);
select is(pg_temp.issue(current_setting('ch.bare')::uuid), '', 'a bare letting issues');
select ok(exists (select 1 from jsonb_array_elements((pg_temp.invoice_of(current_setting('ch.bare')::uuid)).vat_totals) t
                   where t ->> 'category' = 'E' and t ->> 'exemption_reason' like '%Art. 21 Abs. 2 Ziff. 21%'),
          'it is exempt, with the art. 21 reason frozen on the total');
select is((select count(*)::int from jsonb_array_elements((pg_temp.invoice_of(current_setting('ch.bare')::uuid)).vat_totals) t
            where t ->> 'category' = 'S' and (t ->> 'vat_cents')::int > 0), 0, 'and no MWST is charged on the rooms');
select ok(pg_temp.issue(pg_temp.seller('noexempt', 'CHF', 'CHE-109.322.551 MWST', '{"letting_kind":"bare"}'::jsonb)) like '%vat_treatment_unreviewed%',
          'a bare letting with no exempt rate is refused, never taxed');
select set_config('ch.opt', pg_temp.seller('opt', 'CHF', 'CHE-109.322.551 MWST',
  '{"letting_kind":"bare","option_to_tax":true,"option_to_tax_date":"2020-01-01"}'::jsonb, with_exempt => true)::text, true);
select is(pg_temp.issue(current_setting('ch.opt')::uuid), '', 'a bare letting with the option of art. 22 issues');
select is((pg_temp.invoice_of(current_setting('ch.opt')::uuid)).legal_snapshot -> 'land_taxation' ->> 'option_to_tax_date',
          '2020-01-01', 'taxed, and the option it was issued under is frozen');

-- ── the refusals ──────────────────────────────────────────────────────
select ok(pg_temp.issue(pg_temp.seller('baduid', 'CHF', 'CHE-109.322.552 MWST', '{}'::jsonb)) like '%seller_uid_format%',
          'a UID with a wrong check digit is refused');
select ok(pg_temp.issue(pg_temp.seller('nosuffix', 'CHF', 'CHE-109.322.551', '{}'::jsonb)) like '%seller_uid_format%',
          'a UID without the MWST suffix is refused');
select ok(pg_temp.issue(pg_temp.seller('euros', 'EUR', 'CHE-109.322.551 MWST', '{}'::jsonb)) like '%vat_national_currency%',
          'MWST in euros is refused: the return is in francs');
select * from finish();
rollback;
