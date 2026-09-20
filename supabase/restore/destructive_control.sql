-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1338 — the destructive control of the populated upgrade check.
--
-- NOT a migration. `scripts/populated_upgrade_check.sh` applies this
-- through the same path as the real migrations, after the honest upgrade
-- has been compared, to prove the comparison can fail: it "repairs" the
-- legacy invoice's signature by recomputing it over today's columns and
-- stamping the algorithm — the very rewrite that would turn an
-- `unverifiable` archive into one that looks `verified` and destroys the
-- evidence that it was ever different. The check passes only when the
-- snapshot diff names ARC-2.
alter table public.invoices disable trigger user;

update public.invoices v
   set signature = encode(extensions.digest(convert_to(concat_ws('|',
         v.id::text, v.number, v.workspace_id::text, v.member_id::text,
         v.member_name, v.member_address, v.workspace_name,
         coalesce(v.workspace_address, ''), v.issuer_name,
         v.period, v.lines::text, v.total_cents::text, v.currency,
         v.issued_at::date::text, coalesce(v.replaces_invoice_id::text, ''),
         coalesce(v.replaces_number, ''), coalesce(v.details::text, ''),
         v.parties::text, v.vat_totals::text, v.kind),
         'UTF8'), 'sha256'), 'hex'),
       signature_algo = 7
 where v.signature_algo is null;

alter table public.invoices enable trigger user;
