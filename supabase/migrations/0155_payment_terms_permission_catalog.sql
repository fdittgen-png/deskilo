-- SPDX-License-Identifier: 0BSD
-- 0155 — #881: the paymentTermsEdit permission joins the catalog
-- set_role_permissions accepts (0144 refused every payload that named
-- a permission outside its array — #816). Full body, so the catalog
-- literal below IS the latest one the client test mirrors.
create or replace function public.set_role_permissions(p_workspace_id uuid, p_role text, p_permissions text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_catalog text[] := array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations',
    'paymentTermsEdit'];
  v_perm text;
begin
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then
    raise exception 'unknown role';
  end if;
  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not (v_perm = any(v_catalog)) then
      raise exception 'unknown permission %', v_perm;
    end if;
  end loop;
  update public.workspaces
    set role_permissions = jsonb_set(
      coalesce(role_permissions, '{}'::jsonb),
      array[p_role],
      coalesce(to_jsonb(p_permissions), '[]'::jsonb))
    where id = p_workspace_id;
end;
$$;
