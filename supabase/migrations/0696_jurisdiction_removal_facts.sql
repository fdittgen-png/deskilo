-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0696 (#3338) -- the runtime half of the removal check of a jurisdiction
-- module. A source tree cannot say whether a provider still has work in
-- flight; this read-only function does, by id, for one space:
--   * unsettled_transmissions -- e-invoice transmissions that could still
--     complete (prepared, sent or uncertain), optionally those of one
--     provider and/or one syntax;
--   * enabled_capabilities -- the e-invoice channel the space has configured
--     with that provider;
--   * needed_correction_routes -- the replacements (credit notes) of a
--     document the provider accepted that have not been accepted themselves
--     yet: they need the provider's syntax to leave.
-- It returns rows with ids, never counts, and only for the caller's own space.
-- The authority is the connector one (signed in, a native token -- an
-- assistant is refused --, an active member holding manageBilling: the owner
-- and a manager); nothing is written.

create or replace function public.jurisdiction_removal_facts_v1(
  p_workspace_id uuid, p_provider text default null, p_format text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_provider text := nullif(btrim(coalesce(p_provider, '')), '');
  v_format text := nullif(btrim(coalesce(p_format, '')), '');
begin
  perform public.accounting_connector_member(p_workspace_id, 'manageBilling');
  return jsonb_build_object(
    'workspace_id', p_workspace_id,
    'provider', v_provider,
    'format', v_format,
    'enabled_capabilities', coalesce((
      select jsonb_agg(jsonb_build_object(
               'capability', 'einvoice_channel.' || c.provider,
               'provider', c.provider))
        from public.einvoice_credentials c
       where c.workspace_id = p_workspace_id
         and v_provider is not null and c.provider = v_provider), '[]'::jsonb),
    'unsettled_transmissions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'transmission_id', t.id,
               'invoice_id', t.invoice_id,
               'provider', t.provider,
               'format', t.format,
               'phase', t.phase,
               'sent_at', t.sent_at) order by t.sent_at, t.id)
        from public.invoice_transmissions t
       where t.workspace_id = p_workspace_id
         and t.phase in ('prepared', 'sent', 'uncertain')
         and (v_provider is null or t.provider = v_provider)
         and (v_format is null or t.format = v_format)), '[]'::jsonb),
    'needed_correction_routes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'invoice_id', i.id,
               'replaces_invoice_id', o.id) order by i.id)
        from public.invoices i
        join public.invoices o
          on o.id = i.replaces_invoice_id and o.workspace_id = i.workspace_id
       where i.workspace_id = p_workspace_id
         and exists (
           select 1 from public.invoice_transmissions t
            where t.workspace_id = p_workspace_id and t.invoice_id = o.id
              and t.phase = 'accepted'
              and (v_provider is null or t.provider = v_provider)
              and (v_format is null or t.format = v_format))
         and not exists (
           select 1 from public.invoice_transmissions t2
            where t2.workspace_id = p_workspace_id and t2.invoice_id = i.id
              and t2.phase = 'accepted')), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.jurisdiction_removal_facts_v1(uuid, text, text) from public, anon;
grant execute on function public.jurisdiction_removal_facts_v1(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(696);
