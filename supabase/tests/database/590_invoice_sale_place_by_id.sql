-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4495 (0983): the goods of an invoice leave the place the business PICKED. Two sites each with a SHOP: the code alone does not say which,
-- so a code that matches both is named (never guessed) and the posting refuses until a place is picked; the id of Site B / SHOP picked as
-- the setting is the place the goods leave; a code that names exactly one place is stored as that place's id; a place archived, a virtual
-- place and a place of another business are refused when saved, and an archived pick is refused again when an invoice is posted. Rolled back.
begin;
select plan(11);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = message_text;
    v := 'ERR ' || sqlstate || ' ' || d;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
-- the owner sets the setting
create or replace function pg_temp.setp(p_value text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select (public.set_setting(%L, ''stock.invoice_sale_place'', %L::jsonb, '''')::jsonb ->> ''status'')', pg_temp.u(101), to_jsonb(p_value)::text))
$f$;
-- the place the invoice goods would leave: its id as text, or the problem
create or replace function pg_temp.pl() returns text language sql as $f$
  select coalesce(p.place_id::text, p.problem) from public.invoice_sale_place(pg_temp.u(101)) p
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'saleplace-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Sale place', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true, "configurableSettings": true}', '{}'),
  (pg_temp.u(102), 'Elsewhere', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
-- two sites, each with a SHOP, and a place with a code of its own
insert into public.stock_locations (id, workspace_id, parent_id, kind, code, name) values
  (pg_temp.u(501), pg_temp.u(101), null, 'site', 'SITE-A', 'Site A'),
  (pg_temp.u(502), pg_temp.u(101), null, 'site', 'SITE-B', 'Site B'),
  (pg_temp.u(511), pg_temp.u(101), pg_temp.u(501), 'zone', 'SHOP', 'Shop'),
  (pg_temp.u(512), pg_temp.u(101), pg_temp.u(502), 'zone', 'SHOP', 'Shop'),
  (pg_temp.u(513), pg_temp.u(101), pg_temp.u(502), 'zone', 'BACK', 'Back room'),
  (pg_temp.u(514), pg_temp.u(101), pg_temp.u(502), 'zone', 'OLD', 'Old room'),
  (pg_temp.u(521), pg_temp.u(102), null, 'site', 'SITE-X', 'Site X');

select is(pg_temp.pl(), (select id::text from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN'),
  'with no value the place MAIN every business starts with is where the goods leave (as before)');
update public.stock_locations set active = false where id = pg_temp.u(514);
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.invoice_sale_place', '"SHOP"'::jsonb);
select is(pg_temp.pl(), 'stock_sale_place_ambiguous', 'a legacy code that two places carry is named, never guessed');
delete from public.setting_values where key = 'stock.invoice_sale_place' and workspace_id = pg_temp.u(101);

select is(pg_temp.setp(pg_temp.u(512)::text), 'saved', 'the owner picks Site B / SHOP by its id');
select is(pg_temp.pl(), pg_temp.u(512)::text, 'the goods leave Site B / SHOP, not the one created first');
select like(pg_temp.setp('SHOP'), 'ERR 22023%place_ambiguous%', 'a code that two places carry is refused when saved');
select is(pg_temp.setp('BACK'), 'saved', 'a code that names one place is accepted');
select is((select value #>> '{}' from public.setting_values where key = 'stock.invoice_sale_place' and workspace_id = pg_temp.u(101) and valid_to is null),
  pg_temp.u(513)::text, 'and stored as that place''s id');
select like(pg_temp.setp(pg_temp.u(514)::text), 'ERR 22023%place_unusable%', 'an archived place is refused when saved');
select like(pg_temp.setp(pg_temp.u(521)::text), 'ERR 22023%place_unusable%', 'a place of another business is refused');
update public.stock_locations set active = false where id = pg_temp.u(513);
select is(pg_temp.pl(), 'stock_sale_place', 'a pick archived since is refused again when an invoice is posted, with its reason');
select is(pg_temp.setp(''), 'saved', 'an empty value is accepted: the code MAIN stays the default');

select * from finish();
rollback;
