-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3914 (0796): a change of a workspace's payment or e-invoicing credentials
-- leaves one entry, read by those who manage the integrations: which area and
-- provider, whether the credentials were set, replaced or cleared, and the
-- names of the keys -- never a value or a part of one. Who and when are the
-- event's own columns. A refused change, or one that changes nothing, records
-- nothing.
begin;
select plan(18);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003914' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'cred' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values (pg_temp.u(101), 'Credentials 3914', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active', '2026-01-01');

-- Runs p_sql as user n; 'ok' or 'ERR <sqlstate>'.
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.entries() returns int language sql as $$
  select count(*)::int from public.events where workspace_id = pg_temp.u(101) and type = 'credential_change';
$$;
-- The one entry of [p_area] recording [p_change] (one transaction: the
-- entries share their time, so they are told apart by what they record).
create function pg_temp.entry(p_area text, p_change text) returns jsonb language sql as $$
  select payload from public.events where workspace_id = pg_temp.u(101) and type = 'credential_change'
     and payload ->> 'area' = p_area and payload ->> 'change' = p_change;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── payment: set, then replace ──
select is(pg_temp.as_user(1, format(
  'select public.set_payment_credentials(%L, %L, %L)::text', pg_temp.u(101), 'stripe',
  '{"secret_key": "fixture-SECRETVALUE1", "publishable_key": "fixture-PUBLICVALUE1"}')),
  'ok', 'the owner sets a payment provider''s credentials');
select is(pg_temp.entry('payment', 'set'),
  '{"area": "payment", "provider": "stripe", "change": "set", "keys": ["publishable_key", "secret_key"]}'::jsonb,
  'one entry names the area, the provider, the change and the keys');
select is((select count(*)::int from public.events
            where workspace_id = pg_temp.u(101) and type = 'credential_change'
              and actor_member_id = pg_temp.u(201) and created_at is not null),
  1, 'who and when are the event''s own columns');
select is(pg_temp.as_user(1, format(
  'select public.set_payment_credentials(%L, %L, %L)::text', pg_temp.u(101), 'stripe',
  '{"secret_key": "fixture-SECRETVALUE2"}')), 'ok', 'the owner replaces one key');
select ok(pg_temp.entry('payment', 'replace') is not null, 'the second change is a replacement');
select is(pg_temp.entry('payment', 'replace') -> 'keys', '["secret_key"]'::jsonb, 'naming only the key it changed');

-- ── e-invoicing: set, replace, clear ──
select is(pg_temp.as_user(1, format(
  'select public.set_einvoice_credentials(%L, %L)::text', pg_temp.u(101),
  '{"provider": "peppol", "endpoint": "https://ap.example.test/ENDPOINTVALUE", "api_key": "EINVOICESECRET1"}')),
  'ok', 'the owner sets the e-invoicing credentials');
select is(pg_temp.entry('einvoice', 'set'),
  '{"area": "einvoice", "provider": "peppol", "change": "set", "keys": ["api_key", "endpoint"]}'::jsonb,
  'one entry, the connector named as the provider, not as a key');
select is(pg_temp.as_user(1, format(
  'select public.set_einvoice_credentials(%L, %L)::text', pg_temp.u(101), '{"api_key": "EINVOICESECRET2"}')),
  'ok', 'the owner replaces the key');
select is(pg_temp.entry('einvoice', 'replace') -> 'keys', '["api_key"]'::jsonb, 'recorded as a replacement of that key');
select is(pg_temp.as_user(1, format('select public.clear_einvoice_credentials(%L)::text', pg_temp.u(101))),
  'ok', 'the owner clears them');
select is(pg_temp.entry('einvoice', 'clear') -> 'keys', '["api_key", "endpoint"]'::jsonb, 'recorded as cleared, with the keys that were stored');
select is(pg_temp.entries(), 5, 'five changes, five entries');

-- ── what records nothing ──
select is(pg_temp.as_user(1, format('select public.clear_einvoice_credentials(%L)::text', pg_temp.u(101)))
          || ' ' || pg_temp.entries()::text,
  'ok 5', 'clearing what is not stored records nothing');
select is(pg_temp.as_user(2, format(
  'select public.set_payment_credentials(%L, %L, %L)::text', pg_temp.u(101), 'stripe', '{"secret_key": "fixture-X"}'))
          || ' ' || pg_temp.entries()::text,
  'ERR DKN01 5', 'a refused change records nothing');
select ok(position('SECRETVALUE' in (select string_agg(payload::text, ' ') from public.events where type = 'credential_change' and workspace_id = pg_temp.u(101))) = 0
      and position('PUBLICVALUE' in (select string_agg(payload::text, ' ') from public.events where type = 'credential_change' and workspace_id = pg_temp.u(101))) = 0
      and position('EINVOICESECRET' in (select string_agg(payload::text, ' ') from public.events where type = 'credential_change' and workspace_id = pg_temp.u(101))) = 0
      and position('ENDPOINTVALUE' in (select string_agg(payload::text, ' ') from public.events where type = 'credential_change' and workspace_id = pg_temp.u(101))) = 0,
  'no entry carries a value or a part of one');

-- ── who reads them ──
select is(pg_temp.as_user(1, format('select count(*)::text from public.events where workspace_id = %L and type = %L',
                                    pg_temp.u(101), 'credential_change'))
          || ' ' || pg_temp.as_user(2, format('select count(*)::text from public.events where workspace_id = %L and type = %L',
                                    pg_temp.u(101), 'credential_change'))
          || ' ' || pg_temp.as_user(3, format('select count(*)::text from public.events where workspace_id = %L and type = %L',
                                    pg_temp.u(101), 'credential_change')),
  '5 0 0', 'the owner reads the entries; a member and an administrator without the right to manage integrations do not');
select ok(not has_function_privilege('authenticated', 'public.record_credential_change(uuid, text, text, text[], text)', 'execute'),
  'nobody records an entry by hand');

select * from finish();
rollback;
