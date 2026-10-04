-- SPDX-License-Identifier: AGPL-3.0-or-later
-- A workspace's data is its own: every table that carries a workspace_id has
-- row-level security on, and no permissive policy on one opens it to
-- everybody (`true`), except the deliberately public listing card.
begin;
select plan(2);

select is(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
      and exists (select 1 from pg_attribute a
                   where a.attrelid = c.oid and a.attname = 'workspace_id' and not a.attisdropped)),
  '', 'every table that carries a workspace_id has row-level security on');

select is(
  (select coalesce(string_agg(c.relname || '.' || p.polname, ', ' order by c.relname), '')
     from pg_policy p join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and p.polpermissive
      and pg_get_expr(p.polqual, p.polrelid) = 'true'
      and exists (select 1 from pg_attribute a
                   where a.attrelid = c.oid and a.attname = 'workspace_id' and not a.attisdropped)
      and c.relname <> 'public_workspace_cards'),
  '', 'no policy on a workspace table opens it to everybody');

select * from finish();
rollback;
