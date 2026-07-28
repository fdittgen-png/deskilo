-- SPDX-License-Identifier: 0BSD
-- Two advisor findings from applying 0071/0072 to the hosted project, both
-- the same class of slip: a function that skipped the repo's own
-- conventions. Neither is exploitable on its own — they are closed because
-- "it only leaks a VAT rate" is how a habit erodes.

-- 1. Every RPC in this schema is revoked from anon; 0072's helper was
-- missed, so an unauthenticated caller could ask any workspace id for its
-- default rate. A rate is public information (it is printed on every
-- invoice), but the guest role has no business calling app RPCs at all.
revoke execute on function public.workspace_default_vat_percent(uuid)
  from public, anon;

-- 2. A function without a pinned search_path resolves its references
-- against the caller's path. `einvoice_config_is_secret` is SECURITY
-- INVOKER and touches nothing, so the risk is theoretical — but it is
-- called from inside a SECURITY DEFINER function (einvoice_status), which
-- is exactly the shape where a mutable path stops being theoretical.
create or replace function public.einvoice_config_is_secret(p_key text)
returns boolean language sql immutable set search_path = public as $$
  select p_key not in ('endpoint', 'auth_header', 'field_name', 'provider');
$$;
