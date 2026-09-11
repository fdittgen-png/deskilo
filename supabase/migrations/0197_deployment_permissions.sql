-- SPDX-License-Identifier: 0BSD
-- 0197 — #1080: a deployment stops being a way around the permissions.
--
-- 0186 widened two guards so a deployment could reach through them:
--
--   export_workspace_configuration   exportData          OR deploying_touches
--   import_workspace_configuration   manageConfiguration OR deploying_touches
--
-- `deploy_entities` sets `deploying_touches` for BOTH sides, and 0187
-- widened `may_deploy` to accept the direction permission on EITHER
-- side. `deployToDev` is an admin default (0185); `exportData`,
-- `manageConfiguration` and `accessProd` are not.
--
-- So an admin holding only `deployToDev` could call
-- `deploy_entities(prod, dev, ['identity','payment_instructions','roles'])`
-- and read production's IBAN, VAT id and role matrix into a workspace
-- they can read — and into `deployments.snapshot`, where it stays. The
-- same call the other way overwrote the dev matrix with permissions an
-- owner had deliberately removed.
--
-- The rule this restores: a permission is held on the side it acts on.
--
--   reading a side   requires exportData          on THAT side
--   writing a side   requires manageConfiguration on THAT side
--   the direction    requires deployToDev/Prod    on the side WRITTEN
--
-- `deploying_touches` keeps its real job — letting the definer functions
-- reach each other inside a deployment — but it no longer stands in for
-- a permission the caller does not hold. A transaction-local setting is
-- a capability token for plumbing, not an authorisation.
--
-- This is deliberately stricter than before: an admin who may refresh
-- the dev but may not export now cannot, because refreshing the dev from
-- the prod IS reading the prod's configuration. That is the point.

do $patch$
declare v_def text; v_old text;
begin
  -- ── the export guard ─────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='export_workspace_configuration';
  if v_def is null then raise exception '0197: export_workspace_configuration not found'; end if;
  v_old := '  if auth.uid() is null or not (public.has_permission(p_workspace_id, ''exportData'') or public.deploying_touches(p_workspace_id)) then';
  if position(v_old in v_def) = 0 then
    raise exception '0197: export guard anchor missing';
  end if;
  v_def := replace(v_def, v_old,
    '  if auth.uid() is null or not public.has_permission(p_workspace_id, ''exportData'') then');
  execute v_def;

  -- ── the import guard ─────────────────────────────────────────────
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='import_workspace_configuration';
  if v_def is null then raise exception '0197: import_workspace_configuration not found'; end if;
  v_old := '  if auth.uid() is null or not (public.has_permission(p_workspace_id, ''manageConfiguration'') or public.deploying_touches(p_workspace_id)) then';
  if position(v_old in v_def) = 0 then
    raise exception '0197: import guard anchor missing';
  end if;
  v_def := replace(v_def, v_old,
    '  if auth.uid() is null or not public.has_permission(p_workspace_id, ''manageConfiguration'') then');
  execute v_def;
end
$patch$;

-- ── the direction is held where the WRITE lands ────────────────────
-- 0187 accepted the permission on either side, which let a dev-side
-- admin initiate a deployment that reads the prod. The write is the act
-- that needs authorising, so the permission belongs to the target.
create or replace function public.may_deploy(p_from uuid, p_to uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case public.deployment_direction(p_from, p_to)
    when 'dev_to_prod' then public.has_permission(p_to, 'deployToProd')
    else public.has_permission(p_to, 'deployToDev') end;
$fn$;
revoke execute on function public.may_deploy(uuid, uuid) from public, anon;
