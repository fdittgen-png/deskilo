-- SPDX-License-Identifier: AGPL-3.0-or-later
-- DesKilo hardening (issue #31, driven by Supabase security advisors).
-- Applied to the hosted reference project on 2026-07-07.
--
-- Principle: trigger functions are not callable at all; helper predicates and
-- RPCs are callable by authenticated only (they are the intended API surface);
-- nothing SECURITY DEFINER is callable by anon.

-- #1226 — `create` before `alter`.
--
-- This line only ever MOVED an extension somebody had switched on from
-- the dashboard. On an empty database there was nothing to move, so the
-- whole migration history stopped here — which is how we learned, on the
-- day CI first replayed it, that these 210 files could not rebuild the
-- schema they describe.
--
-- btree_gist is not decoration: 0005's `exclude using gist (seat_id with
-- =, tstzrange(...) with &&)` is the constraint that stops two members
-- booking one seat, and gist cannot compare a uuid with `=` without it.
-- The app's most important invariant rested on a checkbox in a web
-- console. It rests on this line now.
--
-- Both halves are conditional so the file behaves the same on an empty
-- database and on the two projects where it has already run.
create extension if not exists btree_gist with schema extensions;
do $btree$
begin
  if (select n.nspname
        from pg_extension e join pg_namespace n on n.oid = e.extnamespace
       where e.extname = 'btree_gist') <> 'extensions' then
    execute 'alter extension btree_gist set schema extensions';
  end if;
end
$btree$;

-- trigger-only functions: no direct execution by any API role
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.protect_last_owner() from public, anon, authenticated;
-- server-side default helper: not an API
revoke execute on function public.gen_invite_code() from public, anon, authenticated;

-- RLS helper predicates: authenticated only (policies evaluate as the caller)
revoke execute on function public.is_member_of(uuid) from public, anon;
revoke execute on function public.is_admin_of(uuid) from public, anon;
revoke execute on function public.is_owner_of(uuid) from public, anon;
revoke execute on function public.shares_workspace_with(uuid) from public, anon;

-- RPCs: authenticated only (they raise on missing auth.uid() anyway)
revoke execute on function public.create_workspace(text, text, text, text) from public, anon;
revoke execute on function public.join_workspace(text) from public, anon;
revoke execute on function public.leave_workspace(uuid) from public, anon;
