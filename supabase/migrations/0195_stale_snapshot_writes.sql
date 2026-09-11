-- SPDX-License-Identifier: 0BSD
-- 0195 — #1089: booking rules and the role matrix stop being written
-- from a stale snapshot.
--
-- 0176 already told this story for `feature_flags`: three screens rewrote
-- the column wholesale from their own copy of the row, and any copy older
-- than the row put the row back to what the copy remembered — "the pilot
-- switched three features on and the third write turned the first two off
-- again". The remedy was to merge IN the database, where the current row
-- is. Two writers were left doing exactly what that migration forbade.
--
--   booking_rules     the client SELECTs the jsonb, adds one key in Dart
--                     and UPDATEs the whole object back
--   role_permissions  the roles screen computes a role's WHOLE permission
--                     list from the snapshot the screen was built with
--
-- The second is the dangerous one. The role matrix is the access-control
-- surface: "last writer wins" there means a permission an owner
-- deliberately removed can come back because somebody else had the screen
-- open — and nobody is told, because from each side their own save
-- succeeded.
--
-- Both now change ONE thing at a time, server-side, under the permission
-- checks they already had. `set_role_permissions` stays for the callers
-- that legitimately replace a whole list — the settings import and the
-- deployment transfer. What changes is that the SCREEN no longer does.

-- ── the catalog, in one place ──────────────────────────────────────
-- `set_role_permissions` carried this array inline. The new single-flip
-- function needs the same list, and two copies of a permission catalog
-- is exactly the drift #982 spent a migration removing elsewhere.
create or replace function public.role_permission_catalog()
returns text[] language sql immutable as $$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd'];
$$;
revoke execute on function public.role_permission_catalog() from public, anon;

-- The existing whole-list writer now reads the catalog instead of its
-- own copy, so the two can never disagree about what a permission is.
do $patch$
declare v_def text; v_new text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='set_role_permissions';
  if v_def is null then raise exception '0195: set_role_permissions not found'; end if;
  v_old := E'  v_catalog text[] := array[\n';
  if position(v_old in v_def) = 0 then
    raise exception '0195: set_role_permissions catalog anchor missing';
  end if;
  -- 's' so that `.` crosses newlines: the catalog literal spans several
  -- lines, and with 'n' this matched NOTHING, returned the definition
  -- unchanged, and re-created the function identically. A patch that
  -- asserts its anchor and then silently does nothing is the failure
  -- #1092 is about, committed here by the same hand that wrote the lint.
  v_new := regexp_replace(
    v_def,
    '  v_catalog text\[\] := array\[.*?\];',
    '  v_catalog text[] := public.role_permission_catalog();',
    's');
  -- The post-condition the first attempt lacked. An anchor that exists
  -- proves where to cut, never that the cut happened.
  if v_new = v_def then
    raise exception '0195: the catalog replacement changed nothing';
  end if;
  if position('role_permission_catalog()' in v_new) = 0 then
    raise exception '0195: the replacement did not install the catalog call';
  end if;
  execute v_new;
end
$patch$;

-- ── one booking rule, merged where the row is ──────────────────────
create or replace function public.set_booking_rule(
  p_workspace_id uuid, p_key text, p_value jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_rules jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only workspace settings managers may change the booking rules';
  end if;
  -- The key space is the client's, not free text: a typo must not
  -- silently add a rule nothing reads.
  if p_key !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'unknown booking rule %', p_key;
  end if;
  update public.workspaces
     set booking_rules = jsonb_set(
           coalesce(booking_rules, '{}'::jsonb), array[p_key], p_value, true)
   where id = p_workspace_id
  returning booking_rules into v_rules;
  if v_rules is null then raise exception 'unknown workspace'; end if;
  return v_rules;
end $$;
revoke execute on function public.set_booking_rule(uuid, text, jsonb) from public, anon;

-- ── one permission, granted or revoked where the row is ────────────
create or replace function public.set_role_permission(
  p_workspace_id uuid, p_role text, p_permission text, p_enabled boolean
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_next jsonb;
begin
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then
    raise exception 'unknown role';
  end if;
  if not (p_permission = any(public.role_permission_catalog())) then
    raise exception 'unknown permission %', p_permission;
  end if;

  -- The read and the write are ONE statement against the live row, so a
  -- concurrent flip of a DIFFERENT permission survives this one.
  update public.workspaces w
     set role_permissions = jsonb_set(
           coalesce(w.role_permissions, '{}'::jsonb),
           array[p_role],
           coalesce((
             select jsonb_agg(value order by value)
               from (
                 select value
                   from jsonb_array_elements_text(
                          coalesce(w.role_permissions->p_role, '[]'::jsonb))
                  where value <> p_permission
                 union
                 select p_permission where p_enabled
               ) t(value)
           ), '[]'::jsonb),
           true)
   where w.id = p_workspace_id
  returning w.role_permissions into v_next;
  if v_next is null then raise exception 'unknown workspace'; end if;
  return v_next;
end $$;
revoke execute on function public.set_role_permission(uuid, text, text, boolean) from public, anon;
