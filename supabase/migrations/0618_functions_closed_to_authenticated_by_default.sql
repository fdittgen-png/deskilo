-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (privileges only; no row and no function body moves)
--
-- 0618 (#3134, follow-up to #3095) -- a NEW function in `public` is reachable
-- by nobody but the service key until its own migration grants it.
--
-- 0614 closed the default for PUBLIC and anon. `authenticated` kept it through
-- the platform's per-schema default (`grant all on functions to anon,
-- authenticated, service_role`): a new definer function that forgot its
-- `revoke ... from authenticated` was callable by every signed-in account of
-- every workspace. Measured on the dev project before writing this: 1158
-- functions in `public`, every one with an explicit ACL (none depends on the
-- default), 651 grant execute to `authenticated`, 507 do not. A default
-- applies at CREATION, so no existing function changes; a function a later
-- migration creates for the app says `grant execute ... to authenticated`.

alter default privileges for role postgres in schema public
  revoke execute on functions from authenticated;

-- The hosted platform also creates objects as supabase_admin: the same, where
-- this role may set it.
do $admin$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    alter default privileges for role supabase_admin in schema public
      revoke execute on functions from authenticated;
  end if;
exception when insufficient_privilege then
  raise notice 'default privileges of supabase_admin left as they are';
end
$admin$;

select public.set_deskilo_schema_version(618);
