-- SPDX-License-Identifier: 0BSD
-- Invoice PDF template (#454): owner-written text blocks (intro above
-- the parties, footer under the totals) with {{placeholder}}
-- substitution, applied ONLY to the rendered PDF — the EN 16931 XML
-- stays untouched by design. Keys inside the jsonb are client-defined
-- ('intro', 'footer'); RLS: workspaces_update already restricts writes
-- to the owner, reads to members.
alter table public.workspaces
  add column if not exists invoice_pdf_template jsonb not null
    default '{}'::jsonb;
