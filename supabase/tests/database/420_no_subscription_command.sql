-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3879 (0759) -- "No subscription" goes through the subscription command:
-- 0 applies to a member who does not pay as they go; with pay-as-you-go it is
-- refused with the sentence of 0235; with a validation policy the approval
-- applies 0; the assistant's path takes 0 as its contract says. Rolled back.
begin;
select plan(6);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;
create or replace function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003879' || lpad(n::text, 4, '0'))::uuid;
$$;
create or replace function pg_temp.m(n int) returns uuid language sql as $$
  select id from public.members where workspace_id = current_setting('deskilo.ns.ws')::uuid and user_id = pg_temp.u(n);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'no-sub-' || i || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) i;

select pg_temp.act_as(pg_temp.u(1));
select set_config('deskilo.ns.ws',
  public.create_workspace('No subscription', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
-- 2 is blocked at its quota, 3 pays as it goes, 4 is blocked (asked under a policy).
insert into public.members (workspace_id, user_id, status, subscription_pct, overage_policy) values
  (current_setting('deskilo.ns.ws')::uuid, pg_temp.u(2), 'active', 50, 'blocked'),
  (current_setting('deskilo.ns.ws')::uuid, pg_temp.u(3), 'active', 50, 'payg'),
  (current_setting('deskilo.ns.ws')::uuid, pg_temp.u(4), 'active', 50, 'blocked');

select pg_temp.act_as(pg_temp.u(1));
select is(public.request_subscription_change(pg_temp.m(2), 0) ->> 'pending', 'false',
  'the owner sets "no subscription" through the command');
reset role;
select is((select subscription_pct from public.members where id = pg_temp.m(2)), 0,
  'and the member has no subscription');

select pg_temp.act_as(pg_temp.u(1));
select throws_like(format($$ select public.request_subscription_change(%L, 0) $$, pg_temp.m(3)),
  '%cannot pay as they go%',
  'a member who pays as they go cannot have no subscription, said in the sentence of 0235');
reset role;

insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('deskilo.ns.ws')::uuid, 'subscription_change', 1, true, 'admins')
on conflict do nothing;
select pg_temp.act_as(pg_temp.u(1));
select set_config('deskilo.ns.event',
  public.request_subscription_change(pg_temp.m(4), 0) ->> 'event_id', true);
reset role;
update public.events set status = 'confirmed' where id = current_setting('deskilo.ns.event')::uuid;
select is((select subscription_pct from public.members where id = pg_temp.m(4)), 0,
  'with a validation policy, the approval applies "no subscription"');

select ok(position($a$(p_args->>'pct')::integer not between 0 and 100$a$
                   in pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure)) > 0
      and position($a$not between 1 and 100$a$
                   in pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure)) = 0,
  'the assistant''s path takes pct 0 to 100, as its contract says');

select pg_temp.act_as(pg_temp.u(1));
select throws_like($$ select public.request_subscription_change(gen_random_uuid(), 101) $$,
  '%unknown member%', 'an unknown member is refused before anything else');
reset role;

select * from finish();
rollback;
