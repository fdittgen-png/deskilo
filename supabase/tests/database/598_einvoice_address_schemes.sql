-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4501 (0990): an e-invoicing address is stored under a scheme of the list and with an identifier of that scheme's
-- form, for a customer (set_member_einvoice_address) and for the business itself (workspaces.invoice_legal). An unknown
-- scheme or an identifier of another form is refused with its reason; an address stored before, under a scheme the
-- list does not offer, is kept as it is until it is changed. Rolled back.
begin;
select plan(16);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.err(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql;
    v := 'ok';
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.addr(p_scheme text, p_id text) returns text language sql as $f$
  select pg_temp.err(pg_temp.u(1), format('select public.set_member_einvoice_address(%L, %L, %L, %L)',
    pg_temp.u(202), p_id, p_scheme, ''))
$f$;
create or replace function pg_temp.legal(p_scheme text, p_id text) returns text language sql as $f$
  select pg_temp.err(pg_temp.u(1), format(
    'update public.workspaces set invoice_legal = invoice_legal || jsonb_build_object(%L, %L, %L, %L) where id = %L',
    'einvoice_endpoint_scheme', p_scheme, 'einvoice_endpoint_id', p_id, pg_temp.u(101)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'teas-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'E-address schemes FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"moneyTab": true, "invoicing": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');

-- the list
select is(public.einvoice_scheme_pattern(' 0009 '), '[0-9]{14}', 'the SIRET scheme has its form');
select is(public.einvoice_scheme_pattern('XX99'), null, 'a scheme the list does not offer has none');
select is(public.einvoice_address_refusal('0204', '991-33333TEST-33', '', ''), null, 'a Leitweg-ID of its form is accepted');
select is(public.einvoice_address_refusal('em', 'billing@example.org', '', ''), null, 'so is an e-mail address');
select is(public.einvoice_address_refusal('', '', '', ''), null, 'no address is no refusal');

-- a customer's address
select is(pg_temp.addr('0009', '73282932000074'), 'ok', 'a customer''s SIRET is stored');
select is((select einvoice_endpoint_scheme || ':' || einvoice_endpoint_id from public.members where id = pg_temp.u(202)),
  '0009:73282932000074', 'under its scheme');
select is(pg_temp.addr('XX99', '73282932000074'), 'ERR DKL02 {"reason": "scheme"}', 'an unknown scheme is refused');
select is(pg_temp.addr('0009', '7328293200'), 'ERR DKL02 {"reason": "identifier"}', 'so is an identifier of another form');
update public.members set einvoice_endpoint_scheme = 'ZZ01', einvoice_endpoint_id = 'legacy-42' where id = pg_temp.u(202);
select is(pg_temp.err(pg_temp.u(1), format('select public.set_member_einvoice_address(%L, %L, %L, %L)',
  pg_temp.u(202), 'legacy-42', 'zz01', '75')), 'ok', 'an address stored before, under a scheme no longer offered, is kept');
select is(pg_temp.addr('ZZ01', 'legacy-43'), 'ERR DKL02 {"reason": "scheme"}', 'until it is changed');

-- the business's own address
select is(pg_temp.legal('0225', '732829320'), 'ok', 'the business''s address under the directory scheme is stored');
select is(pg_temp.legal('0225', '7328'), 'ERR DKL02 {"reason": "identifier"}', 'one of another form is refused');
select is(pg_temp.legal('QQ', '732829320'), 'ERR DKL02 {"reason": "scheme"}', 'and one under an unknown scheme');
-- an address stored before the list (the guard is off for the seed only)
set session_replication_role = replica;
update public.workspaces set invoice_legal = invoice_legal || '{"einvoice_endpoint_scheme": "ZZ01", "einvoice_endpoint_id": "old"}'
 where id = pg_temp.u(101);
set session_replication_role = origin;
select is(pg_temp.err(pg_temp.u(1), format('update public.workspaces set invoice_legal = invoice_legal || %L where id = %L',
  '{"contact_email": "ap@example.org"}', pg_temp.u(101))), 'ok', 'a legal identity whose stored address is not of the list still saves');
select is((select invoice_legal ->> 'einvoice_endpoint_id' from public.workspaces where id = pg_temp.u(101)), 'old',
  'and keeps that address');

select * from finish();
rollback;
