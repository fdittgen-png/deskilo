-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0537 -- the local setup rows open the screen that fills them (#2865).
--
-- 0280 named `/settings` for the legal identity, the payment details and
-- the sites. That is the person's own settings, not the space's: the
-- owner's "Set up" landed on their profile. Each slot now names its
-- screen; nothing else changes.

create or replace function public.template_local_slot_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json$[
    {"slot":"legal_identity","feature":"invoicing","required":true,"route":"/legal-identity",
     "fields":["workspace.legal_id","workspace.street","workspace.postal_code","workspace.city"]},
    {"slot":"payment_details","feature":"invoicing","required":false,"route":"/payment-methods",
     "fields":["workspace.payment_instructions.iban","workspace.payment_instructions.reference"]},
    {"slot":"payment_provider","feature":"onlinePayments","required":true,"route":"/payment-config",
     "fields":[]},
    {"slot":"einvoice_platform","feature":"einvoiceCustomerDelivery","required":true,"route":"/einvoice-config",
     "fields":[]},
    {"slot":"site","feature":"multiSite","required":true,"route":"/settings/sites",
     "fields":["tables.sites[].name","tables.sites[].street","tables.sites[].city"]}
  ]$json$::jsonb;
$fn$;
revoke execute on function public.template_local_slot_catalogue() from public, anon;
grant execute on function public.template_local_slot_catalogue() to authenticated;

select public.set_deskilo_schema_version(537);
