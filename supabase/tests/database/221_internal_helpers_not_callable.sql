-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2588 / 0478: the internal definer helpers a signed-in person could call
-- with any id are not callable by authenticated, anon or public, and the
-- public functions that use them still work.
begin;
select plan(31);

create function pg_temp.callable(p_sig text, p_role text) returns boolean language sql as $$
  select has_function_privilege(p_role, p_sig::regprocedure, 'execute');
$$;

select ok(not pg_temp.callable(sig, 'authenticated') and not pg_temp.callable(sig, 'anon'), sig || ' is not callable by a signed-in or anonymous person')
  from unnest(array[
    'public.deployment_direction(uuid,uuid)', 'public.field_answer_problem(uuid,jsonb)',
    'public.invoice_lines_for(uuid,text,text)', 'public.invoice_lines_for(uuid,text)',
    'public.issuing_gate_of(text)', 'public.level_booking_enabled(uuid)',
    'public.level_has_conflict(uuid,timestamp with time zone,timestamp with time zone)',
    'public.member_custom_permissions(uuid)', 'public.message_body_workspaces(text)',
    'public.message_ref_workspace(text,uuid)', 'public.message_refs_allowed(text,uuid[])',
    'public.reservation_site(public.reservations)', 'public.role_holds(uuid,text,text)',
    'public.template_snapshot(public.workspace_templates,uuid)', 'public.validation_requires(uuid,text,integer)',
    'public.vat_rate_family(uuid)', 'public.vat_rate_id_by_label(uuid,text)',
    'public.vat_rate_percent_at(uuid,date)', 'public.workspace_charges_vat(uuid)',
    'public.workspace_default_vat_percent(uuid)', 'public.workspace_default_vat_percent(uuid,date)',
    'public.workspace_default_vat_rate_id(uuid)', 'public.workspace_tariff_vat_percent(uuid)',
    'public.workspace_tariff_vat_percent(uuid,date)', 'public.workspace_twin_id(uuid)']) sig;

-- what stays callable, because an invoker function, a policy or the pre-request
-- hook runs them with the caller's own rights
select ok(pg_temp.callable('public.eu_country_code(text)', 'authenticated'), 'a pure lookup an invoker function needs stays callable');
select ok(pg_temp.callable('public.is_this_installation(uuid)', 'authenticated'), 'so does the policy helper');
select ok(pg_temp.callable('public.mcp_runtime_epoch_mismatch()', 'authenticated'), 'and the pre-request hook');
select ok(pg_temp.callable('public.preview_invoice(uuid,uuid,text)', 'authenticated'), 'the guarded preview is still the way to read a member''s lines');
select ok(not pg_temp.callable('public.mcp_own_reservation(public.mcp_call_context,jsonb)', 'authenticated'), 'the facade helper the text scan cannot follow is revoked too');
select ok(pg_temp.callable('public.invoice_lines_for(uuid,text)', 'service_role'), 'service_role keeps execute on the helper');

select * from finish();
rollback;
