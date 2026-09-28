-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0307 (#1636) -- readiness acknowledgements, the issue's last open item.
-- Someone who configures a space can set an optional, still-open section
-- aside ("later") so the checklist's next step moves on. What is stored is
-- only that explicit acknowledgement, keyed by installation, workspace,
-- user and section, with the section's material revision at that moment:
--
--   * readiness_acknowledgements: RLS on; a client reads only its own rows,
--     in this installation, for a workspace it may configure. No client
--     writes it; the delegated-token denial sits on top.
--   * is_this_installation(id): the policy's installation test.
--   * readiness_section_revision(section): md5(state || reason || count),
--     the material the owner saw. Internal only.
--   * acknowledge_readiness_section(workspace, section): manageConfiguration,
--     never a delegated assistant token. Only an optional section that is
--     neither ready nor not applicable; required ones must be set up.
--     Upserts and returns the row, revision taken from the CURRENT output.
--   * clear_readiness_acknowledgement(workspace, section): undo.
--   * workspace_readiness v6: generated from 0301's body; each section
--     gains "acknowledged": true only while the caller's acknowledgement
--     still matches its current revision. A changed state, reason or count
--     silently drops it. It never makes anything ready: stale or missing
--     recovery evidence stays unverified.
--
-- (0303-0306 are #1791's; this follows them.)

create table if not exists public.readiness_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null default public.installation_id(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  section text not null check (section ~ '^[a-z_]{1,64}$'),
  material_revision text not null check (material_revision ~ '^[0-9a-f]{32}$'),
  acknowledged_at timestamptz not null default now(),
  constraint readiness_acknowledgements_key unique (installation_id, workspace_id, user_id, section)
);
select public.ensure_system_columns('readiness_acknowledgements');
create index if not exists readiness_acknowledgements_workspace_idx
  on public.readiness_acknowledgements (workspace_id, user_id);
alter table public.readiness_acknowledgements enable row level security;
revoke all on table public.readiness_acknowledgements from anon, authenticated;
grant select on table public.readiness_acknowledgements to authenticated;
drop policy if exists mcp_delegated_deny on public.readiness_acknowledgements;
create policy mcp_delegated_deny on public.readiness_acknowledgements
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- Whether an id is this installation's, without handing the id itself to
-- a client (installation_id() stays revoked from them).
create or replace function public.is_this_installation(p_installation_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_installation_id is not distinct from public.installation_id();
$fn$;
revoke execute on function public.is_this_installation(uuid) from public, anon;
grant execute on function public.is_this_installation(uuid) to authenticated;
drop policy if exists readiness_acknowledgements_own on public.readiness_acknowledgements;
create policy readiness_acknowledgements_own on public.readiness_acknowledgements
  for select to authenticated
  using (user_id = auth.uid()
         and public.is_this_installation(installation_id)
         and public.has_permission(workspace_id, 'manageConfiguration'));

create or replace function public.readiness_section_revision(p_section jsonb)
returns text language sql immutable set search_path = public as $fn$
  select md5(coalesce(p_section->>'state', '') || coalesce(p_section->>'reason', '')
             || coalesce(p_section->>'count', ''));
$fn$;
revoke execute on function public.readiness_section_revision(jsonb) from public, anon, authenticated;

create or replace function public.workspace_readiness(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_seats integer;
  v_members integer;
  v_invitations integer;
  v_pricing boolean;
  v_payments boolean;
  v_local jsonb;
  v_gap jsonb;
  v_policies integer;
  v_short jsonb;
  v_exposed boolean;
  v_eligibility text;
  v_booked boolean;
  v_export timestamptz;
  v_recent boolean;
  v_out jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace sees how ready it is';
  end if;
  select * into w from public.workspaces where id = p_workspace_id;
  select count(*) into v_seats from public.seats where workspace_id = p_workspace_id;
  select count(*) into v_members from public.members where workspace_id = p_workspace_id and status = 'active';
  select count(*) into v_invitations from public.invitations where workspace_id = p_workspace_id;
  v_pricing := exists (select 1 from public.plans where workspace_id = p_workspace_id)
            or exists (select 1 from public.fee_bands where workspace_id = p_workspace_id)
            or coalesce(jsonb_typeof(w.subscription_levels) = 'object' and w.subscription_levels <> '{}'::jsonb, false);
  v_payments := exists (select 1 from jsonb_each_text(coalesce(w.payment_instructions, '{}'::jsonb)) e where trim(e.value) <> '')
             or exists (select 1 from public.payment_credentials c where c.workspace_id = p_workspace_id);
  -- #1636 — what the features switched on still need locally (0280),
  -- as one section: its first gap is where it is set up.
  v_local := public.workspace_local_readiness(p_workspace_id);
  select e into v_gap from jsonb_array_elements(v_local) e
   where not coalesce((e->>'filled')::boolean, false) limit 1;
  -- #1636 (0294) — a validation policy nobody can satisfy leaves its
  -- requests pending forever. The pool per policy is the one the decision
  -- functions use (0135): the owner, then by scope every active member,
  -- the listed ones, or the admins it admits.
  select count(*) into v_policies from public.validation_policies where workspace_id = p_workspace_id;
  select coalesce(jsonb_agg(p.event_type), '[]'::jsonb) into v_short
    from public.validation_policies p
   where p.workspace_id = p_workspace_id
     and p.required_count > (
       select count(*) from public.members m
        where m.workspace_id = p_workspace_id and m.status = 'active'
          and (m.is_owner
               or coalesce(p.validator_scope, 'admins') = 'members'
               or (coalesce(p.validator_scope, 'admins') = 'listed'
                   and m.id = any(p.eligible_admin_ids))
               or (coalesce(p.validator_scope, 'admins') = 'admins'
                   and m.is_admin and p.admins_may_validate
                   and (cardinality(p.eligible_admin_ids) = 0
                        or m.id = any(p.eligible_admin_ids)))));
  -- #1636 (0294) — assistant access is optional, and listed only while
  -- mcpAccess is on. Two of its gates are readable here: the owner's
  -- exposure of this workspace (0271) and the caller's own current
  -- database eligibility (my_database_capabilities, 1718), which a
  -- database administrator grants once per database.
  v_exposed := exists (select 1 from public.workspace_mcp_policies mp
                        where mp.workspace_id = p_workspace_id and mp.enabled
                          and cardinality(mp.operations) > 0);
  v_eligibility := public.my_database_capabilities()->>'mcp_eligibility';
  -- #1636 (0296) — has the space been used yet: one booking that was not
  -- cancelled or released. Read, never made to find out.
  v_booked := exists (select 1 from public.reservations r
                       where r.workspace_id = p_workspace_id
                         and r.status in ('reserved', 'checked_in', 'completed'));
  -- #1636 (0301) — recovery evidence is a completed export the app
  -- recorded (record_workspace_export), never a checkbox: recent within
  -- 90 days, stale after, none at all otherwise.
  select max(e.recorded_at) into v_export from public.workspace_recovery_evidence e
   where e.workspace_id = p_workspace_id and e.kind = 'export';
  v_recent := v_export is not null and v_export >= now() - interval '90 days';
  v_out := jsonb_build_array(
    jsonb_build_object('section', 'region_rules', 'actor', 'owner', 'required', true, 'route', '/availability',
      'state', case when coalesce(w.timezone, '') <> '' and coalesce(w.currency_code, '') <> ''
                     and case when jsonb_typeof(w.booking_rules->'open_weekdays') = 'array'
                              then jsonb_array_length(w.booking_rules->'open_weekdays') > 0 else false end
                    then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'resources', 'actor', 'owner', 'required', true, 'route', '/editor',
      'state', case when v_seats > 0 then 'ready' else 'needs_configuration' end, 'count', v_seats),
    jsonb_build_object('section', 'pricing', 'actor', 'owner', 'required', false, 'route', '/billing',
      'state', case when v_pricing then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'invitations', 'actor', 'owner', 'required', false, 'route', '/workspace-code',
      'state', case when v_members > 1 or v_invitations > 0 then 'ready' else 'needs_configuration' end,
      'count', v_members),
    jsonb_build_object('section', 'payments', 'actor', 'owner', 'required', false, 'route', '/payment-methods',
      'state', case when v_payments then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'roles_validation', 'actor', 'owner', 'required',
      exists (select 1 from jsonb_array_elements_text(v_short) t where t in ('reservation', 'space_reservation')),
      'route', '/validation',
      'state', case when v_policies = 0 then 'not_applicable'
                    when jsonb_array_length(v_short) > 0 then 'needs_configuration' else 'ready' end,
      'reason', case when v_policies = 0 then 'no_policies'
                     when jsonb_array_length(v_short) > 0 then 'too_few_validators' end,
      'count', jsonb_array_length(v_short)),
    jsonb_build_object('section', 'recovery', 'actor', 'operator', 'required', false,
      'route', '/workspace-settings',
      'state', case when v_recent then 'ready' else 'unverified' end,
      'reason', case when v_export is null then 'no_evidence'
                     when v_recent then 'recent_export' else 'stale_export' end,
      'recorded_at', v_export))
    || case when jsonb_array_length(v_local) = 0 then '[]'::jsonb
       else jsonb_build_array(jsonb_build_object('section', 'local_setup', 'actor', 'owner', 'required', false,
         'route', coalesce(v_gap->>'route', '/workspace-settings'),
         'state', case when v_gap is null then 'ready' else 'needs_configuration' end,
         'count', (select count(*) from jsonb_array_elements(v_local) e
                    where not coalesce((e->>'filled')::boolean, false))))
       end
    || case when not public.feature_effective(p_workspace_id, 'mcpAccess') then '[]'::jsonb
       else jsonb_build_array(jsonb_build_object('section', 'assistant', 'required', false,
         'actor', case when v_exposed then 'administrator' else 'owner' end,
         'route', case when v_exposed then '/assistants' else '/settings/assistants' end,
         'state', case when not v_exposed then 'needs_configuration'
                       when v_eligibility is distinct from 'eligible' then 'needs_operator' else 'ready' end,
         'reason', case when not v_exposed then 'not_exposed'
                        when v_eligibility is distinct from 'eligible'
                        then 'eligibility_' || coalesce(v_eligibility, 'unknown') end))
       end
    || jsonb_build_array(jsonb_build_object('section', 'first_booking', 'actor', 'owner',
         'required', false, 'route', '/reserve',
         'state', case when v_booked then 'ready' else 'needs_configuration' end));
  -- #1636 (0307) -- "I'll do it later": a section the caller set aside
  -- reads acknowledged only while it is still optional, still open, and
  -- still what it was when they set it aside (the same material revision,
  -- in this installation, for this caller). It never changes the state:
  -- an acknowledged recovery section stays unverified.
  return (
    select coalesce(jsonb_agg(
      case when not coalesce((t.e->>'required')::boolean, false)
             and t.e->>'state' not in ('ready', 'not_applicable')
             and exists (select 1 from public.readiness_acknowledgements a
                          where a.installation_id = public.installation_id()
                            and a.workspace_id = p_workspace_id
                            and a.user_id = auth.uid()
                            and a.section = t.e->>'section'
                            and a.material_revision = public.readiness_section_revision(t.e))
           then t.e || jsonb_build_object('acknowledged', true) else t.e end
      order by t.n), '[]'::jsonb)
      from jsonb_array_elements(v_out) with ordinality t(e, n));
end;
$fn$;
revoke execute on function public.workspace_readiness(uuid) from public, anon;
grant execute on function public.workspace_readiness(uuid) to authenticated;

create or replace function public.acknowledge_readiness_section(p_workspace_id uuid, p_section text)
returns public.readiness_acknowledgements language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_sec jsonb;
  v public.readiness_acknowledgements;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace sets a section aside'
      using errcode = '42501';
  end if;
  select e into v_sec from jsonb_array_elements(public.workspace_readiness(p_workspace_id)) e
   where e->>'section' = p_section limit 1;
  if v_sec is null then
    raise exception 'this workspace has no readiness section %', coalesce(p_section, '(none)')
      using errcode = '22023';
  end if;
  if coalesce((v_sec->>'required')::boolean, false) then
    raise exception 'a required section cannot be set aside for later: it has to be set up'
      using errcode = '22023';
  end if;
  if v_sec->>'state' in ('ready', 'not_applicable') then
    raise exception 'this section has nothing left to set aside' using errcode = '22023';
  end if;
  insert into public.readiness_acknowledgements (workspace_id, user_id, section, material_revision)
  values (p_workspace_id, auth.uid(), p_section, public.readiness_section_revision(v_sec))
  on conflict on constraint readiness_acknowledgements_key do update
    set material_revision = excluded.material_revision, acknowledged_at = now()
  returning * into v;
  return v;
end;
$fn$;
revoke execute on function public.acknowledge_readiness_section(uuid, text) from public, anon;
grant execute on function public.acknowledge_readiness_section(uuid, text) to authenticated;

create or replace function public.clear_readiness_acknowledgement(p_workspace_id uuid, p_section text)
returns boolean language plpgsql volatile security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace takes a section back'
      using errcode = '42501';
  end if;
  delete from public.readiness_acknowledgements
   where installation_id = public.installation_id() and workspace_id = p_workspace_id
     and user_id = auth.uid() and section = p_section;
  return found;
end;
$fn$;
revoke execute on function public.clear_readiness_acknowledgement(uuid, text) from public, anon;
grant execute on function public.clear_readiness_acknowledgement(uuid, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(307);
