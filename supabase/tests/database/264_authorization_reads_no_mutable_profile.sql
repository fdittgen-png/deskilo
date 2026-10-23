-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2941 — no access decision reads a profile column its owner may edit.
--
-- `holds_template_grant` and `user_has_email` (and the grant table's own
-- read policy) accepted `profiles.email`, which every signed-in person
-- may set to anything: typing a grantee's address into one's profile
-- read that grantee's privately shared template. 0560 removed those
-- reads. This file keeps them removed, from the catalogue, so a policy
-- or function written next year is covered the day it is written.
--
-- The invariant: only `auth.uid()`, the confirmed `auth.users` e-mail
-- and validated identity bindings decide access. A column of
-- `public.profiles` that `authenticated` may UPDATE never does.
--
-- Everything is computed, not listed:
--   * the mutable columns are those `authenticated` holds UPDATE on,
--     minus the system columns and the primary key (`profiles_update`
--     pins the row to `id = auth.uid()`, so the key cannot be moved);
--   * the authorization functions are every function a policy calls,
--     the functions those call (one level, by name in the body), and
--     every function in `public` that answers a boolean or raises 42501.
--     The last set is taken whatever its EXECUTE grant: `user_has_email`
--     is callable only by the server and still decides who may own a
--     workspace;
--   * a function or policy fails when its text mentions `profiles` AND
--     reads one of those columns qualified (`\.column\M`, whatever the
--     alias).
--
-- The regex is a net, not a parser: it can match a column of the same
-- name on another table. A body that is caught and only DISPLAYS a
-- profile value goes on the allow-list below with its reason, and the
-- allow-list is checked the other way too, so an entry that no longer
-- matches anything has to be removed.
begin;
select plan(5);

-- (function name, why it is display-only)
create or replace function pg_temp.allowed() returns table (proname text, reason text)
language sql immutable as $q$
  values
    ('posting_parties',
     'returns the payer''s display_name as a label on booked documents; access is decided before, by has_permission(viewFinances)'),
    ('get_setup_journey',
     'renders updated_by_name through profile_full_name; the match is the journey row''s own v.updated_at, not the profile''s'),
    ('get_setup_step_draft',
     'renders updated_by_name through profile_full_name; the match is the draft row''s own v.updated_at, not the profile''s');
$q$;

create or replace function pg_temp.mutable_columns() returns setof text
language sql stable as $q$
  select a.attname::text
    from pg_attribute a
   where a.attrelid = 'public.profiles'::regclass
     and a.attnum > 0 and not a.attisdropped
     and has_column_privilege('authenticated', a.attrelid, a.attnum, 'UPDATE')
     and a.attname::text <> all (public.system_column_names())
     and a.attnum <> all (coalesce((select k.conkey from pg_constraint k
                                     where k.conrelid = a.attrelid and k.contype = 'p'),
                                    '{}'::smallint[]));
$q$;

create or replace function pg_temp.policy_texts() returns table (relname text, polname text, expr text)
language sql stable as $q$
  select c.relname::text, p.polname::text,
         coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ' ' ||
         coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public';
$q$;

create or replace function pg_temp.authorization_functions() returns setof oid
language sql stable as $q$
  with fns as (
    select p.oid, p.proname::text as name, p.prosrc, p.prorettype
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
  ), called as (
    select distinct f.oid from fns f
      join pg_temp.policy_texts() t on t.expr ~ ('\m' || f.name || '\(')
  ), one_down as (
    select distinct g.oid from fns g
      join fns f on f.oid in (select oid from called)
                and f.prosrc ~ ('\m' || g.name || '\s*\(')
  ), deciders as (
    select f.oid from fns f
     where f.prorettype = 'boolean'::regtype or f.prosrc ~ '42501'
  )
  select oid from called union select oid from one_down union select oid from deciders;
$q$;

create or replace function pg_temp.reads_mutable_profile(p_text text) returns boolean
language sql stable as $q$
  select p_text ~* '\mprofiles\M'
     and exists (select 1 from pg_temp.mutable_columns() c
                  where p_text ~* ('\.' || c || '\M'));
$q$;

create or replace function pg_temp.flagged_functions() returns setof text
language sql stable as $q$
  select distinct p.proname::text
    from pg_proc p
   where p.oid in (select pg_temp.authorization_functions())
     and pg_temp.reads_mutable_profile(p.prosrc);
$q$;

-- 1. The net has something to catch: the columns a person edits about
-- themselves include the e-mail, and the authorization set includes the
-- predicates this issue is about. Without this a broken catalogue query
-- would make every check below pass on nothing.
select ok(
  'email' in (select pg_temp.mutable_columns())
  and (select count(*) from pg_proc p
        where p.oid in (select pg_temp.authorization_functions())
          and p.proname in ('holds_template_grant', 'user_has_email',
                            'may_view_member_finances', 'workspace_template_readable')) = 4,
  'the check sees the self-editable profile columns and the authorization predicates');

-- 2. No authorization function reads one.
select is_empty(
  $$ select f from pg_temp.flagged_functions() f
      where f not in (select proname from pg_temp.allowed()) $$,
  'no authorization function reads a profile column its owner may edit');

-- 3. No policy outside `profiles` itself reads one.
select is_empty(
  $$ select relname || '.' || polname from pg_temp.policy_texts()
      where relname <> 'profiles' and pg_temp.reads_mutable_profile(expr) $$,
  'no row policy decides access from a profile column its owner may edit');

-- 4. Every allow-list entry still exists and is still caught — a stale
-- entry is removed, not kept "just in case".
select is_empty(
  $$ select proname from pg_temp.allowed()
      where proname not in (select pg_temp.flagged_functions()) $$,
  'every allow-listed display reader still matches the net');

-- 5. Every allow-list entry says why.
select is_empty(
  $$ select proname from pg_temp.allowed() where length(trim(reason)) < 20 $$,
  'every allow-list entry gives its reason');

select * from finish();
rollback;
