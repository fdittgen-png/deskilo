-- SPDX-License-Identifier: 0BSD
--
-- #1226 — the first test that has ever executed this database.
--
-- 208 migrations, 54 tables, 83 policies and 241 `SECURITY DEFINER`
-- functions had never been run by anything except a hand-driven harness
-- against the dev project. The three lints we had — `migration_grants_test`,
-- `grant_table_policy_test`, `edge_function_auth_test` — are pattern
-- matches on SQL TEXT. They cannot evaluate a policy, and a policy that
-- is never evaluated is a claim, not a control.
--
-- This file asserts what must hold of the SCHEMA, whatever rows exist:
-- it needs no fixture and it covers every table at once, so a table
-- added next year is covered the day it is added.
begin;
select plan(6);

-- 1. RLS on, everywhere.
--
-- A public table without it is readable by every signed-in user of every
-- other workspace. There is no acceptable exception: the tables that are
-- meant to be readable say so with a policy.
select is_empty(
  $$ select c.relname
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
        and not c.relrowsecurity $$,
  'every table in public has row-level security enabled'
);

-- 2. A table with no policy is closed at the GRANT layer too.
--
-- RLS with no policy denies everything, so a policy-less table is safe
-- today — by accident. `badge_auth_attempts`, `einvoice_credentials`,
-- `payment_credentials` and `push_config` all carried SELECT and INSERT
-- for `anon` and `authenticated` while holding exactly the secrets their
-- names say. One policy added by somebody who assumed the grants meant
-- something would have opened them. 0211 revoked the grants; this keeps
-- the two layers agreeing.
select is_empty(
  $$ select c.relname
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
        and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
        and (has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE')
          or has_table_privilege('authenticated', c.oid, 'SELECT, INSERT, UPDATE, DELETE')) $$,
  'a table with no policy grants nothing to anon or authenticated either'
);

-- 3. No definer function is callable by an unauthenticated caller.
--
-- `SECURITY DEFINER` runs as the owner, which bypasses RLS by design.
-- The only thing standing between `anon` and the whole database is the
-- EXECUTE grant, so every migration ends with `revoke execute … from
-- public, anon`. This proves the revokes landed rather than that they
-- were typed.
select is_empty(
  $$ select p.proname
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef
        and has_function_privilege('anon', p.oid, 'EXECUTE') $$,
  'no SECURITY DEFINER function in public is executable by anon'
);

-- 4. Every definer function pins its search_path.
--
-- Without `set search_path`, a caller who can create a schema chooses
-- which `members` table the function reads. That is the classic definer
-- escalation, and it is a one-line mistake to make.
select is_empty(
  $$ select p.proname
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}')) c
           where c like 'search_path=%') $$,
  'every SECURITY DEFINER function pins its own search_path'
);

-- 5. The six system columns are on every table (#992).
--
-- `ensure_system_columns()` exists and a lint reads the migrations for
-- it; this reads the RESULT.
select is_empty(
  $$ select c.relname
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
        and exists (
          select 1 from unnest(array['created_datetime', 'modified_datetime',
                                     'created_by_user', 'modified_by_user',
                                     'company_id', 'site_id']) col
           where not exists (
             select 1 from pg_attribute a
              where a.attrelid = c.oid and a.attname = col and a.attnum > 0
                and not a.attisdropped)) $$,
  'every table carries the six system columns'
);

-- 6. The migrations applied from empty at all.
--
-- Trivially true if the four above ran — which is the point. Before this
-- file, nothing in CI had ever proved that 208 migrations replay on a
-- fresh database in order. A migration that only works against the dev
-- project's accumulated state is a migration that cannot rebuild prod.
select cmp_ok(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'),
  '>=', 50,
  'the whole migration history replays onto an empty database'
);

select * from finish();
rollback;
