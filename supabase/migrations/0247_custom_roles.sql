-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0247 (#1287) — roles a workspace defines itself.
--
-- ADR 0029: a custom role is an ADDITIVE grant on top of a member's base
-- role. It never removes a permission and never replaces the base, so
-- every existing policy stays correct both while the feature is off and
-- while it is on, and no migration re-derives anybody's authority.
--
--   * `workspace_roles` — key, permissions, per-locale names, order,
--     active — and `workspace_role_members`, the join. **No write policy
--     on either**: rows arrive through the definers below, which check
--     ownership of the WORKSPACE. A grant row never proves access
--     (the `quota_extensions` precedent).
--   * `set_workspace_role` is owner-only and validates every permission
--     against `role_permission_catalog()` (0195), so a custom role can
--     never hold a permission the product does not have, and refuses the
--     four built-in keys.
--   * `assign_workspace_role` needs `manageRoles` and refuses **yourself**
--     — the shape `set_member_simultaneous_limit` already uses.
--   * `has_permission_raw` and `member_has_permission` gain one `EXISTS`
--     each, as a UNION: a workspace with no custom roles evaluates
--     exactly what it evaluated before, which is what makes this safe to
--     apply before any screen exists.
--   * both new branches read the flag off the workspace row they already
--     joined — `feature_effective_in(w.feature_flags, 'customRoles')`,
--     exactly as the `adminInvoicing` branch beside them has since 0227
--     (#1333). Switching the feature off withdraws every custom grant
--     and keeps the assignments, so switching it back on restores who
--     had what. The flag itself is added to `feature_registry()` below
--     (regenerated from featureManifest by
--     `dart run tool/build_feature_registry_sql.dart`).
--
--   * `export_my_data` gains `custom_roles` — which roles this member was
--     given, and when. The roles themselves are the workspace's
--     configuration, not the subject's data, and do not travel with a
--     template yet (#1505).
--
-- An owner keeps every permission whatever the custom roles say: the
-- owner branch is first in the union and untouched.

create table if not exists public.workspace_roles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  key text not null check (key ~ '^[a-z][a-z0-9_]{1,30}$'),
  permissions text[] not null default '{}',
  names jsonb not null default '{}'::jsonb,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_roles');
create unique index if not exists workspace_roles_key
  on public.workspace_roles (workspace_id, key);

create table if not exists public.workspace_role_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  role_id uuid not null references public.workspace_roles(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_role_members');
create unique index if not exists workspace_role_members_once
  on public.workspace_role_members (role_id, member_id);
create index if not exists workspace_role_members_by_member
  on public.workspace_role_members (workspace_id, member_id);

alter table public.workspace_roles enable row level security;
alter table public.workspace_role_members enable row level security;

drop policy if exists workspace_roles_select on public.workspace_roles;
create policy workspace_roles_select on public.workspace_roles
  for select to authenticated using (public.is_member_of(workspace_id));

drop policy if exists workspace_role_members_select on public.workspace_role_members;
create policy workspace_role_members_select on public.workspace_role_members
  for select to authenticated using (public.is_member_of(workspace_id));

revoke all on table public.workspace_roles from anon, authenticated;
revoke all on table public.workspace_role_members from anon, authenticated;
grant select on table public.workspace_roles to authenticated;
grant select on table public.workspace_role_members to authenticated;

create or replace function public.member_custom_permissions(p_member_id uuid)
returns text[]
language sql stable security definer set search_path = public as $fn$
  select coalesce(array_agg(distinct p), '{}'::text[])
    from public.workspace_role_members rm
    join public.workspace_roles r on r.id = rm.role_id and r.active
    cross join unnest(r.permissions) p
   where rm.member_id = p_member_id;
$fn$;

revoke execute on function public.member_custom_permissions(uuid) from public, anon;
grant execute on function public.member_custom_permissions(uuid) to authenticated;

create or replace function public.set_workspace_role(
  p_workspace_id uuid,
  p_key text,
  p_permissions text[],
  p_names jsonb default '{}'::jsonb,
  p_sort_order int default 0,
  p_active boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_perm text;
  v_locale text;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner defines the roles of a workspace';
  end if;
  if not public.feature_effective(p_workspace_id, 'customRoles') then
    raise exception 'custom roles are off in this workspace';
  end if;
  if p_key !~ '^[a-z][a-z0-9_]{1,30}$' then
    raise exception 'a role key is lower-case letters, digits and underscores';
  end if;
  if p_key in ('owner', 'co_owner', 'admin', 'member') then
    raise exception 'the built-in roles are not redefined here';
  end if;
  foreach v_perm in array coalesce(p_permissions, '{}'::text[]) loop
    if not (v_perm = any(public.role_permission_catalog())) then
      raise exception 'unknown permission %', v_perm;
    end if;
  end loop;
  for v_locale in select jsonb_object_keys(coalesce(p_names, '{}'::jsonb)) loop
    if v_locale not in ('en','fr','de','es','it') then
      raise exception 'unsupported locale %', v_locale;
    end if;
    if jsonb_typeof(p_names->v_locale) <> 'string'
       or btrim(p_names->>v_locale) = '' then
      raise exception 'the name for % is empty', v_locale;
    end if;
  end loop;

  insert into public.workspace_roles
    (workspace_id, key, permissions, names, sort_order, active)
  values (p_workspace_id, p_key, coalesce(p_permissions, '{}'::text[]),
          coalesce(p_names, '{}'::jsonb), coalesce(p_sort_order, 0),
          coalesce(p_active, true))
  on conflict (workspace_id, key) do update
    set permissions = excluded.permissions,
        names = excluded.names,
        sort_order = excluded.sort_order,
        active = excluded.active
  returning id into v_id;
  return v_id;
end $fn$;

revoke execute on function public.set_workspace_role(uuid, text, text[], jsonb, int, boolean)
  from public, anon;
grant execute on function public.set_workspace_role(uuid, text, text[], jsonb, int, boolean)
  to authenticated;

create or replace function public.assign_workspace_role(
  p_member_id uuid, p_role_id uuid, p_assign boolean default true
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_role_ws uuid;
  v_is_me boolean;
begin
  select m.workspace_id, (m.user_id = auth.uid())
    into v_ws, v_is_me
    from public.members m where m.id = p_member_id;
  if v_ws is null then raise exception 'unknown member'; end if;
  select r.workspace_id into v_role_ws
    from public.workspace_roles r where r.id = p_role_id;
  if v_role_ws is null or v_role_ws <> v_ws then
    raise exception 'that role belongs to another workspace';
  end if;
  if auth.uid() is null or not public.has_permission(v_ws, 'manageRoles') then
    raise exception 'only someone who manages the roles may assign one';
  end if;
  if v_is_me then
    raise exception 'a role is never assigned to yourself';
  end if;
  if not public.feature_effective(v_ws, 'customRoles') then
    raise exception 'custom roles are off in this workspace';
  end if;

  if p_assign then
    insert into public.workspace_role_members (workspace_id, role_id, member_id)
    values (v_ws, p_role_id, p_member_id)
    on conflict (role_id, member_id) do nothing;
  else
    delete from public.workspace_role_members
     where role_id = p_role_id and member_id = p_member_id;
  end if;
end $fn$;

revoke execute on function public.assign_workspace_role(uuid, uuid, boolean)
  from public, anon;
grant execute on function public.assign_workspace_role(uuid, uuid, boolean)
  to authenticated;

-- The union, on both resolvers. `has_permission_raw` is the one every
-- policy reaches through `has_permission`; `member_has_permission`
-- answers for a member row rather than the caller.
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

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  -- The caller's own permissions.
  v_def := pg_get_functiondef('public.has_permission_raw(uuid, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  select exists (
    select 1 from public.members m join public.workspaces w on w.id = ws$a$,
    $a$  select exists (
    select 1 from public.members m join public.workspaces w on w.id = ws
     where m.workspace_id = ws and m.user_id = auth.uid() and m.status = 'active'
       and public.feature_effective_in(w.feature_flags, 'customRoles')
       and perm = any(public.member_custom_permissions(m.id)))
  or exists (
    select 1 from public.members m join public.workspaces w on w.id = ws$a$);
  if v_patched is null then v_missing := v_missing || 'has_permission_raw'::text;
  else execute v_patched; end if;

  -- The same question about somebody else's membership.
  v_def := pg_get_functiondef('public.member_has_permission(uuid, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  select exists (select 1 from public.members m join public.workspaces w on w.id = m.workspace_id$a$,
    $a$  select exists (select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id and m.status = 'active'
      and public.feature_effective_in(w.feature_flags, 'customRoles')
      and perm = any(public.member_custom_permissions(m.id)))
  or exists (select 1 from public.members m join public.workspaces w on w.id = m.workspace_id$a$);
  if v_patched is null then v_missing := v_missing || 'member_has_permission'::text;
  else execute v_patched; end if;

  -- A subject-access export says which roles this member was given, and
  -- when. `workspace_roles` itself is the workspace's configuration and
  -- is not the subject's data; the grant is.
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    'exported_at', now(),$a$,
    $a$    'exported_at', now(),
    'custom_roles', (select coalesce(jsonb_agg(jsonb_build_object(
                         'key', r.key, 'names', r.names,
                         'permissions', r.permissions,
                         'granted_at', rm.created_at)), '[]')
                       from public.workspace_role_members rm
                       join public.workspace_roles r on r.id = rm.role_id
                      where rm.member_id = v_me.id),$a$);
  if v_patched is null then v_missing := v_missing || 'export_my_data'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0247: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

-- ── the flag: customRoles, platform, off ─────────────────────────────
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": null, "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the association builtin names the new flag explicitly ──────────
-- (`template_contract_test`: a builtin's feature_flags name every feature;
-- supabase/templates/association_fr.json was regenerated by
-- `dart run tool/build_builtin_templates.dart` and this is that file.)
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'features'],
  $cfg$
{
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "carnets": false,
      "coOwner": false,
      "configurationTransfer": false,
      "customRoles": false,
      "dataAccessLog": false,
      "dataExport": true,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "financeFaces": true,
      "formHelpHints": true,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageGestures": true,
      "messagesHub": true,
      "moneyTab": true,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "priceNegotiations": false,
      "publicHolidays": false,
      "pushNotifications": true,
      "qrBadges": false,
      "regionalFormats": true,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleManagement": true,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "services": true,
      "settlementFold": false,
      "singleRoomLevelNames": true,
      "siteDocuments": false,
      "spaceQrCodes": true,
      "subscriptionInvoices": false,
      "supplyExpenses": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceStatus": false,
      "workspaceVocabulary": false
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}
$cfg$::jsonb,
  $tpl$
[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]
$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

select public.set_deskilo_schema_version(247);
