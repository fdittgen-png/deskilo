-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0285 (#1636) -- how far a new space is from being usable, one section
-- at a time, from what the space actually holds.
--
-- workspace_readiness answers, for someone who configures the space, a
-- short ordered list: each section's state (ready / needs_configuration /
-- unverified), whether it blocks a first real booking (required) or only
-- later operations, and where it is set up. It reads rows the caller may
-- already configure; it writes nothing and runs no probe (no test
-- booking, invoice, invitation or payment). "Created", "ready for a
-- first booking" and "ready to invoice" stay different: payments and
-- recovery are never required for a native booking, and recovery is
-- 'unverified' until evidence exists, never promoted by a checkbox.

create or replace function public.workspace_readiness(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_seats integer;
  v_members integer;
  v_invitations integer;
  v_pricing boolean;
  v_payments boolean;
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
  return jsonb_build_array(
    jsonb_build_object('section', 'region_rules', 'required', true, 'route', '/availability',
      'state', case when coalesce(w.timezone, '') <> '' and coalesce(w.currency_code, '') <> ''
                     and case when jsonb_typeof(w.booking_rules->'open_weekdays') = 'array'
                              then jsonb_array_length(w.booking_rules->'open_weekdays') > 0 else false end
                    then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'resources', 'required', true, 'route', '/editor',
      'state', case when v_seats > 0 then 'ready' else 'needs_configuration' end, 'count', v_seats),
    jsonb_build_object('section', 'pricing', 'required', false, 'route', '/billing',
      'state', case when v_pricing then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'invitations', 'required', false, 'route', '/workspace-code',
      'state', case when v_members > 1 or v_invitations > 0 then 'ready' else 'needs_configuration' end,
      'count', v_members),
    jsonb_build_object('section', 'payments', 'required', false, 'route', '/payment-methods',
      'state', case when v_payments then 'ready' else 'needs_configuration' end),
    jsonb_build_object('section', 'recovery', 'required', false, 'route', '/workspace-settings',
      'state', 'unverified'));
end;
$fn$;
revoke execute on function public.workspace_readiness(uuid) from public, anon;
grant execute on function public.workspace_readiness(uuid) to authenticated;

select public.set_deskilo_schema_version(285);
