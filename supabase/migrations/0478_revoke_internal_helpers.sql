-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0478 (#2588 review of the first list) -- internal definer helpers stop being
-- callable by a signed-in person.
--
-- The caller-guard scanner (test/lint/definer_scan.dart) listed 33 exposed
-- SECURITY DEFINER functions it could not show to check their caller. Read one
-- by one against the live schema: 25 are helpers that only other SECURITY
-- DEFINER functions call -- none is called by the app, by an edge function,
-- by a policy, a view, a default or an invoker function -- yet each carried
-- the default execute privilege of `authenticated`. Anyone signed in could
-- call them with any id (the VAT rate of a workspace, the custom permissions
-- of a member, the twin of a workspace). They are revoked from public, anon
-- and authenticated; the functions that call them run with their owner's
-- rights and are untouched. service_role keeps execute.
--
-- Left in the list on purpose, each for a stated reason (see
-- test/lint/definer_unreviewed.txt): pure lookups invoker functions need,
-- a policy helper, a pre-request hook, and a function whose guard sits in a
-- later anchored patch the text scan cannot see.

revoke execute on function public.deployment_direction(uuid,uuid) from public, anon, authenticated;
revoke execute on function public.field_answer_problem(uuid,jsonb) from public, anon, authenticated;
revoke execute on function public.invoice_lines_for(uuid,text,text) from public, anon, authenticated;
revoke execute on function public.invoice_lines_for(uuid,text) from public, anon, authenticated;
revoke execute on function public.issuing_gate_of(text) from public, anon, authenticated;
revoke execute on function public.level_booking_enabled(uuid) from public, anon, authenticated;
revoke execute on function public.level_has_conflict(uuid,timestamp with time zone,timestamp with time zone) from public, anon, authenticated;
revoke execute on function public.member_custom_permissions(uuid) from public, anon, authenticated;
revoke execute on function public.message_body_workspaces(text) from public, anon, authenticated;
revoke execute on function public.message_ref_workspace(text,uuid) from public, anon, authenticated;
revoke execute on function public.message_refs_allowed(text,uuid[]) from public, anon, authenticated;
revoke execute on function public.reservation_site(reservations) from public, anon, authenticated;
revoke execute on function public.role_holds(uuid,text,text) from public, anon, authenticated;
revoke execute on function public.template_snapshot(workspace_templates,uuid) from public, anon, authenticated;
revoke execute on function public.validation_requires(uuid,text,integer) from public, anon, authenticated;
revoke execute on function public.vat_rate_family(uuid) from public, anon, authenticated;
revoke execute on function public.vat_rate_id_by_label(uuid,text) from public, anon, authenticated;
revoke execute on function public.vat_rate_percent_at(uuid,date) from public, anon, authenticated;
revoke execute on function public.workspace_charges_vat(uuid) from public, anon, authenticated;
revoke execute on function public.workspace_default_vat_percent(uuid,date) from public, anon, authenticated;
revoke execute on function public.workspace_default_vat_percent(uuid) from public, anon, authenticated;
revoke execute on function public.workspace_default_vat_rate_id(uuid) from public, anon, authenticated;
revoke execute on function public.workspace_tariff_vat_percent(uuid,date) from public, anon, authenticated;
revoke execute on function public.workspace_tariff_vat_percent(uuid) from public, anon, authenticated;
revoke execute on function public.workspace_twin_id(uuid) from public, anon, authenticated;

select public.set_deskilo_schema_version(478);
