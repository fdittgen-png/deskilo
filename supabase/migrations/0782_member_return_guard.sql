-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one trigger; one function restated; three anchored patches)
--
-- #4008 -- a person who left a business and comes back is a new member of
-- it, on every way of coming back. A member row leaves 'exited' only
-- through member_return_as_new, which makes it what a first-time member of
-- that business gets; any other statement that would take a row out of
-- 'exited' is refused (DKM01, "a member who left comes back as a new
-- member"), whoever runs it.
--
-- The ways of coming back that go through it, then do what they do for a
-- first-time member:
-- * asking a house of the organisation, the business's code, a new
--   invitation (0781);
-- * an administrator setting a member who left back to active, at once or
--   through the business's validation: the administrator's decision is the
--   business's, so the row is active, as a new member. Setting a member who
--   left to paused is refused; setting them to exited changes nothing;
-- * an invitation bound to a managed profile that had left: the profile
--   comes back as a new member, pending as that invitation leaves anyone.

-- ── 1. the one way out of 'exited' ───────────────────────────────────────
create or replace function public.member_return_as_new(p_member uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_defaults jsonb;
begin
  select m.workspace_id into v_ws from public.members m where m.id = p_member and m.status = 'exited';
  if v_ws is null then return; end if;
  select coalesce(w.billing_rules->'new_member_defaults', '{}'::jsonb)
    into v_defaults from public.workspaces w where w.id = v_ws;
  -- the guard lets this row, and only this row, out of 'exited'
  perform set_config('deskilo.member_return', p_member::text, true);
  -- in one statement: pending, the business's terms for a new member, and
  -- every other right and term back to the column's default
  execute format('update public.members set status = %L, subscription_pct = $2, overage_policy = $3%s where id = $1',
    'pending',
    (select coalesce(string_agg(format(', %I = default', c), ''), '')
       from jsonb_array_elements_text(public.house_member_return_columns()->'reset') c
      where c not in ('status', 'subscription_pct', 'overage_policy')))
    using p_member, coalesce((v_defaults->>'subscription_pct')::int, 100),
          coalesce(v_defaults->>'overage_policy', 'blocked');
  perform set_config('deskilo.member_return', '', true);
  delete from public.workspace_role_members where member_id = p_member;
end;
$fn$;
revoke execute on function public.member_return_as_new(uuid) from public, anon, authenticated;

create or replace function public.members_return_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if old.status = 'exited' and new.status is distinct from 'exited'
     and coalesce(current_setting('deskilo.member_return', true), '') is distinct from old.id::text then
    raise exception 'a member who left comes back as a new member' using errcode = 'DKM01';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_return_guard() from public, anon, authenticated;
drop trigger if exists members_return_guard on public.members;
create trigger members_return_guard before update of status on public.members
  for each row when (old.status = 'exited' and new.status is distinct from old.status)
  execute function public.members_return_guard();

-- ── 2. the remaining ways back go through it ────────────────────────────
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
  v_fn text;
begin
  -- an administrator's change of a member's status, at once
  v_def := pg_get_functiondef('public.request_member_status_change(uuid,text)'::regprocedure);
  if position('member_return_as_new' in v_def) = 0 then
    for v_old, v_new in select * from (values
      ($r$  if v_m.is_owner then raise exception 'an owner hands the workspace over first'; end if;$r$,
       $r$  if v_m.is_owner then raise exception 'an owner hands the workspace over first'; end if;
  -- #4008: a member who left comes back as a new member, never paused
  if v_m.status = 'exited' and p_status = 'paused' then
    raise exception 'a member who left comes back as a new member' using errcode = 'DKM01';
  end if;$r$),
      ($r$  update public.members set status = p_status where id = p_member_id;$r$,
       $r$  if v_m.status = 'exited' and p_status = 'active' then
    perform public.member_return_as_new(p_member_id);
  end if;
  update public.members set status = p_status where id = p_member_id;$r$)) v(o, n)
    loop
      if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
        raise exception 'request_member_status_change no longer has the shape 0782 extends: %', left(v_old, 60) using errcode = 'P0001';
      end if;
      v_def := replace(v_def, v_old, v_new);
    end loop;
    execute v_def;
  end if;

  -- the same change, once the business's validation decided it
  select p.oid::regprocedure::text into v_fn from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'apply_validated_decision_0181';
  v_def := pg_get_functiondef(v_fn::regprocedure);
  if position('member_return_as_new' in v_def) = 0 then
    v_old := $r$        update public.members set status = new.payload->>'after' where id = (new.payload->>'member_id')::uuid;$r$;
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception 'apply_validated_decision_0181 no longer has the shape 0782 extends' using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, $r$        -- #4008: a member who left comes back as a new member
        if new.payload->>'after' = 'active' then
          perform public.member_return_as_new((new.payload->>'member_id')::uuid);
        end if;
        update public.members set status = new.payload->>'after' where id = (new.payload->>'member_id')::uuid;$r$);
  end if;

  -- an invitation bound to a managed profile that had left
  v_def := pg_get_functiondef('public.join_workspace(text)'::regprocedure);
  if position('member_return_as_new(v_bound)' in v_def) = 0 then
    v_old := $r$    update public.members
       set user_id = auth.uid(), claimed_at = now(),$r$;
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception 'join_workspace no longer has the bound shape 0782 extends' using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, $r$    -- #4008: a managed profile that had left comes back as a new member
    perform public.member_return_as_new(v_bound);
    update public.members
       set user_id = auth.uid(), claimed_at = now(),$r$);
  end if;
end
$migration$;

select public.set_deskilo_schema_version(782);
