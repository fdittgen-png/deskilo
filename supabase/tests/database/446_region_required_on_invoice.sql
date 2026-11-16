-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4105 (0792) -- the region a country's own invoices require is asked
-- before the invoice is issued: a party in the seller's own country without it
-- is refused (`seller_region`, `buyer_region`), a buyer abroad never is, and a
-- country whose invoices do not require it refuses nothing. The facts come
-- from postal_region_rules(), generated from the app's layouts. Rolled back.
begin;
select plan(13);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004105' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'region4105@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags)
values (pg_temp.u(101), 'Milano 4105', 'IT', 'EUR', 'Europe/Rome', pg_temp.u(1), 'not_subject', '{"invoicing": true}'),
       (pg_temp.u(102), 'Paris 4105', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'not_subject', '{"invoicing": true}'),
       (pg_temp.u(103), 'Boston 4105', 'US', 'USD', 'America/New_York', pg_temp.u(1), 'not_subject',
        '{"invoicing": true, "salesTax": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', now()),
       (pg_temp.u(202), pg_temp.u(102), pg_temp.u(1), true, true, 'active', now()),
       (pg_temp.u(203), pg_temp.u(103), pg_temp.u(1), true, true, 'active', now());

create function pg_temp.missing(p_ws int, p_seller jsonb, p_buyer jsonb) returns text[] language sql as $$
  select public.invoice_essentials_missing(pg_temp.u(p_ws), pg_temp.u(p_ws + 100),
    jsonb_build_object('seller', p_seller, 'buyer', p_buyer), '[]'::jsonb)
$$;
create function pg_temp.regions(p_ws int, p_seller jsonb, p_buyer jsonb) returns text language sql as $$
  select coalesce(string_agg(k, ',' order by k), '')
    from unnest(pg_temp.missing(p_ws, p_seller, p_buyer)) k
   where k in ('seller_region', 'buyer_region')
$$;

select is(public.postal_region_rules() -> 'IT' ->> 'invoice', 'true',
  'the server knows which countries require the region on an invoice');
select is(pg_temp.regions(101,
    '{"street": "Via Roma 2", "city": "Milano", "country": "IT"}',
    '{"name": "Cliente", "street": "Via Po 4", "city": "Torino", "country": "IT"}'),
  'buyer_region,seller_region',
  'an Italian seller and an Italian customer without a province: both refused');
select is(pg_temp.regions(101,
    '{"street": "Via Roma 2", "city": "Milano", "country": "IT", "subdivision": "MI"}',
    '{"name": "Cliente", "street": "Via Po 4", "city": "Torino", "country": "IT", "subdivision": "TO"}'),
  '', 'once each province is entered, nothing about a region is missing');
select is(pg_temp.regions(101,
    '{"street": "Via Roma 2", "city": "Milano", "country": "IT", "subdivision": "MI"}',
    '{"name": "Client", "street": "1 rue de la Paix", "city": "Paris", "country": "FR"}'),
  '', 'a customer abroad is never refused for a region');
select is(pg_temp.regions(101,
    '{"street": "Via Roma 2", "city": "Milano", "country": "IT", "subdivision": "MI"}',
    '{"name": "Cliente", "street": "Via Po 4", "city": "Torino"}'),
  'buyer_region', 'a customer whose address names no country is in the seller''s');
select is(pg_temp.regions(102,
    '{"street": "1 rue de la Paix", "city": "Paris", "country": "FR"}',
    '{"name": "Client", "street": "2 rue du Bac", "city": "Paris", "country": "FR"}'),
  '', 'a country whose invoices do not require a region refuses nothing');
select is(pg_temp.regions(103,
    '{"street": "1 Main St", "city": "Boston", "country": "US"}',
    '{"name": "Customer", "street": "2 Elm St", "city": "Boston", "country": "US"}'),
  'buyer_region,seller_region', 'under sales tax, the state of each American address is asked');
select is(pg_temp.regions(103,
    '{"street": "1 Main St", "city": "Boston", "country": "US", "subdivision": "MA"}',
    '{"name": "Customer", "street": "2 Elm St", "city": "Boston", "country": "US", "subdivision": "MA"}'),
  '', 'and once the states are entered, nothing about a region is missing');

-- ── the draft an issue would store, before the number is taken ──
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(301), pg_temp.u(102), 'Client', 'active', 100, 'blocked', '2026-01-01');
insert into public.managed_identities (workspace_id, member_id, identity)
values (pg_temp.u(102), pg_temp.u(301),
        public.managed_identity_clean('{"first_name": "Ada", "last_name": "Client", "street": "2 rue du Bac", "city": "Paris", "postal_code": "75007"}'));
update public.workspaces set street = '1 rue de la Paix', city = 'Paris', postal_code = '75002'
 where id = pg_temp.u(102);
delete from public.fee_bands where workspace_id = pg_temp.u(102);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (pg_temp.u(102), 0, 100, 3500, 1000);
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
set local role authenticated;
reset role;
-- what a dry run must leave as it was: every row it would write, the
-- document number's counter, and every sequence
create function pg_temp.trace() returns text language sql as $$
  select concat_ws('|',
    (select count(*) from public.invoices where workspace_id = pg_temp.u(102)),
    (select count(*) from public.events where workspace_id = pg_temp.u(102)),
    (select count(*) from public.invoice_issue_notices where workspace_id = pg_temp.u(102)),
    (select count(*) from public.ledger_entries where workspace_id = pg_temp.u(102)),
    (select coalesce(string_agg(journal || ':' || next_value, ',' order by journal), '')
       from public.number_sequences where workspace_id = pg_temp.u(102)),
    (select count(*) from net.http_request_queue),
    (select count(*) from storage.objects))
$$;
select set_config('t.before', pg_temp.trace(), true);
select set_config('t.seq_before', (select coalesce(sum(last_value), 0)::text
  from pg_sequences where schemaname = 'public' and sequencename <> 'invoice_qrr_seq'), true);
set local role authenticated;
select set_config('t.draft', public.invoice_issue_draft(pg_temp.u(102), pg_temp.u(301), '2026-09')::text, true);
reset role;
select is(pg_temp.trace(), current_setting('t.before'),
  'a dry run stores nothing: no invoice, event, notice, ledger entry, request or file, and the number counter is unchanged');
select is((select coalesce(sum(last_value), 0)::text from pg_sequences
            where schemaname = 'public' and sequencename <> 'invoice_qrr_seq'),
  current_setting('t.seq_before'), 'and it advances no sequence of the business''s records');
set local role authenticated;
select set_config('t.inv', public.create_invoice(pg_temp.u(102), pg_temp.u(301), '2026-09')::text, true);
reset role;
-- who may ask: the right to issue, refused before any buyer is read
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(2), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'mate4105@example.test', '', now(), now(), now());
insert into public.members (workspace_id, user_id, status, joined_at)
values (pg_temp.u(102), pg_temp.u(2), 'active', now());
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(2), 'role', 'authenticated')::text, true);
create function pg_temp.draft_err() returns text language plpgsql as $f$
begin
  execute 'set local role authenticated';
  perform public.invoice_issue_draft(pg_temp.u(102), pg_temp.u(301), '2026-09');
  execute 'reset role';
  return '';
exception when others then
  execute 'reset role';
  return sqlstate;
end $f$;
grant execute on function pg_temp.draft_err() to authenticated;
select is(pg_temp.draft_err(), 'DKN01', 'a member without the right to issue is refused the draft');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
select is(current_setting('t.draft')::jsonb -> 'missing', '[]'::jsonb,
  'the draft of an invoice that can be issued names nothing missing');
select is((select parties from public.invoices where id = current_setting('t.inv')::uuid),
  current_setting('t.draft')::jsonb -> 'parties',
  'the draft''s parties are the parties the issued invoice stores');

select * from finish();
rollback;
