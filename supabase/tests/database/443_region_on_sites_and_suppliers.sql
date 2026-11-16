-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3649 (0789) -- a site and a supplier keep the region of their address: it is
-- stored as its code, a save that does not send it keeps the one stored, and a
-- save that sends an empty one clears it. Every call names its arguments,
-- as the app does, with and without p_subdivision. Rolled back.
begin;
select plan(8);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000036496a1', '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'region-sites@deskilo.test', '', now(), now(), now());

create function pg_temp.act() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '00000000-0000-4000-8000-0000036496a1', 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.act();
select set_config('t.ws', public.create_workspace('Region sites', 'IT', 'EUR', 'Europe/Rome', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"multiSite": true, "supplyExpenses": true}'
 where id = current_setting('t.ws')::uuid;

-- ── a site ──
select pg_temp.act();
select set_config('t.site', public.upsert_site(p_workspace_id => current_setting('t.ws')::uuid, p_id => null, p_name => 'Brera', p_street => 'Via Brera 7',
  p_postal_code => '20121', p_city => 'Milano', p_country_code => 'IT', p_legal_id => '', p_subdivision => ' mi ')::text, true);
reset role;
select is((select subdivision from public.sites where id = current_setting('t.site')::uuid), 'MI',
  'a new site keeps its region as a code');
select pg_temp.act();
select public.upsert_site(p_workspace_id => current_setting('t.ws')::uuid, p_id => current_setting('t.site')::uuid, p_name => 'Brera', p_street => 'Via Brera 9',
  p_postal_code => '20121', p_city => 'Milano', p_country_code => 'IT', p_legal_id => '');
reset role;
select is((select (street, subdivision)::text from public.sites where id = current_setting('t.site')::uuid),
  '("Via Brera 9",MI)', 'a save that does not send the region keeps the one stored');
select pg_temp.act();
select public.upsert_site(p_workspace_id => current_setting('t.ws')::uuid, p_id => current_setting('t.site')::uuid, p_name => 'Brera', p_street => 'Via Brera 9',
  p_postal_code => '20121', p_city => 'Milano', p_country_code => 'IT', p_legal_id => '', p_subdivision => 'MB');
reset role;
select is((select subdivision from public.sites where id = current_setting('t.site')::uuid), 'MB',
  'a save that sends one replaces it');
select pg_temp.act();
select public.upsert_site(p_workspace_id => current_setting('t.ws')::uuid, p_id => current_setting('t.site')::uuid, p_name => 'Brera', p_street => 'Via Brera 9',
  p_postal_code => '20121', p_city => 'Milano', p_country_code => 'IT', p_legal_id => '', p_subdivision => '');
reset role;
select is((select subdivision from public.sites where id = current_setting('t.site')::uuid), '',
  'a save that sends an empty one clears it');

-- ── a supplier ──
select pg_temp.act();
select set_config('t.sup', public.save_supplier(p_workspace_id => current_setting('t.ws')::uuid, p_supplier_id => null, p_name => 'Fornitore Srl', p_tax_id => '',
  p_tax_id_kind => 'vat', p_street => 'Via Po 4', p_postal_code => '10123', p_city => 'Torino',
  p_country_code => 'IT', p_contact => '', p_number => '', p_subdivision => 'to')::text, true);
reset role;
select is((select subdivision from public.suppliers where id = current_setting('t.sup')::uuid), 'TO',
  'a new supplier keeps its region as a code');
select pg_temp.act();
select public.save_supplier(p_workspace_id => current_setting('t.ws')::uuid, p_supplier_id => current_setting('t.sup')::uuid, p_name => 'Fornitore Srl', p_tax_id => '',
  p_tax_id_kind => 'vat', p_street => 'Via Po 6', p_postal_code => '10123', p_city => 'Torino',
  p_country_code => 'IT', p_contact => '', p_number => '');
reset role;
select is((select (street, subdivision)::text from public.suppliers where id = current_setting('t.sup')::uuid),
  '("Via Po 6",TO)', 'a supplier saved without the region keeps the one stored');
select pg_temp.act();
select public.save_supplier(p_workspace_id => current_setting('t.ws')::uuid, p_supplier_id => current_setting('t.sup')::uuid, p_name => 'Fornitore Srl', p_tax_id => '',
  p_tax_id_kind => 'vat', p_street => 'Via Po 6', p_postal_code => '10123', p_city => 'Torino',
  p_country_code => 'IT', p_contact => '', p_number => '', p_subdivision => '');
reset role;
select is((select subdivision from public.suppliers where id = current_setting('t.sup')::uuid), '',
  'and one saved with an empty region has none');
-- the earlier signatures are gone: one function per name
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in ('upsert_site', 'save_supplier')), 2,
  'one save function each, no overload left');

select * from finish();
rollback;
