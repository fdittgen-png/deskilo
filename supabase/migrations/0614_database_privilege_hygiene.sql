-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (privileges only; no row and no function body moves)
--
-- 0614 (#3095, SEC-D1 and the oracle half of SEC-D2 of the #2960 audit) --
-- the defaults stop handing out access.
--
--   1. Default privileges of `postgres` in `public`: a NEW function is no
--      longer executable by `public` or `anon`, and a NEW table carries no
--      SELECT for `anon`. Until now both were granted by default, so denial
--      rested on RLS and on the helpers raising alone. A migration that wants
--      an anonymous caller says so with an explicit grant.
--   2. `anon` loses the TABLE-level SELECT it was handed by that default on
--      every table of `public` (51 on the dev project) — every read of an
--      anonymous caller was already refused or empty — except
--      `deskilo_schema_version`, the one table an app reads before anybody
--      signs in. The column-level grants the published cards and the
--      directory carry on purpose stay.
--   3. `feature_operation_allowed` (definer, 0324) is no longer executable by
--      `authenticated`: it answered whether a feature is on in ANY workspace.
--      The definer functions that call it run as their owner and are
--      unaffected; the app never calls it directly.
--
-- Not here (next slice): the actor check that moves ahead of the
-- state-specific errors in void_invoice, record_invoice_reminder,
-- settle_credit_invoice and add_conversation_participant, and the per-entry
-- check of set_room_rental_fees_v1.

-- Global AND per-schema: a per-schema default only ADDS to the global one, so
-- it cannot take back the built-in EXECUTE of PUBLIC (or a global grant to
-- anon); a fresh replay keeps the function executable unless the global
-- default is revoked too.
alter default privileges for role postgres
  revoke execute on functions from public, anon;
alter default privileges for role postgres
  revoke select on tables from anon;
-- The service key keeps what PUBLIC gave it, by name. The signed-in user is
-- NOT named here: a function is granted to `authenticated` where it is
-- declared, as the migrations already do (a global grant would reopen the
-- default this migration closes).
alter default privileges for role postgres
  grant execute on functions to service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon;
alter default privileges for role postgres in schema public
  revoke select on tables from anon;

-- The hosted platform also creates objects as supabase_admin: the same
-- defaults for it, where this role may set them (a migration run as another
-- role is refused, and that is not a failure of this one).
do $admin$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    alter default privileges for role supabase_admin
      revoke execute on functions from public, anon;
    alter default privileges for role supabase_admin
      revoke select on tables from anon;
    alter default privileges for role supabase_admin
      grant execute on functions to service_role;
    alter default privileges for role supabase_admin in schema public
      revoke execute on functions from public, anon;
    alter default privileges for role supabase_admin in schema public
      revoke select on tables from anon;
  end if;
exception when insufficient_privilege then
  raise notice 'default privileges of supabase_admin left as they are';
end
$admin$;

-- Revoking a table privilege also revokes the matching column privileges, so
-- a table where anon holds a COLUMN grant is skipped: the published cards, the
-- directory source list and the installation identity carry theirs on purpose
-- (0299, 0305, 0390, 0559). Those tables have no table-level SELECT anyway
-- (revoked in 0269/0305/0390); the guard covers an installation that drifted.
do $privileges$
declare
  v_table regclass;
begin
  for v_table in
    select c.oid::regclass
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p')
       and c.relname <> 'deskilo_schema_version'
       and has_table_privilege('anon', c.oid, 'select')
       and not exists (
         select 1
           from pg_attribute a, aclexplode(a.attacl) x
          where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
            and x.privilege_type = 'SELECT'
            and x.grantee = (select oid from pg_roles where rolname = 'anon'))
  loop
    execute format('revoke select on table %s from anon', v_table);
  end loop;
end
$privileges$;
grant select on public.deskilo_schema_version to anon;

revoke execute on function public.feature_operation_allowed(uuid, text, text) from authenticated;

select public.set_deskilo_schema_version(614);
