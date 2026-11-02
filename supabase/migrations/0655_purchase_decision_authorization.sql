-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #3070: authorize each supplier-bill decision while holding the workspace,
-- actor membership, assigned role definitions and assignments through the
-- transaction. Existing idempotency, maker-checker and receipt flow remain.
do $patch$
declare
  v_proc regprocedure := 'public.decide_purchase_v1(uuid, uuid, integer, boolean, text, uuid)'::regprocedure;
  v_def text := pg_get_functiondef(v_proc);
  v_anchor text := $old$begin
  if auth.uid() is null then raise exception 'not signed in'; end if;$old$;
  v_replacement text := $new$begin
  -- Hold the authorization rows for the entire decision transaction. A
  -- revocation and this command serialize on the rows they both update.
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception using errcode = '42501', message = 'purchase decision is not available';
  end if;
  perform 1 from public.workspaces w where w.id = p_workspace_id for share;
  if not found then
    raise exception using errcode = '42501', message = 'purchase decision is not available';
  end if;
  -- The member UPDATE lock also conflicts with the immediate FK KEY SHARE
  -- acquired when a new custom-role assignment is inserted. This prevents a
  -- newly granted role from appearing after the assignment lock scan.
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id
    and m.user_id = auth.uid() for update;
  if v_me is null then
    raise exception using errcode = '42501', message = 'purchase decision is not available';
  end if;
  -- member_custom_permissions reads every role assignment for this member.
  -- Lock definitions first (role deletion cascades to assignments), then
  -- assignments, in a deterministic order before evaluating permission.
  perform r.id from public.workspace_roles r
    join public.workspace_role_members rm on rm.role_id = r.id
   where rm.member_id = v_me order by r.id for share of r;
  perform rm.id from public.workspace_role_members rm
   where rm.member_id = v_me order by rm.id for share;
  if public.feature_effective(p_workspace_id, 'purchases') is not true
      or not coalesce(public.has_permission(p_workspace_id, 'approveExpenses'), false) then
    raise exception using errcode = '42501', message = 'purchase decision is not available';
  end if;
  if auth.uid() is null then raise exception 'not signed in'; end if;$new$;
begin
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) <> length(v_anchor) then
    raise exception 'purchase decision guard anchor mismatch';
  end if;
  execute replace(v_def, v_anchor, v_replacement);
end
$patch$;

select public.set_deskilo_schema_version(655);
