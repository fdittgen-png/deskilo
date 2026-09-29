-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0311 (#1631) -- the epoch check is not for anonymous callers.
--
-- 0310 granted `mcp_runtime_epoch_mismatch()` to anon beside
-- authenticated, copying the grant of `mcp_is_delegated()`, which the
-- pre-request guard runs for every request. The epoch check is different:
-- the guard reaches it only for a DELEGATED token, and a delegated token
-- is always `authenticated`. As a SECURITY DEFINER function it must not
-- be callable without signing in (00_schema_guarantees, the doctor's
-- definer-function alarm), so anon loses it. Nothing else changes.

revoke execute on function public.mcp_runtime_epoch_mismatch() from public, anon;
grant execute on function public.mcp_runtime_epoch_mismatch() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(311);
