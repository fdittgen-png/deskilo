-- SPDX-License-Identifier: 0BSD
-- Member preferred language (#496): the language DOCUMENTS are printed
-- in for this member (reports, reminder letters, the financial
-- agreement). Written by the member themself when they pick an app
-- language; '' = unset → the workspace language (0096) → the country's
-- language. RLS: profiles_update already restricts writes to the owner
-- of the row.
alter table public.profiles
  add column if not exists preferred_locale text not null default ''
    check (char_length(preferred_locale) <= 5);
