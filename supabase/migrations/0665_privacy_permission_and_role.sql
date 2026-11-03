-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3278 (1 of 2) -- the permission and the role of whoever handles the members'
-- personal data.
--
-- * `managePrivacy` joins the permission catalogue. An owner holds every
--   permission; a co-owner holds it by default (an explicit co-owner list that
--   omits it stays as chosen); an admin does not.
-- * `rights_controller` -- who decides the rights requests of 0327 -- is an
--   owner, or `viewPersonalData` (as before), or `managePrivacy`.
-- * A custom role "Personal Data Admin" (additive, ADR 0029) is seeded in every
--   workspace, new and existing. It holds `managePrivacy` and nobody until the
--   owner assigns it; its grants count while `customRoles` is on, and the owner
--   can also give the permission to a built-in role in the matrix.
-- Nobody loses anything: no one held a permission that did not exist.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── the permission catalogue knows `managePrivacy` (0473's body, one more) ──
create or replace function public.role_permission_catalog()
returns text[] language sql immutable as $$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments','managePurchases','recordOutgoingPayments',
    'manageLease','managePrivacy'];
$$;
revoke execute on function public.role_permission_catalog() from public, anon;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.rights_controller(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$or public.has_permission(p_workspace_id, 'viewPersonalData'));$a$,
    $a$or public.has_permission(p_workspace_id, 'viewPersonalData')
          or public.has_permission(p_workspace_id, 'managePrivacy'));$a$);
  if v_def is null then raise exception '0665: rights_controller anchor missing'; end if;
  execute v_def;

  -- A mirror import puts aside the roles the file does not carry; it must not
  -- silently withdraw the Personal Data Admin grants, so that key is kept like
  -- the Administrator (a deliberate deactivation by the owner still works).
  select pg_get_functiondef('public.workspace_roles_import(uuid,jsonb,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$          and not r.builtin
          and not exists (select 1 from jsonb_array_elements(p_roles) e2$a$,
    $a$          and not r.builtin
          and r.key <> 'personal_data_admin'
          and not exists (select 1 from jsonb_array_elements(p_roles) e2$a$);
  if v_def is null then raise exception '0665: workspace_roles_import check anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$       and not r.builtin
       and not exists (select 1 from jsonb_array_elements(p_roles) e$a$,
    $a$       and not r.builtin
       and r.key <> 'personal_data_admin'
       and not exists (select 1 from jsonb_array_elements(p_roles) e$a$);
  if v_def is null then raise exception '0665: workspace_roles_import update anchor missing'; end if;
  execute v_def;
end
$migration$;

create or replace function public.personal_data_admin_role_names()
returns jsonb language sql immutable set search_path = '' as $fn$
  select jsonb_build_object(
    'en', 'Personal Data Admin',
    'fr', 'Administrateur des données personnelles',
    'de', 'Verantwortliche/r für personenbezogene Daten',
    'es', 'Administrador de datos personales',
    'it', 'Amministratore dei dati personali');
$fn$;
revoke execute on function public.personal_data_admin_role_names() from public, anon;

-- One seeded role per workspace; a role the owner has already created, renamed
-- or deleted under this key is left as it is (the unique key makes the insert a
-- no-op), and a deleted one is not brought back by the trigger, only by a new
-- workspace.
create or replace function public.ensure_personal_data_admin_role(p_workspace_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  select r.id into v_id from public.workspace_roles r
   where r.workspace_id = p_workspace_id and r.key = 'personal_data_admin';
  if v_id is not null then return v_id; end if;
  insert into public.workspace_roles
    (workspace_id, key, permissions, names, sort_order, active, builtin)
  values (p_workspace_id, 'personal_data_admin', array['managePrivacy']::text[],
          public.personal_data_admin_role_names(), 90, true, false)
  returning id into v_id;
  return v_id;
end $fn$;
revoke execute on function public.ensure_personal_data_admin_role(uuid) from public, anon, authenticated;

create or replace function public.workspaces_personal_data_admin_role()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.ensure_personal_data_admin_role(new.id);
  return null;
end $fn$;
revoke execute on function public.workspaces_personal_data_admin_role() from public, anon, authenticated;

drop trigger if exists workspaces_personal_data_admin_role on public.workspaces;
create trigger workspaces_personal_data_admin_role
  after insert on public.workspaces
  for each row execute function public.workspaces_personal_data_admin_role();

-- Existing workspaces (the same one-row insert, per workspace).
select public.ensure_personal_data_admin_role(w.id) from public.workspaces w;

select public.set_deskilo_schema_version(665);
