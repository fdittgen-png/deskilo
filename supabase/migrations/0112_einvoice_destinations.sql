-- SPDX-License-Identifier: 0BSD
-- #568 — an e-invoice has TWO destinations, not one: the government
-- platform (clearance / plateforme agréée — what 0071 configured) and the
-- customer's own delivery service (a Peppol access point, the customer's
-- portal, whatever was agreed bilaterally).
--
-- The customer channel lives in the SAME einvoice_credentials.config
-- jsonb, under customer_-prefixed keys (customer_endpoint,
-- customer_auth_value, customer_auth_header, customer_field_name — with
-- the 0074 _uat/_dev environment suffixes after the field name). The
-- merge RPC (set_einvoice_credentials) already accepts arbitrary keys, so
-- storage needs nothing; only the transmission log and the echo-back
-- allowlist learn the new axis.

-- 1. WHERE each attempt went. Every row so far went to the platform the
-- government mandate points at — backfilled by the default.
alter table public.invoice_transmissions
  add column destination text not null default 'government'
    check (destination in ('government', 'customer'));

-- 2. The non-secret allowlist gains the customer_-prefixed twins, so the
-- config screen can echo the customer endpoint back like it echoes the
-- government one. Everything else keeps reporting PRESENT, never a value.
create or replace function public.einvoice_config_is_secret(p_key text)
returns boolean language sql immutable as $$
  select p_key !~ '^(customer_)?(endpoint|auth_header|field_name|provider)(_uat|_dev)?$';
$$;
