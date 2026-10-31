-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2562 C2a: a personal home enrols a workspace installation only through
-- its operator functions. The relation is closed to every API role and
-- carries the restrictive personal policies; the functions are definers no
-- API role executes; an enrolment validates its origin, key, roles and
-- capability versions, refuses the home itself, a second installation on
-- one origin and an installation that is no personal home's to enrol, is
-- audited once per change, revoked rather than deleted and keeps its id.
-- The three identity.* settings exist with their bounds.
--
-- Every write goes through a function as the owner; roles are switched
-- only at the end and reset after each scene. A second installation cannot
-- live in this database: the enrolled ones are foreign ids.
begin;
select plan(40);

create function pg_temp.anon_jwt(p_claims text) returns text language sql as $$
  select 'eyJhbGciOiJIUzI1NiJ9.'
      || rtrim(translate(encode(convert_to(p_claims, 'UTF8'), 'base64'), '+/', '-_'), '=')
      || '.c2lnbmF0dXJl';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── the relation and its doors ────────────────────────────────────────
select has_table('public', 'enrolled_installations', 'the enrolment relation exists');
select ok((select relrowsecurity from pg_class where oid = 'public.enrolled_installations'::regclass),
  'it is row-level secured');
select is((select array_agg(polname::text order by polname) from pg_policy
            where polrelid = 'public.enrolled_installations'::regclass and not polpermissive),
  array['mcp_delegated_deny', 'personal_native_session'],
  'it carries the restrictive delegated and native-session policies');
select is_empty($$select r from unnest(array['anon', 'authenticated', 'service_role']) r
   where has_table_privilege(r, 'public.enrolled_installations', 'SELECT, INSERT, UPDATE, DELETE')$$,
  'no API role holds any privilege on it');
select is_empty($$select p.oid::regprocedure::text || ' ' || r from pg_proc p
   cross join unnest(array['anon', 'authenticated', 'service_role', 'deskilo_identity']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('operator_enrol_installation', 'operator_revoke_installation',
                      'operator_enrolled_installations', 'protect_enrolled_installation')
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the operator functions or the guard');
select is((select count(*)::int from pg_proc where pronamespace = 'public'::regnamespace
            and proname in ('operator_enrol_installation', 'operator_revoke_installation',
                            'operator_enrolled_installations') and prosecdef), 3,
  'the three operator functions are definers');

-- ── enrol ─────────────────────────────────────────────────────────────
select is(public.operator_enrol_installation('00000000-0000-4000-8000-00000025620a',
    'HTTPS://W-A.example.test/', 'sb_publishable_wa_key_123',
    array['workspace_host'], array['workspace@1'])->>'unchanged', 'false',
  'a personal home enrols a workspace host');
select is((select origin || ' ' || array_to_string(roles, '+') || ' ' || accepting_new_workspaces || ' ' || enabled
             from public.enrolled_installations
            where installation_id = '00000000-0000-4000-8000-00000025620a'),
  'https://w-a.example.test workspace_host true true',
  'with its origin normalised, its roles, accepting and in force');
select is((select count(*)::int from public.database_authority_audit
            where action = 'installation_enrolled'
              and detail->>'enrolled_installation_id' = '00000000-0000-4000-8000-00000025620a'), 1,
  'the enrolment is audited');
select ok(not exists (select 1 from public.database_authority_audit
            where action = 'installation_enrolled' and detail::text like '%sb_publishable%'),
  'and the audit names no key');
select is(public.operator_enrol_installation('00000000-0000-4000-8000-00000025620a',
    'https://w-a.example.test', 'sb_publishable_wa_key_123',
    array['workspace_host', 'workspace_host'], array['workspace@1'])->>'unchanged', 'true',
  'the same enrolment again changes nothing');
select is((select count(*)::int from public.database_authority_audit
            where action = 'installation_enrolled'
              and detail->>'enrolled_installation_id' = '00000000-0000-4000-8000-00000025620a'), 1,
  'and writes no second audit row');
select is(public.operator_enrol_installation('00000000-0000-4000-8000-00000025620b',
    'https://w-b.example.test', pg_temp.anon_jwt('{"role":"anon","iss":"supabase"}'),
    array['personal_home', 'workspace_host'], array['personal@1', 'workspace@1'], false)->>'unchanged',
  'false', 'a combined installation with a legacy anon key enrols, not accepting new workspaces');
select is((select accepting_new_workspaces from public.enrolled_installations
            where installation_id = '00000000-0000-4000-8000-00000025620b'), false,
  'and is recorded as not accepting');

-- ── refusals ──────────────────────────────────────────────────────────
select throws_ok(format($$select public.operator_enrol_installation(%L::uuid,
    'https://self.example.test', 'sb_publishable_self_123', array['workspace_host'], array['workspace@1'])$$,
    public.installation_id()), '22023', null, 'the home never enrols itself');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'http://w-c.example.test', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '22023', null, 'an origin that is not HTTPS is refused');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test/path', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '22023', null, 'an origin with a path is refused');
select throws_ok(format($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', %L, array['workspace_host'], array['workspace@1'])$$,
    pg_temp.anon_jwt('{"role":"service_role","iss":"supabase"}')),
  '22023', null, 'a secret (service_role) key is refused');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', 'sb_secret_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '22023', null, 'an sb_secret key is refused');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', 'sb_publishable_wc_key_123', array['personal_home'], array['personal@1'])$$,
  '22023', null, 'an installation that hosts no workspace is refused');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@2'])$$,
  '22023', null, 'an installation without workspace@1 is refused');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-a.example.test', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '23505', null, 'one origin names one installation');
select is((select count(*)::int from public.enrolled_installations
            where installation_id = '00000000-0000-4000-8000-00000025620c'), 0,
  'no refused enrolment left a row');

-- ── revoked, never forgotten ──────────────────────────────────────────
select throws_ok($$delete from public.enrolled_installations
   where installation_id = '00000000-0000-4000-8000-00000025620a'$$,
  '55000', null, 'an enrolment is never deleted, even by the owner');
select throws_ok($$update public.enrolled_installations
   set installation_id = '00000000-0000-4000-8000-00000025620d'
   where installation_id = '00000000-0000-4000-8000-00000025620a'$$,
  '55000', null, 'and keeps its installation id');
select is(public.operator_revoke_installation('00000000-0000-4000-8000-00000025620a')->>'status',
  'revoked', 'the operator revokes an enrolment');
select is((select concat_ws(' ', enabled::text, accepting_new_workspaces::text, (revoked_at is not null)::text)
             from public.enrolled_installations
            where installation_id = '00000000-0000-4000-8000-00000025620a'),
  'false false true', 'which is no longer in force nor accepting');
select is(public.operator_revoke_installation('00000000-0000-4000-8000-00000025620a')->>'unchanged',
  'true', 'revoking again changes nothing');
select is((select count(*)::int from public.database_authority_audit
            where action = 'installation_enrolment_revoked'
              and detail->>'enrolled_installation_id' = '00000000-0000-4000-8000-00000025620a'), 1,
  'the revocation is audited once');
select throws_ok($$select public.operator_revoke_installation('00000000-0000-4000-8000-00000025620e')$$,
  'P0002', null, 'an installation never enrolled cannot be revoked');
select is(public.operator_enrol_installation('00000000-0000-4000-8000-00000025620a',
    'https://w-a.example.test', 'sb_publishable_wa_key_123',
    array['workspace_host'], array['workspace@1'])->>'unchanged', 'false',
  'enrolling a revoked installation again brings it back, audited');
select is((select string_agg(origin || ':' || enabled, ' ' order by origin)
             from public.operator_enrolled_installations()),
  'https://w-a.example.test:true https://w-b.example.test:true',
  'the operator lists every enrolment');

-- ── only a personal home enrols ───────────────────────────────────────
select public.operator_set_installation_roles(array['workspace_host']);
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '55000', null, 'a workspace host that is no personal home enrols nobody');
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);

-- ── the API roles ─────────────────────────────────────────────────────
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000002562a1","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select count(*) from public.enrolled_installations$$,
  '42501', null, 'a signed-in person reads no enrolment');
select throws_ok($$select public.operator_enrol_installation('00000000-0000-4000-8000-00000025620c',
    'https://w-c.example.test', 'sb_publishable_wc_key_123', array['workspace_host'], array['workspace@1'])$$,
  '42501', null, 'nor enrols one');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.operator_revoke_installation('00000000-0000-4000-8000-00000025620b')$$,
  '42501', null, 'an anonymous caller revokes nothing');
reset role;

-- ── the identity freshness settings ───────────────────────────────────
select is((select string_agg(key || '=' || (default_value #>> '{}') || ' ' || min_value || '..' || max_value,
                             ', ' order by key)
             from public.setting_definitions where key like 'identity.%' and scopes = array['platform']),
  'identity.clock_skew_seconds=30 0..30, identity.status_assertion_lifetime_seconds=900 60..900, identity.status_reconcile_seconds=300 30..900',
  'the three identity settings are platform settings with their defaults and bounds');
select is(concat_ws('/', public.setting_value(null, 'identity.status_assertion_lifetime_seconds'),
    public.setting_value(null, 'identity.status_reconcile_seconds'),
    public.setting_value(null, 'identity.clock_skew_seconds')),
  '900/300/30', 'and resolve to them with nothing stored');
select ok((select public.setting_value_problem(type, '901'::jsonb, min_value, max_value, floor_value, choices) is not null
             from public.setting_definitions where key = 'identity.status_assertion_lifetime_seconds'),
  'a lifetime above 900 seconds is refused');
select ok((select public.setting_value_problem(type, '31'::jsonb, min_value, max_value, floor_value, choices) is not null
              and public.setting_value_problem(type, '0'::jsonb, min_value, max_value, floor_value, choices) is null
             from public.setting_definitions where key = 'identity.clock_skew_seconds'),
  'the skew takes 0..30 and nothing above');

select * from finish();
rollback;
