-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1294 — how a new member starts, and who is NOT a new member.
--
-- `subscription_pct` and `overage_policy` were column defaults, so a
-- workspace could not say how somebody joining should start. They now
-- come from `billing_rules.new_member_defaults`.
--
-- The assertion that matters most is the one about re-joining.
-- `join_workspace` inserts with `on conflict do update`, so a member who
-- left and comes back takes the UPDATE branch. The defaults are named
-- only in the insert; if they were named in the update too, coming back
-- would silently rewrite the subscription that member already had.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_id uuid := '00000000-0000-4000-8000-0000000000a1';
  joiner_id uuid := '00000000-0000-4000-8000-0000000000a2';
  ws uuid; plain uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (owner_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'defaults-owner@deskilo.test', '', now(), now(), now()),
         (joiner_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'defaults-joiner@deskilo.test', '', now(), now(), now());

  perform set_config('request.jwt.claims',
    json_build_object('sub', owner_id::text, 'role', 'authenticated')::text, true);
  select public.create_workspace('Defaults', 'FR', 'EUR', 'Europe/Paris') into ws;
  select public.create_workspace('Plain', 'FR', 'EUR', 'Europe/Paris') into plain;

  -- A billing rule some other feature owns, so the keyed writer below
  -- can be seen to preserve it.
  update public.workspaces set billing_rules = '{"something_else": "kept"}'::jsonb
   where id = ws;
  perform public.set_billing_rule(ws, 'new_member_defaults',
    jsonb_build_object('subscription_pct', 50, 'overage_policy', 'payg'));

  perform set_config('deskilo.def.ws', ws::text, false);
  perform set_config('deskilo.def.plain', plain::text, false);
  perform set_config('deskilo.def.owner', owner_id::text, false);
  perform set_config('deskilo.def.joiner', joiner_id::text, false);
  perform set_config('deskilo.def.code',
    (select invite_code from public.workspaces where id = ws), false);
  perform set_config('deskilo.def.plaincode',
    (select invite_code from public.workspaces where id = plain), false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.def.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.member(p_ws text, p_user text)
returns text language sql as $$
  select subscription_pct || '/' || overage_policy
    from public.members
   where workspace_id = current_setting('deskilo.def.' || p_ws)::uuid
     and user_id = current_setting('deskilo.def.' || p_user)::uuid;
$$;

select pg_temp.seed();

-- ----------------------------------------------- the founder is not one
select is(pg_temp.member('ws', 'owner'), '100/blocked',
  'the founder of a workspace does not take the new-member defaults — '
  'they are not a joining member');

-- ------------------------------------------------------ a genuine join
select pg_temp.act_as('joiner');
select public.join_workspace(current_setting('deskilo.def.code'));
select is(pg_temp.member('ws', 'joiner'), '50/payg',
  'somebody joining by invitation starts as the workspace says');

-- ------------------------------ and a workspace that configures nothing
select public.join_workspace(current_setting('deskilo.def.plaincode'));
select is(pg_temp.member('plain', 'joiner'), '100/blocked',
  'with nothing configured the product defaults still apply, exactly as '
  'before this existed');

-- --------------------------------------------- re-joining rewrites NOTHING
update public.members set subscription_pct = 80, overage_policy = 'blocked'
 where workspace_id = current_setting('deskilo.def.ws')::uuid
   and user_id = current_setting('deskilo.def.joiner')::uuid;
select public.join_workspace(current_setting('deskilo.def.code'));
select is(pg_temp.member('ws', 'joiner'), '80/blocked',
  'a member who re-joins keeps what they had: the defaults are named in '
  'the INSERT and never in the ON CONFLICT branch');

-- -------------------------------------------------- a managed profile
select pg_temp.act_as('owner');
select public.create_managed_member(current_setting('deskilo.def.ws')::uuid,
  jsonb_build_object('first_name', 'Mana', 'last_name', 'Ged'), '{}'::jsonb);
select is(
  (select subscription_pct || '/' || overage_policy from public.members
    where workspace_id = current_setting('deskilo.def.ws')::uuid
      and managed_name <> '' limit 1),
  '50/payg',
  'a managed profile an admin creates starts the same way');

-- ------------------------- changing the rule touches no existing member
select public.set_billing_rules(current_setting('deskilo.def.ws')::uuid,
  jsonb_build_object('new_member_defaults',
    jsonb_build_object('subscription_pct', 25, 'overage_policy', 'blocked')));
select is(pg_temp.member('ws', 'joiner'), '80/blocked',
  'changing what NEW members get rewrites nobody who is already here');

-- That call also just demonstrated the hazard #1089 named: it replaced
-- `billing_rules` WHOLESALE, so the unrelated rule seeded above is gone.
-- This is not a defect being tolerated — it is the entire reason the
-- keyed writer below exists, so it is asserted rather than described.
-- (This assertion is what the first version of this file got wrong: it
-- seeded the sibling, replaced the blob, and then expected the sibling
-- to have survived. The product was right and the test was not.)
select is(
  (select billing_rules->>'something_else' from public.workspaces
    where id = current_setting('deskilo.def.ws')::uuid),
  null::text,
  'the blob writer replaces every billing rule, including ones it was '
  'never told about — which is why writing one key needs its own writer');

-- Put it back through the keyed writer, so the next assertion measures
-- preservation rather than the leftovers of the seed.
select public.set_billing_rule(current_setting('deskilo.def.ws')::uuid,
  'something_else', '"kept"'::jsonb);

-- -------------------------------------------------------- the refusals
select throws_matching(
  format($$ select public.set_billing_rules(%L, '{"new_member_defaults": {"subscription_pct": 0}}'::jsonb) $$,
         current_setting('deskilo.def.ws')),
  'between 1 and 100',
  'zero is refused: members_subscription_pct_check is 1..100, so a stored '
  'zero could never be applied to anybody (#1279 S1 makes it legal)');

select throws_matching(
  format($$ select public.set_billing_rules(%L, '{"new_member_defaults": {"subscription_pct": 250}}'::jsonb) $$,
         current_setting('deskilo.def.ws')),
  'between 1 and 100',
  'and so is a percentage above one hundred');

-- ------------------------------------------ the keyed writer (#1089)
-- `set_billing_rules` replaces the whole blob, so writing one key
-- through it means reading the jsonb, changing a key in Dart and
-- writing it back — the shape that let two admins each revert the
-- other. `set_billing_rule` merges in the database instead.
select lives_ok(
  format($$ select public.set_billing_rule(%L, 'new_member_defaults',
              '{"subscription_pct": 40, "overage_policy": "blocked"}'::jsonb) $$,
         current_setting('deskilo.def.ws')),
  'the keyed writer sets one billing rule');

select is(
  (select billing_rules->>'something_else' from public.workspaces
    where id = current_setting('deskilo.def.ws')::uuid),
  'kept',
  'and every other billing rule survives it — the merge is the '
  'database''s, not the client''s');

select throws_matching(
  format($$ select public.set_billing_rule(%L, 'Not A Key', '{}'::jsonb) $$,
         current_setting('deskilo.def.ws')),
  'unknown billing rule',
  'a key that is not a key is refused rather than written');

select * from finish();
rollback;
