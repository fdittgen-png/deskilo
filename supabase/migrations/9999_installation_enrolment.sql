-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one new table, three operator functions, one guard trigger and
-- three platform settings. No existing row is read or rewritten.
--
-- #2562 C2a -- a personal home enrols the workspace installations its
-- people may be sent to, explicitly, and only its operator can.
--
-- A public directory listing (0347 `public_directory_sources`) says that an
-- installation exists; it is not trust. `enrolled_installations` is the one
-- purpose-specific relation a personal home keeps of the workspace hosts its
-- operator approved: the installation's immutable id, its validated HTTPS
-- origin and publishable key, the roles and capability versions it
-- advertised when it was inspected, whether it accepts new workspaces, and
-- whether the enrolment is still in force. It is not a second client
-- registry: the identity-only OAuth client a workspace host signs people in
-- with stays in `identity_federation_clients` (0292/0564).
--
--   * `operator_enrol_installation` records or refreshes one enrolment and
--     `operator_revoke_installation` ends it. They are operator functions in
--     the sense of 0312/0318/0559: SECURITY DEFINER, executable by nobody the
--     API lets in, reached only through the Management API by the operator's
--     tooling (`dart run tool/instance.dart enrol`, the instance wizard).
--     Workspace ownership grants nothing here. Every change is audited in
--     `database_authority_audit`; an unchanged call writes nothing.
--   * Only a personal home enrols (55000), never itself (22023), and only an
--     installation that advertises `workspace_host` with `workspace@1`. The
--     key must be a publishable one: a secret pasted by mistake is refused
--     before it is stored. One origin names one installation (23505).
--   * An enrolment is revoked, never forgotten: the guard trigger refuses a
--     delete and any change of the installation id. Re-enrolling a revoked
--     installation brings it back, audited like any other change.
--   * Nobody reads the table through the API in this checkpoint: no grant to
--     anon, authenticated or service_role. It carries the restrictive
--     `mcp_delegated_deny` and `personal_native_session` policies all the
--     same (no workspace_id: a personal surface by the 0564 inventory).
--
-- The freshness of the identity status a workspace host will hold (C2b) is
-- configuration, not code: three platform settings in the registry, edited
-- in the settings editor. The assertion lifetime is at most 900 seconds for
-- the deadline #2562 promises, reconciliation runs every 300 seconds by
-- default, and the allowed clock skew is 0..30 seconds.
--
-- pgTAP 271 proves the table, the guard, the functions, their effective
-- privileges and the settings.

-- ── the relation ─────────────────────────────────────────────────────
create table if not exists public.enrolled_installations (
  installation_id uuid primary key,
  origin text not null unique
    check (origin ~ '^https://[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?$'),
  publishable_key text not null
    check (public.is_publishable_backend_key(publishable_key)),
  roles text[] not null
    check (roles <@ array['personal_home', 'workspace_host']::text[]
           and 'workspace_host' = any (roles)),
  capability_versions text[] not null
    check ('workspace@1' = any (capability_versions)),
  accepting_new_workspaces boolean not null default true,
  enabled boolean not null default true,
  enrolled_by text not null default 'operator' check (enrolled_by = 'operator'),
  enrolled_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint enrolled_installations_revoked check (enabled = (revoked_at is null))
);
select public.ensure_system_columns('enrolled_installations');
comment on table public.enrolled_installations is
  '#2562 C2a -- the workspace installations this personal home''s operator '
  'enrolled. Written only by operator_enrol_installation and '
  'operator_revoke_installation; revoked, never deleted.';
alter table public.enrolled_installations enable row level security;
revoke all on public.enrolled_installations from public, anon, authenticated, service_role;
drop policy if exists mcp_delegated_deny on public.enrolled_installations;
create policy mcp_delegated_deny on public.enrolled_installations
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.enrolled_installations;
create policy personal_native_session on public.enrolled_installations
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

create or replace function public.protect_enrolled_installation()
returns trigger language plpgsql set search_path = '' as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'an enrolment is revoked, never forgotten' using errcode = '55000';
  end if;
  if new.installation_id <> old.installation_id then
    raise exception 'an enrolled installation keeps its id' using errcode = '55000';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.protect_enrolled_installation() from public, anon, authenticated, service_role;
drop trigger if exists protect_enrolled_installation on public.enrolled_installations;
create trigger protect_enrolled_installation
  before update or delete on public.enrolled_installations
  for each row execute function public.protect_enrolled_installation();

-- ── the operator functions ───────────────────────────────────────────
create or replace function public.operator_enrol_installation(
  p_installation_id uuid, p_origin text, p_publishable_key text,
  p_roles text[], p_capability_versions text[],
  p_accepting_new_workspaces boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_origin text := nullif(lower(trim(trailing '/' from trim(coalesce(p_origin, '')))), '');
  v_key text := nullif(trim(coalesce(p_publishable_key, '')), '');
  v_roles text[];
  v_caps text[];
  v_other uuid;
  v_before jsonb;
  v_after jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('enrolled_installations', 2562));
  if not exists (select 1 from public.installation_identity
                  where 'personal_home' = any (roles)) then
    raise exception 'this installation is not a personal home: it enrols no workspace installation'
      using errcode = '55000';
  end if;
  if p_installation_id is null or p_accepting_new_workspaces is null then
    raise exception 'an enrolment names the installation and whether it accepts new workspaces'
      using errcode = '22023';
  end if;
  if p_installation_id = public.installation_id() then
    raise exception 'an installation does not enrol itself' using errcode = '22023';
  end if;
  if v_origin is null or v_origin !~ '^https://[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?$' then
    raise exception 'an installation is enrolled by its HTTPS origin, without a path'
      using errcode = '22023';
  end if;
  -- A publishable key, by 0565's classification: a secret is refused
  -- before it is stored.
  if not public.is_publishable_backend_key(v_key) then
    raise exception 'an installation is enrolled with its publishable key, never a secret one'
      using errcode = '22023';
  end if;
  select array_agg(distinct r order by r) into v_roles
    from unnest(coalesce(p_roles, '{}'::text[])) r;
  if v_roles is null
     or not (v_roles <@ array['personal_home', 'workspace_host']::text[])
     or not ('workspace_host' = any (v_roles)) then
    raise exception 'only an installation that hosts workspaces is enrolled'
      using errcode = '22023';
  end if;
  select array_agg(distinct c order by c) into v_caps
    from unnest(coalesce(p_capability_versions, '{}'::text[])) c;
  if v_caps is null or exists (select 1 from unnest(v_caps) c where c !~ '^[a-z]+@[0-9]+$')
     or not ('workspace@1' = any (v_caps)) then
    raise exception 'the installation must advertise workspace@1' using errcode = '22023';
  end if;
  select installation_id into v_other from public.enrolled_installations
   where origin = v_origin and installation_id <> p_installation_id;
  if v_other is not null then
    raise exception 'the origin % is already enrolled for installation %', v_origin, v_other
      using errcode = '23505';
  end if;
  select jsonb_build_object('origin', origin, 'publishable_key', publishable_key,
           'roles', to_jsonb(roles), 'capability_versions', to_jsonb(capability_versions),
           'accepting_new_workspaces', accepting_new_workspaces, 'enabled', enabled)
    into v_before
    from public.enrolled_installations where installation_id = p_installation_id;
  v_after := jsonb_build_object('origin', v_origin, 'publishable_key', v_key,
    'roles', to_jsonb(v_roles), 'capability_versions', to_jsonb(v_caps),
    'accepting_new_workspaces', p_accepting_new_workspaces, 'enabled', true);
  if v_before = v_after then
    return jsonb_build_object('installation_id', p_installation_id, 'status', 'enrolled',
                              'unchanged', true);
  end if;
  insert into public.enrolled_installations as e
    (installation_id, origin, publishable_key, roles, capability_versions,
     accepting_new_workspaces)
  values (p_installation_id, v_origin, v_key, v_roles, v_caps, p_accepting_new_workspaces)
  on conflict (installation_id) do update
    set origin = excluded.origin,
        publishable_key = excluded.publishable_key,
        roles = excluded.roles,
        capability_versions = excluded.capability_versions,
        accepting_new_workspaces = excluded.accepting_new_workspaces,
        enabled = true,
        revoked_at = null,
        enrolled_at = case when e.enabled then e.enrolled_at else now() end;
  -- The key is publishable, but the audit names what changed, not keys.
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'installation_enrolled', 'operator',
          jsonb_build_object('enrolled_installation_id', p_installation_id,
            'from', v_before - 'publishable_key', 'to', v_after - 'publishable_key',
            'key_changed', v_before is null
                           or v_before->>'publishable_key' is distinct from v_key));
  return jsonb_build_object('installation_id', p_installation_id, 'status', 'enrolled',
                            'unchanged', false);
end;
$fn$;
revoke execute on function public.operator_enrol_installation(uuid, text, text, text[], text[], boolean)
  from public, anon, authenticated, service_role;

create or replace function public.operator_revoke_installation(p_installation_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_enabled boolean;
begin
  perform pg_advisory_xact_lock(hashtextextended('enrolled_installations', 2562));
  select enabled into v_enabled from public.enrolled_installations
   where installation_id = p_installation_id;
  if v_enabled is null then
    raise exception 'installation % is not enrolled here', p_installation_id
      using errcode = 'P0002';
  end if;
  if not v_enabled then
    return jsonb_build_object('installation_id', p_installation_id, 'status', 'revoked',
                              'unchanged', true);
  end if;
  update public.enrolled_installations
     set enabled = false, accepting_new_workspaces = false, revoked_at = now()
   where installation_id = p_installation_id;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'installation_enrolment_revoked', 'operator',
          jsonb_build_object('enrolled_installation_id', p_installation_id));
  return jsonb_build_object('installation_id', p_installation_id, 'status', 'revoked',
                            'unchanged', false);
end;
$fn$;
revoke execute on function public.operator_revoke_installation(uuid)
  from public, anon, authenticated, service_role;

-- What the operator's tooling lists: every enrolment, revoked ones too.
create or replace function public.operator_enrolled_installations()
returns table (installation_id uuid, origin text, roles text[],
               capability_versions text[], accepting_new_workspaces boolean,
               enabled boolean, enrolled_at timestamptz, revoked_at timestamptz)
language sql stable security definer set search_path = public as $fn$
  select e.installation_id, e.origin, e.roles, e.capability_versions,
         e.accepting_new_workspaces, e.enabled, e.enrolled_at, e.revoked_at
    from public.enrolled_installations e
   order by e.enabled desc, e.origin;
$fn$;
revoke execute on function public.operator_enrolled_installations()
  from public, anon, authenticated, service_role;

-- ── the identity freshness settings (read by C2b) ─────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('identity.status_assertion_lifetime_seconds', 'duration', '900'::jsonb, 60, 900, 'seconds', 'security', array['platform'], 'workspaceSettings', 60, true, null, 'identity status assertions (#2562)', 'How long a workspace server may rely on one identity status the personal home signed, counted from when the home issued it. At most 900 seconds: a suspended account is refused new requests within this time plus the allowed clock skew. Tightening it never extends a status already issued.'),
('identity.status_reconcile_seconds', 'duration', '300'::jsonb, 30, 900, 'seconds', 'security', array['platform'], 'workspaceSettings', null, true, null, 'identity status assertions (#2562)', 'Seconds between two reconciliations of the identity status a workspace server holds for its linked people, independent of the app. Keep it below the assertion lifetime, or statuses lapse to stale between two runs.'),
('identity.clock_skew_seconds', 'duration', '30'::jsonb, 0, 30, 'seconds', 'security', array['platform'], 'workspaceSettings', null, true, null, 'identity status assertions (#2562)', 'Seconds of clock difference between the personal home and a workspace server that are still accepted: a status issued further in the future is refused, and an expired one is honoured no longer than this.')
on conflict (key) do nothing;
-- END GENERATED SEED

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
