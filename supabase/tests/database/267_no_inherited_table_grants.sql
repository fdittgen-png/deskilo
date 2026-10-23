-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2942 — anon and authenticated hold only the table privileges a policy
-- or a client path uses, and a new table in `public` starts without the
-- rest.
--
-- Row-level security refuses the writes a policy does not allow, but
-- TRUNCATE is not subject to it, and a grant that no policy backs is one
-- `create policy` away from meaning something. This reads the RESULT of
-- every migration, the way `00_schema_guarantees` does: a table added
-- next year is covered the day it is added.
begin;
select plan(14);

-- 1. No table-level maintenance privilege for a client role.
select is_empty(
  $$ select c.relname || ' ' || r.rolname || ' ' || p.priv
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
       cross join (values ('anon'), ('authenticated')) r(rolname)
       cross join (values ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')) p(priv)
      where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and has_table_privilege(r.rolname, c.oid, p.priv) $$,
  'no public table grants TRUNCATE, REFERENCES, TRIGGER or MAINTAIN to anon or authenticated'
);

-- 2./3. A write privilege is backed by a permissive policy for that
-- command that applies to the role (named, or `public`).
select is_empty(
  $$ select c.relname || ' anon ' || w.priv
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
       cross join (values ('INSERT', 'a'), ('UPDATE', 'w'), ('DELETE', 'd')) w(priv, cmd)
      where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and has_table_privilege('anon', c.oid, w.priv)
        and not exists (
          select 1 from pg_policy p
           where p.polrelid = c.oid and p.polpermissive
             and p.polcmd::text in (w.cmd, '*')
             and (0::oid = any(p.polroles) or 'anon'::regrole::oid = any(p.polroles))) $$,
  'anon holds no write privilege without a policy that applies to anon'
);

select is_empty(
  $$ select c.relname || ' authenticated ' || w.priv
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
       cross join (values ('INSERT', 'a'), ('UPDATE', 'w'), ('DELETE', 'd')) w(priv, cmd)
      where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and has_table_privilege('authenticated', c.oid, w.priv)
        and not exists (
          select 1 from pg_policy p
           where p.polrelid = c.oid and p.polpermissive
             and p.polcmd::text in (w.cmd, '*')
             and (0::oid = any(p.polroles) or 'authenticated'::regrole::oid = any(p.polroles))) $$,
  'authenticated holds no write privilege without a permissive policy for that command'
);

-- 4. A table created now starts closed (the default privileges of the
-- role that runs the migrations).
create table public.zz_grant_probe_2942 (id int);
select is_empty(
  $$ select r.rolname || ' ' || p.priv
       from (values ('anon'), ('authenticated')) r(rolname)
       cross join (values ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')) p(priv)
      where has_table_privilege(r.rolname, 'public.zz_grant_probe_2942', p.priv) $$,
  'a new table grants no TRUNCATE, REFERENCES, TRIGGER or MAINTAIN to a client role'
);
select ok(not has_table_privilege('anon', 'public.zz_grant_probe_2942', 'INSERT, UPDATE, DELETE'),
  'a new table grants anon no write');
select ok(has_table_privilege('authenticated', 'public.zz_grant_probe_2942', 'SELECT'),
  'the remaining defaults are unchanged: the revoke-all-then-grant convention still applies');
drop table public.zz_grant_probe_2942;

-- 5. Positive controls: what the policies and the app's repositories use.
select ok(has_table_privilege('authenticated', 'public.profiles', 'SELECT')
      and has_table_privilege('authenticated', 'public.profiles', 'UPDATE'),
  'a person still reads profiles and updates their own (profiles_update)');
select ok(has_table_privilege('authenticated', 'public.members', 'UPDATE')
      and has_table_privilege('authenticated', 'public.members', 'DELETE'),
  'an owner still updates and removes members (members_update_owner, members_delete_owner)');
select ok(has_table_privilege('authenticated', 'public.workspaces', 'UPDATE')
      and has_table_privilege('authenticated', 'public.workspaces', 'DELETE'),
  'workspace settings still save (workspaces_update, save_workspace_settings)');
select ok(has_table_privilege('authenticated', 'public.member_notes', 'DELETE'),
  'a note can still be deleted (member_notes_delete)');
select ok(has_table_privilege('authenticated', 'public.seats', 'INSERT')
      and has_table_privilege('authenticated', 'public.seats', 'UPDATE')
      and has_table_privilege('authenticated', 'public.seats', 'DELETE'),
  'the floor plan editor still writes seats (seats_write_sites)');
select ok(has_table_privilege('authenticated', 'public.validation_policies', 'INSERT')
      and has_table_privilege('authenticated', 'public.validation_policies', 'UPDATE'),
  'validation policies still upsert (validation_policies_write)');
select ok(has_table_privilege('authenticated', 'public.reservations', 'SELECT')
      and not has_table_privilege('authenticated', 'public.reservations', 'INSERT'),
  'reservations are read directly and written only through the booking functions');

-- 6. Negative control on a table with only a SELECT policy.
select ok(not has_table_privilege('authenticated', 'public.vat_rates', 'INSERT')
      and not has_table_privilege('authenticated', 'public.quota_extensions', 'UPDATE')
      and not has_table_privilege('anon', 'public.members', 'DELETE'),
  'a read-only table grants no write, and anon writes nothing');

select * from finish();
rollback;
