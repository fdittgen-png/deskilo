-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3932 (0818): the Spanish channel's connector can be configured. Its
-- certificate and private key are secrets: stored in the Vault, the row holds
-- a marker and never the PEM; the sandbox address stays public. A provider
-- outside the list is still refused.
begin;
select plan(8);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003932' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'es3932@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values (pg_temp.u(101), 'Spain 3932', 'ES', 'EUR', 'Europe/Madrid', pg_temp.u(1), '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01');

create function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(pg_temp.as_owner(format(
  'select public.set_einvoice_credentials(%L, %L::jsonb)::text', pg_temp.u(101),
  '{"provider": "es_verifactu", "base_url_uat": "https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP",
    "client_certificate_uat": "-----BEGIN CERTIFICATE-----FIXTURECERT-----END CERTIFICATE-----",
    "private_key_uat": "-----BEGIN PRIVATE KEY-----FIXTUREKEY-----END PRIVATE KEY-----"}')),
  'ok', 'the owner sets the Spanish connector''s sandbox credentials');
select is((select provider from public.einvoice_credentials where workspace_id = pg_temp.u(101)),
  'es_verifactu', 'the provider is stored');
select is((select config ->> 'base_url_uat' from public.einvoice_credentials where workspace_id = pg_temp.u(101)),
  'https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP', 'the sandbox address stays readable');
select ok((select config ->> 'private_key_uat' from public.einvoice_credentials where workspace_id = pg_temp.u(101))
  not like '%FIXTUREKEY%', 'the private key is a marker, not the key');
select ok((select config ->> 'client_certificate_uat' from public.einvoice_credentials where workspace_id = pg_temp.u(101))
  not like '%FIXTURECERT%', 'the certificate is a marker, not the PEM');
select ok(public.einvoice_config_is_secret('private_key_uat')
  and public.einvoice_config_is_secret('client_certificate_uat')
  and not public.einvoice_config_is_secret('base_url_uat'), 'the registry classifies the three keys');
select is(pg_temp.as_owner(format(
  'select public.set_einvoice_credentials(%L, %L::jsonb)::text', pg_temp.u(101), '{"provider": "es_other"}')),
  'ERR 22023', 'a provider outside the list is refused');
select throws_ok($$update public.einvoice_credentials set provider = 'es_other'$$, '23514',
  null, 'and the table refuses it too');

select * from finish();
rollback;
