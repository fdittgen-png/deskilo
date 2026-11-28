-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4518 (1003): a supplier has contacts, each with a role, and one preferred purchasing contact; it carries the commercial defaults
-- agreed once. A business starts with five roles and keeps its own list; a contact needs a name, a role of the business and a valid
-- e-mail (the preferred one has one); making another contact preferred swaps in one command; a retired contact is no longer the
-- preferred one; only whoever manages suppliers writes, and only while the contacts are on; a supplier of another business is refused;
-- whoever reads the suppliers reads the contacts, nobody else; the defaults are checked and read through one function. Rolled back.
begin;
select plan(21);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004518' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.run_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
create function pg_temp.role(p_ws int, p_code text) returns uuid language sql stable as $f$
  select id from public.supplier_contact_roles where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create function pg_temp.save(p_user int, p_ws int, p_body jsonb) returns text language sql as $f$
  select pg_temp.run_as(p_user, format('select public.supplier_contact_save_v1(%L, gen_random_uuid(), %L::jsonb)::text', pg_temp.u(p_ws), p_body))
$f$;
create function pg_temp.contact(p_supplier int, p_name text, p_role uuid, p_email text, p_preferred boolean default false) returns jsonb language sql as $f$
  select jsonb_build_object('supplier_id', pg_temp.u(p_supplier), 'name', p_name, 'role_id', p_role, 'email', p_email, 'preferred', p_preferred)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'supcon' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'Contacts 4518', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "supplyExpenses": true, "supplierContacts": true}'),
  (pg_temp.u(102), 'Other 4518', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "supplyExpenses": true, "supplierContacts": true}'),
  (pg_temp.u(103), 'Off 4518', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "supplyExpenses": true, "supplierContacts": false}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(204), pg_temp.u(103), pg_temp.u(1), true, true, 'active', '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  (pg_temp.u(301), pg_temp.u(101), '1', 'ACME Sarl'),
  (pg_temp.u(302), pg_temp.u(102), '1', 'Other Ltd'),
  (pg_temp.u(303), pg_temp.u(103), '1', 'Off Ltd');

select is((select string_agg(code, ',' order by sort_order) from public.supplier_contact_roles where workspace_id = pg_temp.u(101)),
  'orders,invoices,delivery,accounting,other', 'a business starts with five roles');

-- ── the contacts ──
select set_config('c.a', pg_temp.save(1, 101, pg_temp.contact(301, 'Ana Martin', pg_temp.role(101, 'orders'), 'ana@acme.test', true)), false);
select ok(current_setting('c.a') like '{%', 'the owner adds a preferred purchasing contact: ' || current_setting('c.a'));
select is(pg_temp.save(1, 101, pg_temp.contact(301, '  ', pg_temp.role(101, 'orders'), '')), 'ERR DKX02 name_required', 'a contact has a name');
select is(pg_temp.save(1, 101, pg_temp.contact(301, 'Bob', pg_temp.role(101, 'delivery'), 'not-an-address')), 'ERR DKX02 email_invalid', 'a malformed e-mail is refused');
select is(pg_temp.save(1, 101, pg_temp.contact(301, 'Bob', pg_temp.role(101, 'delivery'), '', true)), 'ERR DKX02 preferred_needs_email', 'the preferred purchasing contact has an e-mail');
select is(pg_temp.save(1, 101, pg_temp.contact(301, 'Bob', pg_temp.role(102, 'delivery'), 'bob@acme.test')), 'ERR DKX02 role_unknown', 'a role of another business is refused');
select is(pg_temp.save(1, 101, pg_temp.contact(302, 'Bob', pg_temp.role(101, 'delivery'), 'bob@acme.test')), 'ERR DKX02 supplier_unknown', 'and a supplier of another business');

select set_config('c.b', pg_temp.save(1, 101, pg_temp.contact(301, 'Bob Durand', pg_temp.role(101, 'delivery'), 'bob@acme.test', true)), false);
select is((select count(*) from public.supplier_contacts where supplier_id = pg_temp.u(301) and preferred), 1::bigint, 'making another contact preferred leaves one');
select is((select name from public.supplier_contacts where supplier_id = pg_temp.u(301) and preferred), 'Bob Durand', 'the new one');

-- ── who may ──
select is(pg_temp.save(2, 101, pg_temp.contact(301, 'Cy', pg_temp.role(101, 'other'), '')), 'ERR DKN01', 'a plain member cannot write');
select is(pg_temp.save(1, 103, pg_temp.contact(303, 'Cy', pg_temp.role(103, 'other'), '')), 'ERR DKN01', 'nor while the contacts are off');
select is(pg_temp.run_as(2, format('select count(*)::text from public.supplier_contacts where workspace_id = %L', pg_temp.u(101))), '0', 'and reads none');
select is(pg_temp.run_as(1, format('select count(*)::text from public.supplier_contacts where workspace_id = %L', pg_temp.u(101))), '2', 'the owner reads them');

-- ── retiring ──
select ok(pg_temp.run_as(1, format('select public.supplier_contact_retire_v1(%L, gen_random_uuid(), %L, true)::text', pg_temp.u(101), current_setting('c.b')::jsonb ->> 'id')) like '%"preferred": false%', 'a retired contact is no longer the preferred one');
select is((select count(*) from public.supplier_contacts where supplier_id = pg_temp.u(301) and preferred), 0::bigint, 'none is preferred');
select is(pg_temp.save(1, 101, jsonb_build_object('id', current_setting('c.b')::jsonb ->> 'id', 'preferred', true)), 'ERR DKX02 preferred_retired', 'a retired contact cannot be made preferred');

-- ── the roles ──
select set_config('r.a', pg_temp.run_as(1, format('select public.supplier_contact_role_save_v1(%L, gen_random_uuid(), ''{"label": "Quality"}'')::text', pg_temp.u(101))), false);
select ok(current_setting('r.a') like '{%', 'the owner adds a role');
select is(pg_temp.run_as(1, format('select public.supplier_contact_role_save_v1(%L, gen_random_uuid(), ''{"label": " quality "}'')::text', pg_temp.u(101))), 'ERR DKX02 label_taken', 'a name is kept once among the active roles');

-- ── the defaults ──
select ok(pg_temp.run_as(1, format($s$select public.save_supplier_terms_v1(%L, gen_random_uuid(), %L, '{"order_currency": "chf", "payment_term_days": 30, "order_lead_days": 5}')::text$s$, pg_temp.u(101), pg_temp.u(301))) like '%"order_currency": "CHF"%', 'the defaults are saved');
select is(pg_temp.run_as(1, format('select public.supplier_payment_term_days(%L)::text', pg_temp.u(301))), '30', 'the payment term is read through its one function');
select is(pg_temp.run_as(1, format($s$select public.save_supplier_terms_v1(%L, gen_random_uuid(), %L, '{"payment_term_days": 400}')::text$s$, pg_temp.u(101), pg_temp.u(301))), 'ERR DKX02 term_invalid', 'a term above a year is refused');

select * from finish();
rollback;
