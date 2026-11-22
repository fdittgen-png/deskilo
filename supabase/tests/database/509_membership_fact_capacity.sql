-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4327: a workspace server with more live relationships than one drain run sends keeps every fact
-- fresh. The drain's batch is a platform setting (stated capacity: batch x refresh period / 60); a
-- renewal is not queued while an earlier event of the same assertion still waits, so the queue holds
-- one waiting event per relationship; the backlog reader says how many wait longer than a period.
begin;
select plan(12);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002563e' || lpad(p_n::text, 3, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.iss() returns text language sql as $$ select 'https://p.test/auth/v1' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- W-A, W-B, P and a stranger, by letter.
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('000002563a0' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ws() returns uuid language sql as $$ select pg_temp.id('000002563f01') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ref(p_c text) returns text language sql as $$ select pg_temp.inst(p_c) || ':' || pg_temp.ws() $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- plpgsql, not an inlinable SQL function: its own statement takes a fresh
-- snapshot, so it sees what an earlier go() in the same statement wrote.
create function pg_temp.sees(p_field text, p_viewer int) returns text language plpgsql as $$
begin return public.account_field_visible_to(pg_temp.u(1), p_field, pg_temp.u(p_viewer))::text; end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.mine(p_c text) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1()->'refs') e
   where e->>'network_id' = pg_temp.ref(p_c);
  perform set_config('request.jwt.claims', '', true);
  return coalesce((v->>'freshness') || ' ' || coalesce(v->>'status', '-'), 'none');
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;



delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider) values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p.test', 'sb_publishable_p_key_123');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));

select is((select key || '=' || (default_value #>> '{}') || ' ' || min_value || '..' || max_value || ' ' || unit || ' ' || array_to_string(scopes, ',')
             from public.setting_definitions where key = 'federation.fact_drain_batch')
          || ' ' || public.membership_fact_drain_batch()::text,
  'federation.fact_drain_batch=500 50..2000 entries platform 500', 'the drain batch is a platform setting of 500');
select is((select count(*)::int from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('membership_fact_drain_batch', 'membership_fact_backlog')
    and has_function_privilege(r, p.oid, 'EXECUTE')), 0, 'no API role executes the helpers');

-- 130 live relationships: more than one run of a batch of 50 sends
insert into public.setting_values (scope, workspace_id, key, value, note)
values ('platform', null, 'federation.fact_drain_batch', '50'::jsonb, 'test');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-4327@deskilo.test', '', now(), now(), now()
  from generate_series(1, 130) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values (pg_temp.ws(), 'Facts', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev', '{}', '{}');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
select public.installation_id(), pg_temp.u(n), pg_temp.iss(), 'subject-' || n, 'oidc_identity', 'active', null
  from generate_series(1, 130) n;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
select gen_random_uuid(), pg_temp.ws(), pg_temp.u(n), false, false, 'active' from generate_series(1, 130) n;
select is((select count(*)::int from public.membership_fact_outbox where state = 'pending'), 130,
  'one waiting event per live relationship');
select is(public.membership_fact_drain_batch()::text || ' ' || (public.membership_fact_drain()->>'sent'), '50 50',
  'a run sends the batch the setting names');
select is((public.membership_fact_drain()->>'sent') || ' ' || (public.membership_fact_drain()->>'sent'), '50 30',
  'three runs send the 130: more than one run of a batch');
select is((select count(*)::int from public.membership_fact_outbox where state = 'pending'), 0, 'and none waits');

-- a period later every relationship is renewed once and the queue does not double
update public.membership_fact_outbox set state = 'delivered', delivered_at = now();
update public.membership_fact_state set last_asserted_at = now() - interval '10 minutes';
select is(public.membership_fact_reconcile()::text, '{"changed": 0, "renewed": 130}', 'the quiet relationships are renewed');
select is(public.membership_fact_reconcile()::text || ' ' ||
          (select count(*)::int from public.membership_fact_outbox where state = 'pending'),
  '{"changed": 0, "renewed": 0} 130', 'a renewal is not queued again behind its waiting event');
select is(public.membership_fact_backlog(), '0|130|130|250', 'nothing waits longer than a period: 130 waiting, 130 live, 250 per period');
update public.membership_fact_outbox set asserted_at = now() - interval '10 minutes' where state = 'pending';
select is(public.membership_fact_backlog(), '130|130|130|250', 'events waiting longer than a period are counted');

-- a changed relationship is queued as before, whatever waits
update public.members set status = 'paused' where user_id = pg_temp.u(1);
select is((select count(*)::int from public.membership_fact_outbox where subject = 'subject-1' and state = 'pending' and status = 'paused'), 1,
  'a changed relationship is a new event');
select is((public.membership_fact_drain()->>'sent')::int, 50, 'the oldest waiting events go first');

select * from finish();
rollback;
