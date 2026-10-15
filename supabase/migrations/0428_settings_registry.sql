-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0428 (#2484, S1 of #2483) -- the settings registry.
--
-- A business value outside VAT (a limit, a window, a lifetime, a default) is
-- a SETTING: declared once in `setting_definitions` (type, default, bounds,
-- security floor, owner), stored as versions in `setting_values` (platform
-- or workspace scope; a change closes the previous version, never edits it)
-- and resolved by ONE function, `setting_value(workspace, key)`: workspace
-- value, else platform value, else the registry default, with the bounds
-- and the floor enforced. The app reads the same rows through `my_settings`.
-- Writes go through `set_setting` only: the definition's permission decides
-- who, the platform owner alone writes the platform scope, the type, bounds
-- and floor are validated, and every change is audited.
--
-- The proof setting is `dunning.first_after_days` (days before a first
-- reminder, and the payment term frozen on an invoice when the workspace
-- stated one): each workspace's explicit value in `workspaces.dunning_rules`
-- moves to a workspace setting (behaviour unchanged), the rules column
-- mirrors it (a trigger keeps the two in step), and `calendar_items` and
-- `invoice_maturity_freeze` read
-- `setting_value`. A maturity already frozen on an invoice is never
-- recomputed.

-- ── validation: one function says why a value is not acceptable ─────────
create or replace function public.setting_value_problem(
  p_type text, p_value jsonb, p_min numeric, p_max numeric, p_floor numeric, p_choices jsonb)
returns text language plpgsql immutable set search_path = public as $fn$
declare
  v_n numeric;
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then return 'a value is required'; end if;
  case p_type
    when 'int', 'duration' then
      if jsonb_typeof(p_value) <> 'number' then return 'a whole number is required'; end if;
      v_n := (p_value #>> '{}')::numeric;
      if v_n <> trunc(v_n) then return 'a whole number is required'; end if;
      if p_floor is not null and v_n < p_floor then return format('below the security floor of %s', p_floor); end if;
      if p_min is not null and v_n < p_min then return format('below the minimum of %s', p_min); end if;
      if p_max is not null and v_n > p_max then return format('above the maximum of %s', p_max); end if;
    when 'bool' then
      if jsonb_typeof(p_value) <> 'boolean' then return 'true or false is required'; end if;
    when 'text' then
      if jsonb_typeof(p_value) <> 'string' then return 'text is required'; end if;
    when 'enum' then
      if jsonb_typeof(p_value) <> 'string' or p_choices is null or not (p_choices @> to_jsonb(p_value #>> '{}')) then
        return 'not one of the choices';
      end if;
    else
      return 'unknown type';
  end case;
  return null;
end;
$fn$;
revoke execute on function public.setting_value_problem(text, jsonb, numeric, numeric, numeric, jsonb) from public, anon, authenticated;

-- ── the registry ─────────────────────────────────────────────────────────
create table if not exists public.setting_definitions (
  key text primary key check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  type text not null check (type in ('int', 'duration', 'bool', 'text', 'enum')),
  default_value jsonb not null,
  min_value numeric,
  max_value numeric,
  unit text not null default '',
  group_key text not null check (btrim(group_key) <> ''),
  scopes text[] not null check (cardinality(scopes) > 0 and scopes <@ array['platform', 'workspace']),
  edit_permission text not null default '',
  floor_value numeric,
  editable boolean not null default true,
  choices jsonb,
  source text not null default '',
  note text not null default '',
  constraint setting_definitions_default_valid
    check (public.setting_value_problem(type, default_value, min_value, max_value, floor_value, choices) is null),
  constraint setting_definitions_duration_unit
    check (type <> 'duration' or unit in ('seconds', 'minutes', 'hours', 'days')),
  constraint setting_definitions_workspace_permission
    check (not ('workspace' = any (scopes)) or btrim(edit_permission) <> '')
);
select public.ensure_system_columns('setting_definitions');
alter table public.setting_definitions enable row level security;
revoke all on table public.setting_definitions from anon, authenticated;
grant select on table public.setting_definitions to authenticated;
drop policy if exists setting_definitions_select on public.setting_definitions;
create policy setting_definitions_select on public.setting_definitions for select to authenticated using (true);
drop policy if exists mcp_delegated_deny on public.setting_definitions;
create policy mcp_delegated_deny on public.setting_definitions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table if not exists public.setting_values (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('platform', 'workspace')),
  workspace_id uuid references public.workspaces (id) on delete cascade,
  key text not null references public.setting_definitions (key),
  value jsonb not null,
  note text not null default '',
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  changed_by uuid,
  constraint setting_values_scope_workspace check ((scope = 'platform') = (workspace_id is null)),
  constraint setting_values_period check (valid_to is null or valid_to >= valid_from)
);
select public.ensure_system_columns('setting_values');
-- A platform value belongs to no workspace, so it has no company: the
-- stamp derives the company from the workspace and the check that every row
-- has one cannot hold for this table.
alter table public.setting_values drop constraint if exists system_company_present;
-- One version in force per scope, workspace and key.
create unique index if not exists setting_values_one_open
  on public.setting_values (scope, coalesce(workspace_id, '00000000-0000-0000-0000-000000000000'::uuid), key)
  where valid_to is null;
create index if not exists setting_values_by_workspace on public.setting_values (workspace_id, key);
alter table public.setting_values enable row level security;
revoke all on table public.setting_values from anon, authenticated;
grant select on table public.setting_values to authenticated;
drop policy if exists setting_values_select on public.setting_values;
create policy setting_values_select on public.setting_values for select to authenticated
  using (scope = 'platform' or public.is_member_of(workspace_id));
drop policy if exists mcp_delegated_deny on public.setting_values;
create policy mcp_delegated_deny on public.setting_values as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the SQL resolver ─────────────────────────────────────────────────────
-- Workspace value, else platform value, else the registry default; a stored
-- number is held inside the definition's bounds and floor, so a bound tightened
-- later cannot leave a value outside it. A person who is not in the workspace
-- is refused; the server's own callers (no session: triggers, the sweep) pass.
create or replace function public.setting_value(p_workspace uuid, p_key text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  d public.setting_definitions;
  v jsonb;
  v_n numeric;
begin
  select * into d from public.setting_definitions where key = p_key;
  if not found then raise exception 'unknown setting %', p_key; end if;
  if auth.uid() is not null and p_workspace is not null
     and not public.is_member_of(p_workspace) and not public.is_platform_owner() then
    raise exception 'not a member of the workspace';
  end if;
  if p_workspace is not null and 'workspace' = any (d.scopes) then
    select s.value into v from public.setting_values s
     where s.scope = 'workspace' and s.workspace_id = p_workspace and s.key = p_key and s.valid_to is null;
  end if;
  if v is null and 'platform' = any (d.scopes) then
    select s.value into v from public.setting_values s
     where s.scope = 'platform' and s.key = p_key and s.valid_to is null;
  end if;
  v := coalesce(v, d.default_value);
  if d.type in ('int', 'duration') then
    v_n := (v #>> '{}')::numeric;
    v_n := greatest(v_n, coalesce(d.floor_value, v_n), coalesce(d.min_value, v_n));
    v_n := least(v_n, coalesce(d.max_value, v_n));
    v := to_jsonb(v_n::bigint);
  end if;
  return v;
end;
$fn$;
revoke execute on function public.setting_value(uuid, text) from public, anon;
grant execute on function public.setting_value(uuid, text) to authenticated;

-- Where the effective value of a key for a workspace comes from.
create or replace function public.setting_origin(p_workspace uuid, p_key text)
returns text language sql stable security definer set search_path = public as $fn$
  select case
    when p_workspace is not null and exists (select 1 from public.setting_values s
           where s.scope = 'workspace' and s.workspace_id = p_workspace and s.key = p_key and s.valid_to is null)
      then 'workspace'
    when exists (select 1 from public.setting_values s
           where s.scope = 'platform' and s.key = p_key and s.valid_to is null)
      then 'platform'
    else 'default'
  end;
$fn$;
revoke execute on function public.setting_origin(uuid, text) from public, anon, authenticated;

-- The registry and the effective values for the app. p_workspace null is
-- the platform's own view (platform values over defaults).
create or replace function public.my_settings(p_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_workspace is not null and not public.is_member_of(p_workspace) and not public.is_platform_owner() then
    raise exception 'not a member of the workspace';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'key', d.key, 'type', d.type, 'default_value', d.default_value,
             'min', d.min_value, 'max', d.max_value, 'unit', d.unit, 'group_key', d.group_key,
             'scopes', to_jsonb(d.scopes), 'edit_permission', d.edit_permission,
             'floor_value', d.floor_value, 'editable', d.editable, 'choices', d.choices,
             'source', d.source, 'note', d.note,
             'value', public.setting_value(p_workspace, d.key),
             'origin', public.setting_origin(p_workspace, d.key)) order by d.group_key, d.key)
      from public.setting_definitions d), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_settings(uuid) from public, anon;
grant execute on function public.my_settings(uuid) to authenticated;

-- ── history ──────────────────────────────────────────────────────────────
create or replace function public.setting_history(p_workspace uuid, p_key text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_workspace is not null and not public.is_member_of(p_workspace) and not public.is_platform_owner() then
    raise exception 'not a member of the workspace';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'scope', s.scope, 'workspace_id', s.workspace_id, 'key', s.key, 'value', s.value,
             'valid_from', s.valid_from, 'valid_to', s.valid_to, 'note', s.note, 'changed_by', s.changed_by)
           order by s.valid_from desc, s.created_datetime desc)
      from public.setting_values s
     where s.key = p_key
       and ((p_workspace is null and s.scope = 'platform')
         or (p_workspace is not null and s.scope = 'workspace' and s.workspace_id = p_workspace))), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.setting_history(uuid, text) from public, anon;
grant execute on function public.setting_history(uuid, text) to authenticated;

-- ── the one writer ───────────────────────────────────────────────────────
-- Internal: closes the version in force and opens a new one. No permission
-- check -- the callers do theirs; not callable by clients.
create or replace function public.store_setting(
  p_workspace uuid, p_key text, p_value jsonb, p_note text, p_by uuid)
returns boolean language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_scope text := case when p_workspace is null then 'platform' else 'workspace' end;
  v_open public.setting_values;
begin
  perform pg_advisory_xact_lock(hashtextextended('setting:' || v_scope || ':' || coalesce(p_workspace::text, '') || ':' || p_key, 0));
  select * into v_open from public.setting_values s
   where s.scope = v_scope and s.workspace_id is not distinct from p_workspace and s.key = p_key and s.valid_to is null;
  if found then
    if v_open.value = p_value then return false; end if;
    update public.setting_values set valid_to = now() where id = v_open.id;
  end if;
  insert into public.setting_values (scope, workspace_id, key, value, note, changed_by)
  values (v_scope, p_workspace, p_key, p_value, coalesce(p_note, ''), p_by);
  -- The dunning rules mirror this one key (see dunning_rules_sync_setting).
  if p_workspace is not null and p_key = 'dunning.first_after_days' then
    update public.workspaces
       set dunning_rules = dunning_rules || jsonb_build_object('first_after_days', p_value)
     where id = p_workspace and (dunning_rules -> 'first_after_days') is distinct from p_value;
  end if;
  return true;
end;
$fn$;
revoke execute on function public.store_setting(uuid, text, jsonb, text, uuid) from public, anon, authenticated;

create or replace function public.set_setting(p_workspace uuid, p_key text, p_value jsonb, p_note text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  d public.setting_definitions;
  v_problem text;
  v_changed boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated() then raise exception 'not allowed'; end if;
  select * into d from public.setting_definitions where key = p_key;
  if not found then raise exception 'unknown setting %', p_key; end if;
  if not d.editable then raise exception 'the setting % is a guardrail and cannot be changed', p_key; end if;
  if p_workspace is null then
    if not ('platform' = any (d.scopes)) then raise exception 'the setting % has no platform value', p_key; end if;
    if not public.is_platform_owner() then raise exception 'platform owners only'; end if;
  else
    if not ('workspace' = any (d.scopes)) then raise exception 'the setting % is not set per workspace', p_key; end if;
    if not public.has_permission(p_workspace, d.edit_permission) then
      raise exception 'not allowed to change this setting';
    end if;
    if not public.feature_effective(p_workspace, 'configurableSettings') then
      raise exception 'configurable settings are switched off for this workspace';
    end if;
  end if;
  v_problem := public.setting_value_problem(d.type, p_value, d.min_value, d.max_value, d.floor_value, d.choices);
  if v_problem is not null then raise exception 'the value of % is refused: %', p_key, v_problem; end if;
  v_changed := public.store_setting(p_workspace, p_key, p_value, p_note, auth.uid());
  if v_changed then
    insert into public.database_authority_audit (installation_id, action, actor, detail)
    values (public.installation_id(), 'setting_set',
            (case when p_workspace is null then 'platform_owner:' else 'member:' end) || auth.uid(),
            jsonb_build_object('key', p_key, 'workspace_id', p_workspace, 'value', p_value));
  end if;
  return jsonb_build_object('status', case when v_changed then 'saved' else 'unchanged' end,
                            'value', public.setting_value(p_workspace, p_key));
end;
$fn$;
revoke execute on function public.set_setting(uuid, text, jsonb, text) from public, anon;
grant execute on function public.set_setting(uuid, text, jsonb, text) to authenticated;

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('dunning.first_after_days', 'int', '14'::jsonb, 1, 365, 'days', 'dunning', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'DunningRules (#472, 0093, 0134, 0144, 0145)', 'Days after issue before a first reminder is suggested and before an invoice falls due when the workspace stated no payment term.')
on conflict (key) do nothing;
-- END GENERATED SEED


-- ── the proof: dunning.first_after_days ──────────────────────────────────
-- 1. Each workspace's explicit value moves to a workspace setting (the same
--    number, held inside the registry bounds: Dart and calendar_items
--    already read it at least 1); the mirror in the rules stays as it is.
insert into public.setting_values (scope, workspace_id, key, value, note)
select 'workspace', w.id, 'dunning.first_after_days',
       to_jsonb(least(greatest((w.dunning_rules ->> 'first_after_days')::int, 1), 365)),
       'moved from the dunning rules by migration 0428'
  from public.workspaces w
 where w.dunning_rules ? 'first_after_days'
   and (w.dunning_rules ->> 'first_after_days') ~ '^[0-9]{1,6}$'
on conflict do nothing;

-- 2. The dunning rules keep a MIRROR of the key (the configuration transfer,
--    the setup questionnaire's import and the builtin templates still carry
--    `dunning_rules.first_after_days`), and the two are kept in step by the
--    server: a write to the rules moves the value into the setting, a write
--    of the setting (store_setting, below) updates the mirror. The setting
--    is the one the app and the SQL resolver read.
create or replace function public.dunning_rules_sync_setting()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_raw text := new.dunning_rules ->> 'first_after_days';
  v_n int;
begin
  if v_raw is null or v_raw !~ '^[0-9]{1,6}$' then return new; end if;
  v_n := least(greatest(v_raw::int, 1), 365);
  perform public.store_setting(new.id, 'dunning.first_after_days', to_jsonb(v_n), 'dunning rules', auth.uid());
  if v_n <> v_raw::int then
    update public.workspaces
       set dunning_rules = dunning_rules || jsonb_build_object('first_after_days', v_n)
     where id = new.id;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.dunning_rules_sync_setting() from public, anon, authenticated;
drop trigger if exists dunning_rules_sync_setting on public.workspaces;
create trigger dunning_rules_sync_setting
  after insert or update of dunning_rules on public.workspaces
  for each row execute function public.dunning_rules_sync_setting();

-- 3. The payment term frozen at issue reads the setting. A maturity already
--    frozen on an invoice is never recomputed: only a NEW invoice asks.
create or replace function public.invoice_maturity_freeze()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_tz text;
  v_days int;
begin
  select coalesce(nullif(w.timezone, ''), 'UTC') into v_tz
    from public.workspaces w where w.id = new.workspace_id;
  v_days := least(greatest((public.setting_value(new.workspace_id, 'dunning.first_after_days') #>> '{}')::int, 0), 365);
  if public.setting_origin(new.workspace_id, 'dunning.first_after_days') = 'workspace' then
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + v_days, 'document_term', v_days,
            format('the workspace payment term of %s days in force at issue', v_days));
  else
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + v_days, 'default_term', v_days,
            format('no payment term configured; the default of %s days needs review', v_days));
  end if;
  return new;
end $fn$;
revoke execute on function public.invoice_maturity_freeze() from public, anon, authenticated;

-- 4. calendar_items: the three due/reminder dates read the setting. Anchored
--    on the expression, asserted to occur exactly three times.
do $patch$
declare
  v_def text;
  v_re text := 'coalesce\(\s*\(\s*w\.dunning_rules\s*->>\s*''first_after_days''\s*\)\s*::int\s*,\s*14\s*\)';
  v_count int;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'calendar_items';
  select count(*) into v_count from regexp_matches(v_def, v_re, 'g');
  if v_count <> 3 then
    raise exception '0428: calendar_items anchor found % times, expected 3', v_count;
  end if;
  v_def := regexp_replace(v_def, v_re,
    '(public.setting_value(w.id, ''dunning.first_after_days'') #>> ''{}'')::int', 'g');
  execute v_def;
end
$patch$;

-- ── the feature registry: configurableSettings (dart run tool/build_feature_registry_sql.dart) ──
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
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

select public.set_deskilo_schema_version(428);
