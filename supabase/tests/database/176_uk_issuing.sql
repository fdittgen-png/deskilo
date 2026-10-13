-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2359 (0417-0419): a UK workspace issues. One real create_invoice per
-- scene against a GB seller in pounds: land taxed by the owner's option
-- (20 %, the VRN and the frozen option on the invoice), land exempt without
-- it (E, the Schedule 9 reason frozen), a less detailed invoice up to
-- GBP 250 with no customer on file, and the refusals (a VRN of the wrong
-- shape, euros). Then a credit note and the return: compute_vat_return
-- keeps the credit note on its own line and Box 1 is the VAT of both.
-- Rolled back.
begin;
select plan(14);

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
           'owner-' || tag || '@uk2359g.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@uk2359g.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags,invoice_legal)
   values ('UK 2359g ' || tag, 'GB', currency, 'Europe/London', uo, '1 High Street', 'London', 'N1 1AA',
           'vat_registered', vat_id, '12345678', '{"invoicing":true}', legal)
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Standard 20 %',20,true);
  insert into public.vat_rates(workspace_id,label,percent,category,group_key) values (ws,'Zero 0 %',0,'Z','zero');
  if with_exempt then
    insert into public.vat_rates(workspace_id,label,percent,category,group_key,exemption_reason)
     values (ws,'Exempt (land)',0,'E','exempt','VAT Act 1994, Schedule 9, Group 1 (land)');
  end if;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name = case when named_buyer then 'Synthetic' else '' end,
         last_name = case when named_buyer then 'Customer' else '' end,
         company = case when named_buyer then 'Customer Ltd' else '' end,
         country_code='GB', street = case when named_buyer then '2 Low Road' else '' end,
         city = case when named_buyer then 'Leeds' else '' end, postal_code='LS1 1AA'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',amount,'Desk licence','2026-09',20);
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

-- ── land taxed by the option ──────────────────────────────────────────
select set_config('uk.opt', pg_temp.seller('opt', 'GBP', 'GB123456789',
  '{"option_to_tax":true,"option_to_tax_date":"2020-01-01","option_to_tax_reference":"HMRC/1"}'::jsonb)::text, true);
select is(pg_temp.issue(current_setting('uk.opt')::uuid), '', 'a UK seller that opted to tax issues');
select is((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).currency, 'GBP', 'in pounds sterling');
select ok(exists (select 1 from jsonb_array_elements((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).vat_totals) t
                   where t ->> 'category' = 'S' and (t ->> 'percent')::numeric = 20),
          'the desk licence carries 20 % VAT');
select is((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).legal_snapshot -> 'land_taxation' ->> 'option_to_tax_reference',
          'HMRC/1', 'the option it was issued under is frozen on the invoice');
select is((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).legal_snapshot ->> 'seller_country', 'GB',
          'the seller country is frozen');

-- ── the credit note and the return ────────────────────────────────────
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name,
                             signature, kind, issued_at, vat_totals, legal_snapshot)
select i.workspace_id, i.member_id, i.member_id, 'CN-UK-1', 'Credit',
       '[{"label": "Refund", "amount_cents": -2400, "vat_percent": 20}]',
       -2400, 'GBP', 'M', 'UK', 'M', 's', 'full', '2026-09-20 10:00+00',
       '[{"percent": 20, "category": "S"}]', i.legal_snapshot
  from public.invoices i where i.member_id = current_setting('uk.opt')::uuid and i.period = '2026-09';
select is((select count(*)::int from public.compute_vat_return(
             (select workspace_id from public.members where id = current_setting('uk.opt')::uuid),
             '2026-01-01', '2099-12-31') where direction = 'output' and credit_note),
          1, 'the credit note is on its own line of the return');
select is((select sum(vat_cents)::int from public.compute_vat_return(
             (select workspace_id from public.members where id = current_setting('uk.opt')::uuid),
             '2026-01-01', '2099-12-31') where direction = 'output'),
          ((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).total_cents
             - round((pg_temp.invoice_of(current_setting('uk.opt')::uuid)).total_cents / 1.2)::int) - 400,
          'Box 1 is the VAT of the invoice less the VAT of the credit note');

-- ── land exempt without the option ────────────────────────────────────
select set_config('uk.exempt', pg_temp.seller('exempt', 'GBP', 'GB123456789', '{}'::jsonb, with_exempt => true)::text, true);
select is(pg_temp.issue(current_setting('uk.exempt')::uuid), '', 'a bare desk licence issues without the option');
select ok(exists (select 1 from jsonb_array_elements((pg_temp.invoice_of(current_setting('uk.exempt')::uuid)).vat_totals) t
                   where t ->> 'category' = 'E' and t ->> 'exemption_reason' like '%Schedule 9%'),
          'it is exempt, with the Schedule 9 reason frozen on the total');
select is((select count(*)::int from jsonb_array_elements((pg_temp.invoice_of(current_setting('uk.exempt')::uuid)).vat_totals) t
            where t ->> 'category' = 'S' and (t ->> 'vat_cents')::int > 0), 0, 'and no VAT is charged on the land');
select ok(pg_temp.issue(pg_temp.seller('noexempt', 'GBP', 'GB123456789', '{}'::jsonb)) like '%vat_treatment_unreviewed%',
          'without the option and without an exempt rate the land is refused, never taxed');

-- ── the less detailed invoice ─────────────────────────────────────────
select is(pg_temp.issue(pg_temp.seller('small', 'GBP', 'GB123456789',
  '{"option_to_tax":true}'::jsonb, named_buyer => false, amount => 1000)), '',
  'up to GBP 250 an invoice needs no customer name or address');

-- ── the refusals ──────────────────────────────────────────────────────
select ok(pg_temp.issue(pg_temp.seller('badvrn', 'GBP', 'GB12345', '{"option_to_tax":true}'::jsonb)) like '%seller_vat_id_format%',
          'a VRN of the wrong shape is refused');
select ok(pg_temp.issue(pg_temp.seller('euros', 'EUR', 'GB123456789', '{"option_to_tax":true}'::jsonb)) like '%vat_national_currency%',
          'VAT in euros is refused: it is stated in sterling');
select * from finish();
rollback;
