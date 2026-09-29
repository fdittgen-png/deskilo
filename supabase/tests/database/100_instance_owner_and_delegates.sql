-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1829 / 0314: the instance owner is visible to everyone on the database
-- and can delegate. A delegate is an operator for the installation-wide
-- steps and nothing more: they cannot delegate, withdraw or see account
-- ids. An assistant's delegated token is never an operator. A new
-- instance has no owner until the account whose confirmed e-mail matches
-- the creator's recorded claim claims it, once. Callers run as
-- `authenticated`; seeds run as postgres.
begin;
select plan(20);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001829a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-1829@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001829a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'delegate-1829@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001829a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-1829@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001829a4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'unconfirmed-1829@deskilo.test', '', null, now(), now()),
 ('00000000-0000-4000-8000-0000001829a5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'creator-1829@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000001829a1');

-- ── everyone sees who is responsible ────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a3');
select is(public.instance_responsibles()->'owners'->0->>'email', 'owner-1829@deskilo.test', 'a member sees the instance owner');
select is(public.instance_responsibles()->>'you', null, 'a member is neither owner nor delegate');
select is(public.is_instance_operator(), false, 'a member is not an operator');
select throws_ok($$select public.delegate_instance_role('delegate-1829@deskilo.test')$$, 'P0001', null, 'a member cannot delegate');

-- ── the owner delegates, with refusals that say why ─────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a1');
select is(public.delegate_instance_role('nobody-1829@deskilo.test')->>'reason', 'no_account', 'an unknown e-mail is refused');
select is(public.delegate_instance_role('unconfirmed-1829@deskilo.test')->>'reason', 'unconfirmed', 'an unconfirmed account is refused');
select is(public.delegate_instance_role('owner-1829@deskilo.test')->>'reason', 'already_owner', 'the owner cannot delegate to themselves');
select is(public.delegate_instance_role('Delegate-1829@deskilo.test')->>'status', 'delegated', 'a confirmed account is delegated, whatever the case');
select is(public.delegate_instance_role('delegate-1829@deskilo.test')->>'status', 'unchanged', 'delegating twice changes nothing');
select is(jsonb_array_length(public.instance_responsibles()->'delegates'), 1, 'the owner sees the delegate');
select ok(public.instance_responsibles()->'delegates'->0 ? 'user_id', 'the owner gets the account id to withdraw with');

-- ── the delegate operates, and nothing more ─────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a2');
select is(public.is_instance_operator(), true, 'a delegate is an operator');
select ok(not (public.instance_responsibles()->'delegates'->0 ? 'user_id'), 'a delegate does not get account ids');
select throws_ok($$select public.delegate_instance_role('member-1829@deskilo.test')$$, 'P0001', null, 'a delegate cannot delegate');

-- ── an assistant token is never an operator ─────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a2', 'assistant-1829');
select is(public.is_instance_operator(), false, 'a delegated token is not an operator');

-- ── withdrawing ends it ─────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a1');
select is(public.withdraw_instance_delegation('00000000-0000-4000-8000-0000001829a2')->>'status', 'withdrawn', 'the owner withdraws the delegation');
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a2');
select is(public.is_instance_operator(), false, 'a withdrawn delegate is no longer an operator');

-- ── a new instance: only the creator's confirmed e-mail claims ──────
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a5');
select is(public.claim_instance_ownership()->>'reason', 'owner_exists', 'nobody claims an instance that has an owner');
reset role;
delete from public.platform_admins;
select public.operator_record_instance_owner_claim('Creator-1829@deskilo.test');
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a3');
select is(public.claim_instance_ownership()->>'reason', 'no_claim', 'an account that is not the creator cannot claim');
select pg_temp.act_as('00000000-0000-4000-8000-0000001829a5');
select is(public.claim_instance_ownership()->>'status', 'claimed', 'the creator claims the ownership, once');

select * from finish();
rollback;
