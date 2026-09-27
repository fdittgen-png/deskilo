-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0280 (#1656, group 5) -- what a space must set up locally before the
-- features a template switches on can do their job.
--
-- A template never carries the source's legal identity, bank details,
-- provider connections or sites: they are the source's own (0229). But a
-- template that turns invoicing on makes a space that cannot issue a
-- lawful invoice until it has its own identity. So the local needs are a
-- finite, typed list, each tied to the feature that needs it and to the
-- field ids of #1655's registry, with where it is filled in:
--
--   legal_identity    invoicing                 workspace legal id and address
--   payment_details   invoicing (recommended)   how members pay (IBAN, ...)
--   payment_provider  onlinePayments            a provider connection
--   einvoice_platform einvoiceCustomerDelivery  the e-invoice platform account
--   site              multiSite                 at least one site
--
-- `template_local_needs` says which a template will need; nothing is
-- guessed, no source value is a default, and no slot holds a secret.
-- `workspace_local_readiness` says which a space still lacks, for the
-- people who configure it.

create or replace function public.template_local_slot_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json$[
    {"slot":"legal_identity","feature":"invoicing","required":true,"route":"/settings",
     "fields":["workspace.legal_id","workspace.street","workspace.postal_code","workspace.city"]},
    {"slot":"payment_details","feature":"invoicing","required":false,"route":"/settings",
     "fields":["workspace.payment_instructions.iban","workspace.payment_instructions.reference"]},
    {"slot":"payment_provider","feature":"onlinePayments","required":true,"route":"/payment-config",
     "fields":[]},
    {"slot":"einvoice_platform","feature":"einvoiceCustomerDelivery","required":true,"route":"/einvoice-config",
     "fields":[]},
    {"slot":"site","feature":"multiSite","required":true,"route":"/settings",
     "fields":["tables.sites[].name","tables.sites[].street","tables.sites[].city"]}
  ]$json$::jsonb;
$fn$;
revoke execute on function public.template_local_slot_catalogue() from public, anon;
grant execute on function public.template_local_slot_catalogue() to authenticated;

-- The local needs of a template: the slots whose feature it switches on.
create or replace function public.template_local_needs(p_template_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_flags jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select coalesce(configuration->'workspace'->'feature_flags', '{}'::jsonb) into v_flags
    from public.workspace_templates where id = p_template_id;
  return coalesce((select jsonb_agg(s order by ord)
                     from jsonb_array_elements(public.template_local_slot_catalogue()) with ordinality c(s, ord)
                    where coalesce((v_flags->>(s->>'feature'))::boolean, false)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.template_local_needs(uuid) from public, anon;
grant execute on function public.template_local_needs(uuid) to authenticated;

-- What this space still lacks, for the features it has on.
create or replace function public.workspace_local_readiness(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  w public.workspaces;
  v_out jsonb := '[]'::jsonb;
  v_slot jsonb;
  v_filled boolean;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace sees what it lacks';
  end if;
  select * into w from public.workspaces where id = p_workspace_id;
  for v_slot in select value from jsonb_array_elements(public.template_local_slot_catalogue()) loop
    if not public.feature_effective(p_workspace_id, v_slot->>'feature') then
      continue;
    end if;
    v_filled := case v_slot->>'slot'
      when 'legal_identity' then coalesce(trim(w.legal_id), '') <> ''
                             and (coalesce(trim(w.street), '') <> '' or coalesce(trim(w.address), '') <> '')
      when 'payment_details' then exists (
        select 1 from jsonb_each_text(coalesce(w.payment_instructions, '{}'::jsonb)) e where trim(e.value) <> '')
      when 'payment_provider' then exists (select 1 from public.payment_credentials c where c.workspace_id = p_workspace_id)
      when 'einvoice_platform' then exists (select 1 from public.einvoice_credentials c where c.workspace_id = p_workspace_id)
      when 'site' then exists (select 1 from public.sites s where s.workspace_id = p_workspace_id)
      else false end;
    v_out := v_out || (v_slot || jsonb_build_object('filled', v_filled));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.workspace_local_readiness(uuid) from public, anon;
grant execute on function public.workspace_local_readiness(uuid) to authenticated;

select public.set_deskilo_schema_version(280);
