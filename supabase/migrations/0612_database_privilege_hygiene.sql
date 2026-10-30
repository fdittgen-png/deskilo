-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (privileges only; no row and no function body moves)
--
-- 0612 (#3095, SEC-D1 and the oracle half of SEC-D2 of the #2960 audit) --
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

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon;
alter default privileges for role postgres in schema public
  revoke select on tables from anon;

-- Only a TABLE-level grant is withdrawn: `revoke select on all tables` would
-- also drop the column-level grants the published cards, the directory source
-- list and the installation identity carry on purpose (0299, 0305, 0390, 0559).
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
  loop
    execute format('revoke select on table %s from anon', v_table);
  end loop;
end
$privileges$;
grant select on public.deskilo_schema_version to anon;

revoke execute on function public.feature_operation_allowed(uuid, text, text) from authenticated;

select public.set_deskilo_schema_version(612);
