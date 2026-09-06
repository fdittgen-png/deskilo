-- SPDX-License-Identifier: 0BSD
-- 0173 — #953: a draft declaration on a workspace that charges no VAT is
-- an orphan of a gate that came later (save_vat_declaration refuses one
-- now). A FILED declaration is never touched. One row on the pilot.
delete from public.vat_declarations d
 where d.status = 'draft' and not public.workspace_charges_vat(d.workspace_id);
