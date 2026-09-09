-- SPDX-License-Identifier: 0BSD
--
-- #1047 — close the anon execute grant on every public function.
--
-- The rule has been stated since 0004: `revoke execute … from public,
-- anon` on every new function. A review of the live catalogue found it
-- held on 161 functions and was missed on 99, because nothing enforced
-- it.
--
-- Why an omission is permanent once made: `CREATE OR REPLACE FUNCTION`
-- **preserves the existing ACL**. A function first created WITH a
-- revoke keeps it through every later version; one first created
-- WITHOUT never acquires it. The miss is therefore decided by the
-- migration that introduces a function, and never corrects itself —
-- which is why this is a sweep and not a list.
--
-- Most of the 99 were harmless in practice: they re-check the caller
-- with auth.uid(), has_permission() or is_member_of(), and `anon` has
-- no uid, so the body refused. That is the second line of defence doing
-- its job, and not a reason to leave the first one open — one function
-- that forgets its internal check is then reachable unauthenticated.
--
-- Nothing pre-authentication calls a public function: sign-in and
-- sign-up go through GoTrue, and the client makes no RPC call while
-- signed out. So `authenticated` keeps every grant it had. Verified on
-- the live catalogue in a rolled-back transaction before applying:
-- anon 99 → 0, authenticated 225 → 225.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and (p.proacl is null
           or array_to_string(p.proacl::text[], ' ') like '%anon=X%')
  loop
    execute format('revoke execute on function %s from public, anon', r.sig);
  end loop;
end
$$;
