-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0296 (#1636) -- the readiness checklist says whether the space has been
-- used: a last section, first_booking, ready once one booking exists that
-- was not cancelled or released, otherwise the next thing to try. Never
-- required, never probed: the function still books nothing to find out.
-- Every other section is unchanged from 0294.

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
      'route', '/workspace-settings', 'state', 'unverified', 'reason', 'no_evidence'))
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

select public.set_deskilo_schema_version(296);
