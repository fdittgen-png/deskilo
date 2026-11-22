-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4326: a person who unlinks their account and links it again is one relationship at the
-- personal home: one fact per subject and business, from the active binding; a run with nothing
-- changed writes nothing; a revoked binding is read only when no active one exists.
begin;
select plan(9);

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
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-4326@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into public.identity_authority (kind, issuer, oidc_provider) values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p.test', 'sb_publishable_p_key_123');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values (pg_temp.ws(), 'Facts', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev', '{}', '{}');
-- u1 is bound to the subject s1; u2 to s2.
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(1), pg_temp.iss(), 'subject-1', 'oidc_identity', 'active', null),
       (public.installation_id(), pg_temp.u(2), pg_temp.iss(), 'subject-2', 'oidc_identity', 'active', null);
create function pg_temp.out(p_subject text) returns text language sql as $$
  select string_agg(status, '<' order by revision, asserted_at) from public.membership_fact_outbox where subject = p_subject $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.events() returns int language sql as $$ select count(*)::int from public.membership_fact_outbox $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('000004326d01'), pg_temp.ws(), pg_temp.u(1), false, false, 'active');
select is(pg_temp.out('subject-1'), 'active', 'a member bound to a subject is one active fact');

-- revoke, then bind again with the same subject: the old row stays, a new active row is added
update public.identity_bindings set status = 'revoked', revoked_at = now() where local_user_id = pg_temp.u(1);
select is(pg_temp.out('subject-1'), 'active<tombstone', 'the revoked link is a tombstone');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(1), pg_temp.iss(), 'subject-1', 'oidc_identity', 'active', null);
select is(pg_temp.out('subject-1'), 'active<tombstone<active', 're-linking is one newer active fact');
select is((select count(*)::int from public.identity_bindings where local_user_id = pg_temp.u(1)), 2,
  'the person now has a revoked and an active binding of one subject');

-- nothing changed: neither the produce nor the reconcile writes anything, however often it runs
select is(pg_temp.events()::text || ' ' ||
          public.membership_fact_produce(pg_temp.ws(), pg_temp.u(1))::text || ' ' ||
          public.membership_fact_produce(pg_temp.ws(), pg_temp.u(1))::text, '3 0 0',
  'a second run with nothing changed writes nothing');
select is(public.membership_fact_reconcile()::text || ' ' || pg_temp.events()::text,
  '{"changed": 0, "renewed": 0} 3', 'nor does the reconcile');
select is((select status from public.membership_fact_state where subject = 'subject-1'), 'active',
  'the relationship stands as active at the home');

-- a subject another local person holds active is not tombstoned by this person's revoked row
update public.identity_bindings set status = 'revoked', revoked_at = now()
 where local_user_id = pg_temp.u(2);
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(2), pg_temp.iss(), 'subject-1', 'oidc_identity', 'revoked', now());
select is(public.membership_fact_produce(pg_temp.ws(), pg_temp.u(2))::text || ' ' ||
          (select status from public.membership_fact_state where subject = 'subject-1'), '0 active',
  'a revoked row of a subject held active by someone else asserts nothing');

-- a revoked binding alone, with no active one, is read: the relationship ends
update public.identity_bindings set status = 'revoked', revoked_at = now() where local_user_id = pg_temp.u(1) and status = 'active';
select is((select status from public.membership_fact_state where subject = 'subject-1'), 'tombstone',
  'with no active binding the revoked one ends the relationship');

select * from finish();
rollback;
