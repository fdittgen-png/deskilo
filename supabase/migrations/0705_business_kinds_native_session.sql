-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one restrictive policy on a table of 0703)
--
-- #3549 -- public.business_kinds has no workspace_id, so like every such table
-- (exchange_rate_sources, deskilo_schema_version, ...) it carries the
-- restrictive native-session policy: only a native signed-in session reads it.

drop policy if exists personal_native_session on public.business_kinds;
create policy personal_native_session on public.business_kinds as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

select public.set_deskilo_schema_version(705);
