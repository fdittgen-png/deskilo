-- SPDX-License-Identifier: 0BSD
--
-- 0221 (#1294) — how a newly joining member starts.
--
-- `members.subscription_pct` defaults to 100 and `members.overage_policy`
-- to 'blocked', as column defaults. A workspace could not say otherwise,
-- so a template that configures tariffs, hours and features still left
-- every new member on a product default.
--
-- No new column and no new entity: the setting lives in
-- `billing_rules.new_member_defaults`, and `billing_rules` already
-- travels with the `tariffs` entity (#1276 S1 gave it merge semantics).
--
-- ## Applied on INSERT, never on conflict
--
-- `join_workspace` inserts with `on conflict (workspace_id, user_id) do
-- update` so that somebody re-joining is restored rather than
-- duplicated. The defaults are named in the INSERT and deliberately NOT
-- in the update branch: a returning member keeps the subscription they
-- already had. Rewriting it would be exactly what "existing members are
-- never rewritten" forbids, and it is the one hazard this change could
-- plausibly introduce.
--
-- The founder path (`create_workspace`), the twin (`create_workspace_twin`)
-- and the dev mirror (`members_mirror_to_dev`) are untouched: the first
-- is not a joining member, and the other two copy values that exist.

-- 1. The workspace may say what a new member starts with — within the
--    range the column itself allows.
do $validator$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'set_billing_rules' limit 1;
  if position('  update public.workspaces set billing_rules = coalesce(p_rules, ''{}''::jsonb)' in v_def) = 0 then
    raise exception '0221: the set_billing_rules anchor did not match';
  end if;
  v_def := replace(v_def,
    '  update public.workspaces set billing_rules = coalesce(p_rules, ''{}''::jsonb)',
$$  -- `members_subscription_pct_check` is 1..100, so a stored 0 could
  -- never be applied to anybody. #1279 S1 is what makes zero legal; the
  -- "no subscription cannot be pay-as-you-go" pairing belongs with it.
  if p_rules ? 'new_member_defaults' then
    if (p_rules->'new_member_defaults'->>'subscription_pct') is not null
       and ((p_rules->'new_member_defaults'->>'subscription_pct')::int < 1
            or (p_rules->'new_member_defaults'->>'subscription_pct')::int > 100) then
      raise exception 'a new member''s subscription is a percentage between 1 and 100';
    end if;
  end if;
  update public.workspaces set billing_rules = coalesce(p_rules, '{}'::jsonb)$$);
  execute v_def;
end
$validator$;

-- 2. Somebody joining by invitation.
do $join$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'join_workspace' limit 1;
  if position('  v_prod_joined boolean := false;' in v_def) = 0 then
    raise exception '0221: the join_workspace declare anchor did not match';
  end if;
  v_def := replace(v_def, '  v_prod_joined boolean := false;',
                          '  v_prod_joined boolean := false;' || chr(10) || '  v_defaults jsonb;');

  if position('    insert into public.members (workspace_id, user_id, is_admin, status, origin)
    values (ws_id, auth.uid(), v_admin, ''pending'', ''invited'')' in v_def) = 0 then
    raise exception '0221: the join_workspace insert anchor did not match';
  end if;
  v_def := replace(v_def,
    '    insert into public.members (workspace_id, user_id, is_admin, status, origin)
    values (ws_id, auth.uid(), v_admin, ''pending'', ''invited'')',
    '    select coalesce(billing_rules->''new_member_defaults'', ''{}''::jsonb)
      into v_defaults from public.workspaces where id = ws_id;
    insert into public.members (workspace_id, user_id, is_admin, status, origin,
                                subscription_pct, overage_policy)
    values (ws_id, auth.uid(), v_admin, ''pending'', ''invited'',
            coalesce((v_defaults->>''subscription_pct'')::int, 100),
            coalesce(v_defaults->>''overage_policy'', ''blocked''))');
  execute v_def;
end
$join$;

-- 3. A managed profile an admin creates on somebody's behalf.
do $managed$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_managed_member' limit 1;
  if position('  v_identity jsonb;' || chr(10) || '  v_id uuid;' in v_def) = 0 then
    raise exception '0221: the create_managed_member declare anchor did not match';
  end if;
  v_def := replace(v_def, '  v_identity jsonb;' || chr(10) || '  v_id uuid;',
                          '  v_identity jsonb;' || chr(10) || '  v_id uuid;' || chr(10) || '  v_defaults jsonb;');

  if position('  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name, origin)' in v_def) = 0 then
    raise exception '0221: the create_managed_member insert anchor did not match';
  end if;
  v_def := replace(v_def,
    '  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name, origin)',
    '  select coalesce(billing_rules->''new_member_defaults'', ''{}''::jsonb)
    into v_defaults from public.workspaces where id = p_workspace_id;
  insert into public.members
    (workspace_id, user_id, is_admin, status, managed_identity, managed_by,
     managed_access, managed_name, origin, subscription_pct, overage_policy)');
  v_def := replace(v_def,
    '          public.managed_identity_name(v_identity), ''delegated'')',
    '          public.managed_identity_name(v_identity), ''delegated'',
          coalesce((v_defaults->>''subscription_pct'')::int, 100),
          coalesce(v_defaults->>''overage_policy'', ''blocked''))');
  execute v_def;
end
$managed$;

-- 4. A keyed writer, because the merge belongs in the database.
--
-- `set_billing_rules` replaces the whole blob. Writing one key through
-- it means reading the jsonb, adding the key in Dart and writing the
-- object back — which is exactly the shape #1089 removed from the
-- booking rules: two admins with the settings screen open each wrote the
-- row as they had found it, and the second silently reverted the first.
--
-- Same shape as `set_booking_rule`, deliberately: the key guard, the
-- `jsonb_set` merge, the unknown-workspace check and the returned blob.
create or replace function public.set_billing_rule(
  p_workspace_id uuid,
  p_key text,
  p_value jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare v_rules jsonb;
begin
  if auth.uid() is null
     or not (public.has_permission(p_workspace_id, 'workspaceSettings')
             or public.has_permission(p_workspace_id, 'manageBilling')) then
    raise exception 'only workspace settings managers may change the billing rules';
  end if;
  if p_key !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'unknown billing rule %', p_key;
  end if;
  -- `members_subscription_pct_check` is 1..100, so a stored zero could
  -- never be applied to anybody. #1279 S1 is what makes zero legal, and
  -- the "no subscription cannot be pay-as-you-go" pairing belongs there.
  if p_key = 'new_member_defaults'
     and (p_value->>'subscription_pct') is not null
     and ((p_value->>'subscription_pct')::int < 1
          or (p_value->>'subscription_pct')::int > 100) then
    raise exception 'a new member''s subscription is a percentage between 1 and 100';
  end if;
  update public.workspaces
     set billing_rules = jsonb_set(
           coalesce(billing_rules, '{}'::jsonb), array[p_key], p_value, true)
   where id = p_workspace_id
  returning billing_rules into v_rules;
  if v_rules is null then raise exception 'unknown workspace'; end if;
  return v_rules;
end $fn$;

revoke execute on function public.set_billing_rule(uuid, text, jsonb)
  from public, anon;
grant execute on function public.set_billing_rule(uuid, text, jsonb)
  to authenticated;
