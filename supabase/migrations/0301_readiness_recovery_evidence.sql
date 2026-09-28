-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0301 (#1636) -- recovery evidence. The readiness checklist's recovery
-- section was always unverified: nothing recorded that a copy of the space
-- had ever been taken. Evidence now comes from a real, completed export,
-- never from a toggle:
--
--   * workspace_recovery_evidence: one row per export the app finished
--     saving -- when, by whom, the SHA-256 of the saved file and how many
--     data rows it holds. No client writes it directly: RLS on, every
--     privilege revoked, the delegated-token denial on top.
--   * record_workspace_export(workspace, sha256, row_count): the one way
--     in, for someone holding exportData (the permission the export tile
--     itself requires, #1310 S0). The hash must be 64 hexadecimal
--     characters, the row count at least zero.
--   * workspace_readiness v5: generated from 0296's body; only the
--     recovery section changes. An export recorded within 90 days is
--     ready (recent_export, with recorded_at), an older one stays
--     unverified (stale_export), none stays unverified (no_evidence).
--     Actor operator, never required.
--
-- (0300 is #1630 checkpoint 2, in flight; this follows it.)

create table if not exists public.workspace_recovery_evidence (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  kind text not null default 'export' check (kind in ('export')),
  recorded_at timestamptz not null default now(),
  recorded_by uuid references auth.users (id) on delete set null,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  row_count integer not null check (row_count >= 0)
);
select public.ensure_system_columns('workspace_recovery_evidence');
create index if not exists workspace_recovery_evidence_workspace_idx
  on public.workspace_recovery_evidence (workspace_id, kind, recorded_at desc);
alter table public.workspace_recovery_evidence enable row level security;
revoke all on table public.workspace_recovery_evidence from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.workspace_recovery_evidence;
create policy mcp_delegated_deny on public.workspace_recovery_evidence
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.record_workspace_export(p_workspace_id uuid, p_sha256 text, p_row_count integer)
returns public.workspace_recovery_evidence language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.workspace_recovery_evidence;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace records its export'
      using errcode = '42501';
  end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9A-Fa-f]{64}$' then
    raise exception 'an export hash is 64 hexadecimal characters' using errcode = '22023';
  end if;
  if p_row_count is null or p_row_count < 0 then
    raise exception 'an export holds zero rows or more' using errcode = '22023';
  end if;
  insert into public.workspace_recovery_evidence (workspace_id, kind, recorded_by, sha256, row_count)
  values (p_workspace_id, 'export', auth.uid(), lower(p_sha256), p_row_count)
  returning * into v;
  return v;
end;
$fn$;
revoke execute on function public.record_workspace_export(uuid, text, integer) from public, anon;
grant execute on function public.record_workspace_export(uuid, text, integer) to authenticated;

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
  return jsonb_build_array(
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
end;
$fn$;
revoke execute on function public.workspace_readiness(uuid) from public, anon;
grant execute on function public.workspace_readiness(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(301);
