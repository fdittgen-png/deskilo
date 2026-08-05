-- SPDX-License-Identifier: 0BSD
-- Legal invoice mentions (#480): the free-text lines French law (and
-- most of the EU) wants printed on a professional invoice beyond the
-- 0069 identity — legal form & capital, trade register, payment terms,
-- late-penalty rate, the fixed recovery indemnity, the escompte
-- clause, professional insurance and any special-regime mention. Keys
-- are client-defined (InvoiceLegal); empty/absent keys fall back to
-- localized statutory defaults at render time. RLS: workspaces_update
-- already restricts writes to the owner.
alter table public.workspaces
  add column if not exists invoice_legal jsonb not null
    default '{}'::jsonb;
