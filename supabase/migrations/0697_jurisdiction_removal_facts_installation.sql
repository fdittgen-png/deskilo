-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0697 (#3338) -- removing a jurisdiction module is an INSTALLATION decision,
-- and 0696 answers for one space under its manager: a clean space beside
-- another with an uncertain transmission would read "removable". This adds the
-- installation-wide answer, grouped by space, for the operator (service role
-- only -- no member sees other spaces):
--   * jurisdiction_removal_facts_of(space, provider, format) -- the per-space
--     facts of 0696, now one internal function both callers share (no
--     authority of its own, executable by nobody but the definer functions);
--   * jurisdiction_removal_facts_v1 -- unchanged contract: the same authority
--     check, then the shared function;
--   * jurisdiction_removal_facts_installation_v1(provider, format) -- every
--     space that has anything for that provider/syntax, with its ids, and how
--     many spaces were examined.

create or replace function public.jurisdiction_removal_facts_of(
  p_workspace_id uuid, p_provider text, p_format text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_provider text := nullif(btrim(coalesce(p_provider, '')), '');
  v_format text := nullif(btrim(coalesce(p_format, '')), '');
begin
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
revoke execute on function public.jurisdiction_removal_facts_of(uuid, text, text) from public, anon, authenticated;

create or replace function public.jurisdiction_removal_facts_v1(
  p_workspace_id uuid, p_provider text default null, p_format text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.accounting_connector_member(p_workspace_id, 'manageBilling');
  return public.jurisdiction_removal_facts_of(p_workspace_id, p_provider, p_format);
end;
$fn$;
revoke execute on function public.jurisdiction_removal_facts_v1(uuid, text, text) from public, anon;
grant execute on function public.jurisdiction_removal_facts_v1(uuid, text, text) to authenticated;

create or replace function public.jurisdiction_removal_facts_installation_v1(
  p_provider text default null, p_format text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_checked bigint;
  v_spaces jsonb;
begin
  select count(*) into v_checked from public.workspaces;
  select coalesce(jsonb_agg(f order by f ->> 'workspace_id'), '[]'::jsonb) into v_spaces
    from (
      select public.jurisdiction_removal_facts_of(w.id, p_provider, p_format) as f
        from public.workspaces w
    ) x
   where f -> 'enabled_capabilities' <> '[]'::jsonb
      or f -> 'unsettled_transmissions' <> '[]'::jsonb
      or f -> 'needed_correction_routes' <> '[]'::jsonb;
  return jsonb_build_object(
    'scope', 'installation',
    'provider', nullif(btrim(coalesce(p_provider, '')), ''),
    'format', nullif(btrim(coalesce(p_format, '')), ''),
    'workspaces_checked', v_checked,
    'workspaces', v_spaces);
end;
$fn$;
revoke execute on function public.jurisdiction_removal_facts_installation_v1(text, text) from public, anon, authenticated;
grant execute on function public.jurisdiction_removal_facts_installation_v1(text, text) to service_role;

select public.set_deskilo_schema_version(697);
