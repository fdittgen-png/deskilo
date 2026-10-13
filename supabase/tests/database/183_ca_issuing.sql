-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2361 (0423-0426): a Canadian workspace issues. One real create_invoice per
-- scene against a CA seller in Canadian dollars: Ontario at HST 13 %, Quebec
-- at GST 5 % + QST 9.975 % (CAD 1 000.00 -> 50.00 + 99.75 = 1 149.75, both
-- numbers frozen on the invoice), British Columbia at GST alone, a small
-- supplier that charges nothing, and the refusals (a business number without
-- its RT account, a Quebec invoice without the QST number, US dollars, a
-- small supplier asked to charge). Then the return: the QST line of the
-- summary and the federal figures of the GST34. Rolled back.
begin;
select plan(20);

create or replace function pg_temp.seller(
  tag text, currency text, vat_id text, legal_id text, pct numeric, amount int,
  regime text default 'vat_registered'
) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@ca2361g.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@ca2361g.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags,invoice_legal)
   values ('CA 2361g ' || tag, 'CA', currency, 'America/Toronto', uo, '100 Main St', 'Montreal', 'H2X 1Y4',
           regime, vat_id, legal_id, '{"invoicing":true}', '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Rate',pct,true);
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer Ltd',
         country_code='CA', street = '200 King St', city = 'Toronto', postal_code='M5H 1J9'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',amount,'Desk licence','2026-09',pct);
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

-- ── Ontario: HST 13 % ─────────────────────────────────────────────────
select set_config('ca.on', pg_temp.seller('on', 'CAD', '123456789 RT0001', '', 13, 11300)::text, true);
select is(pg_temp.issue(current_setting('ca.on')::uuid), '', 'an Ontario seller issues');
select is((select string_agg(c ->> 'scheme' || ':' || (c ->> 'tax_cents'), ' ')
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('ca.on')::uuid)).vat_totals -> 0 -> 'components') c),
          'HST:1300', 'the HST is one component of 13.00 on 100.00');
select is((pg_temp.invoice_of(current_setting('ca.on')::uuid)).currency, 'CAD', 'in Canadian dollars');

-- ── Quebec: GST 5 % + QST 9.975 % on CAD 1 000.00 ─────────────────────
select set_config('ca.qc', pg_temp.seller('qc', 'CAD', '123456789 RT0001', '1234567890 TQ0001', 14.975, 114975)::text, true);
select is(pg_temp.issue(current_setting('ca.qc')::uuid), '', 'a Quebec seller with both numbers issues');
select is((select string_agg(c ->> 'scheme' || ':' || (c ->> 'tax_cents'), ' ' order by o)
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).vat_totals -> 0 -> 'components')
                  with ordinality t(c, o)),
          'GST:5000 QST:9975', 'GST 50.00 and QST 99.75');
select is((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).total_cents, 114975, 'the total is 1 149.75');
select is((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).vat_totals -> 0 ->> 'net_cents', '100000', 'on a net of 1 000.00');
select is((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).parties -> 'seller' ->> 'vat_id', '123456789 RT0001', 'the GST/HST number is on the invoice');
select is((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).parties -> 'seller' ->> 'legal_id', '1234567890 TQ0001', 'and the QST number beside it');
select is((pg_temp.invoice_of(current_setting('ca.qc')::uuid)).legal_snapshot ->> 'seller_country', 'CA', 'the seller country is frozen');

-- ── British Columbia: GST alone on a desk ─────────────────────────────
select set_config('ca.bc', pg_temp.seller('bc', 'CAD', '123456789 RT0001', '', 5, 10500)::text, true);
select is(pg_temp.issue(current_setting('ca.bc')::uuid), '', 'a British Columbia seller issues');
select is((select string_agg(c ->> 'scheme', '+')
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('ca.bc')::uuid)).vat_totals -> 0 -> 'components') c),
          'GST', 'GST alone, no provincial sales tax on a desk');

-- ── a small supplier charges nothing ──────────────────────────────────
select set_config('ca.small', pg_temp.seller('small', 'CAD', '', '', 0, 5000, 'exempt')::text, true);
select is(pg_temp.issue(current_setting('ca.small')::uuid), '', 'a small supplier issues');
select is((select coalesce(sum((t ->> 'vat_cents')::int), 0)::int
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('ca.small')::uuid)).vat_totals) t),
          0, 'and charges no tax');

-- ── the return ────────────────────────────────────────────────────────
select is((select l -> 'components' -> 1 ->> 'tax_cents'
             from public.vat_return_summary((select workspace_id from public.members where id = current_setting('ca.qc')::uuid),
                                            '2026-09-01', '2026-12-31') s, jsonb_array_elements(s.lines) l
            where (l ->> 'percent')::numeric = 14.975),
          '9975', 'the return states the QST apart');
select is((select sum((c ->> 'tax_cents')::int)::int
             from public.vat_return_summary((select workspace_id from public.members where id = current_setting('ca.qc')::uuid),
                                            '2026-09-01', '2026-12-31') s, jsonb_array_elements(s.lines) l,
                  jsonb_array_elements(l -> 'components') c where c ->> 'scheme' = 'GST'),
          5000, 'and the GST apart');

-- ── the refusals ──────────────────────────────────────────────────────
select ok(pg_temp.issue(pg_temp.seller('badbn', 'CAD', '123456789', '', 5, 10500)) like '%seller_bn_format%',
          'a business number without its RT account is refused');
select ok(pg_temp.issue(pg_temp.seller('noqst', 'CAD', '123456789 RT0001', '', 14.975, 114975)) like '%seller_qst_number%',
          'a Quebec invoice without the QST number is refused');
select ok(pg_temp.issue(pg_temp.seller('usd', 'USD', '123456789 RT0001', '', 5, 10500)) like '%vat_national_currency%',
          'GST in US dollars is refused: the return is in Canadian dollars');
select ok(pg_temp.issue(pg_temp.seller('smallcharge', 'CAD', '', '', 5, 10500, 'exempt')) like '%vat_charged_not_registered%',
          'a small supplier never issues a line with tax on it');
select * from finish();
rollback;
