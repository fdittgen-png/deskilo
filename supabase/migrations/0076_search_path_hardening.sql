-- SPDX-License-Identifier: 0BSD
-- Pin search_path on the four helper functions the security advisor
-- flags as mutable (#399). All four are pure or NEW/OLD-only — none
-- touches a table, so the practical exposure was nil — but every other
-- function in this schema pins its path, and the idiom exists precisely
-- so nobody has to re-derive "is the exposure nil?" per function.
--
-- `public`, not '': matches the codebase idiom (0004 onward) and is
-- provably behavior-neutral for any unqualified reference.

alter function public.einvoice_config_is_secret(text)
  set search_path = public;
alter function public.payment_config_is_secret(text)
  set search_path = public;
alter function public.invoices_immutable()
  set search_path = public;
alter function public.stamp_accessory_supplements_since()
  set search_path = public;
