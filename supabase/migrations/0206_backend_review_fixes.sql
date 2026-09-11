-- SPDX-License-Identifier: 0BSD
-- 0206 — four backend findings from the 2026-09-11 review.
--
-- ── #1141 / #1145 — stale overloads ───────────────────────────────
-- create_reservation (6/7-arg), admin_create_reservation_for (5-arg) and
-- profile_postal_block (2-arg) were each left beside a wider re-creation.
-- The older SECURITY DEFINER bodies predate the level-booking gates
-- (0057) and the validation routing (0059) and stayed callable by
-- `authenticated` — a hand-crafted 6-key POST exact-matched the 0031
-- body. The 2-arg postal block made every 1- or 2-arg call ambiguous
-- (42725). The app calls only the surviving signatures; a shorter call
-- now routes to the hardened body through its defaults.
drop function if exists public.create_reservation(uuid,uuid,uuid,timestamptz,timestamptz,boolean);
drop function if exists public.create_reservation(uuid,uuid,uuid,timestamptz,timestamptz,boolean,uuid);
drop function if exists public.admin_create_reservation_for(uuid,uuid,uuid,timestamptz,timestamptz);
drop function if exists public.profile_postal_block(profiles,text);

-- ── #1139 — a held matrix change could not be confirmed ──────────
-- 0198 made the confirm branch call set_role_permission in the
-- VALIDATOR's session, whose has_permission(manageRoles) the default
-- admin fails, so the whole respond_to_event rolled back. The REQUEST
-- was already gated on manageRoles; the validator is whoever the policy
-- names. The delta itself needs no caller check — it is revoked from
-- every client role and reachable only through the trigger and
-- set_role_permission.
create or replace function public.apply_role_permission_delta(p_workspace_id uuid, p_role text, p_permission text, p_enabled boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_next jsonb;
begin
  if p_role not in ('co_owner','admin','member') then raise exception 'unknown role'; end if;
  if not (p_permission = any(public.role_permission_catalog())) then raise exception 'unknown permission %', p_permission; end if;
  update public.workspaces w set role_permissions = jsonb_set(coalesce(w.role_permissions,'{}'::jsonb), array[p_role],
    coalesce((select jsonb_agg(value order by value) from (
      select value from jsonb_array_elements_text(coalesce(w.role_permissions->p_role,'[]'::jsonb)) where value <> p_permission
      union select p_permission where p_enabled) t(value)), '[]'::jsonb), true)
  where w.id = p_workspace_id returning w.role_permissions into v_next;
  if v_next is null then raise exception 'unknown workspace'; end if;
  return v_next;
end; $fn$;
revoke execute on function public.apply_role_permission_delta(uuid,text,text,boolean) from public, anon, authenticated;

do $patch$
declare v_def text; v_new text; anc text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='apply_validated_decision_0181';
  anc := 'perform public.set_role_permission(new.workspace_id, new.payload->>''role'',';
  if position(anc in v_def)=0 then raise exception '0206: trigger anchor missing'; end if;
  v_new := replace(v_def, anc, 'perform public.apply_role_permission_delta(new.workspace_id, new.payload->>''role'',');
  if v_new = v_def then raise exception '0206: trigger patch changed nothing'; end if;
  execute v_new;

  -- ── #1146 — the twin's owner: numbered (0165) and a founder (0200) ─
  -- Both fixes went to create_workspace only; the tile's "add the
  -- missing twin" path still inserted a bare owner row.
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='create_workspace_twin';
  anc := E'  insert into public.members (workspace_id, user_id, is_admin, is_owner)\n  values (twin_id, auth.uid(), true, true);';
  if position(anc in v_def)=0 then raise exception '0206: twin anchor missing'; end if;
  v_new := replace(v_def, anc, E'  insert into public.members (workspace_id, user_id, is_admin, is_owner, origin)\n  values (twin_id, auth.uid(), true, true, ''founder'');\n  update public.members set member_number = public.next_document_number(twin_id, ''member'')\n    where workspace_id = twin_id and user_id = auth.uid();');
  if v_new = v_def then raise exception '0206: twin patch changed nothing'; end if;
  execute v_new;

  -- ── #1142 — importing into a target you may deploy into ──────────
  -- 0197 narrowed the guard to manageConfiguration, which the default
  -- admin does not hold, while may_deploy() and the router still offered
  -- the refresh on deployToDev. The guard now says what they say.
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='import_workspace_configuration';
  anc := 'if auth.uid() is null or not public.has_permission(p_workspace_id, ''manageConfiguration'') then';
  if position(anc in v_def)=0 then raise exception '0206: import anchor missing'; end if;
  v_new := replace(v_def, anc, 'if auth.uid() is null or not (public.has_permission(p_workspace_id, ''manageConfiguration'') or public.has_permission(p_workspace_id, case (select environment from public.workspaces where id = p_workspace_id) when ''prod'' then ''deployToProd'' else ''deployToDev'' end)) then');
  if v_new = v_def then raise exception '0206: import patch changed nothing'; end if;
  execute v_new;
end $patch$;
revoke execute on function public.apply_validated_decision_0181() from public, anon;
revoke execute on function public.create_workspace_twin(uuid) from public, anon;
revoke execute on function public.import_workspace_configuration(uuid, jsonb) from public, anon;
