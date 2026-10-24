-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2554 SPACE-04 (282): leaving a workspace is the workspace host's own
-- act (`leave_workspace`), and the owner handover rule holds there. The
-- only owner, with no co-owner, is refused and stays the active owner; an
-- authorized non-owner member leaves; an owner with a co-owner leaves and
-- the co-owner becomes the owner; a stranger's leave changes nobody; with
-- no session nothing happens. Leaving is not erasure: the member row stays
-- as history (exited), and the account still names the space with its
-- name and its favourite. The entry point is a definer function and a row
-- trigger, not a row policy: callers are impersonated through
-- request.jwt.claims, seeds are direct inserts as postgres. Each call's
-- answer (or SQLSTATE and message) is returned by a helper, so a refused
-- call rolls back alone. Everything rolls back.
begin;
select plan(13);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('0999e' || lpad(p_n::text, 7, '0')) $$;
create function pg_temp.w(p_n int) returns uuid language sql as $$
  select pg_temp.id('0999f' || lpad(p_n::text, 7, '0')) $$;
-- Acts as u(p_n), or with no session when p_n is null.
create function pg_temp.as_user(p_n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when p_n is null then ''
    else jsonb_build_object('sub', pg_temp.u(p_n), 'role', 'authenticated')::text end, true);
end $$;
-- One leave of w(p_ws) as u(p_n): 'ok', or the SQLSTATE and message.
create function pg_temp.leave(p_n int, p_ws int) returns text language plpgsql as $$
begin
  perform pg_temp.as_user(p_n);
  perform public.leave_workspace(pg_temp.w(p_ws));
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
-- u(p_n)'s favourite on w(p_ws) as the account writer answers it.
create function pg_temp.fav(p_n int, p_ws int) returns text language plpgsql as $$
begin
  perform pg_temp.as_user(p_n);
  return public.set_workspace_favorite_ref_v1(
    (select network_id from public.workspaces where id = pg_temp.w(p_ws)), true) ->> 'is_favorite';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
-- u(p_n)'s row in w(p_ws): owner or member, and its status; '-' when none.
create function pg_temp.row_of(p_n int, p_ws int) returns text language sql as $$
  select coalesce((select (case when is_owner then 'owner' else 'member' end) || ':' || status
                     from public.members
                    where user_id = pg_temp.u(p_n) and workspace_id = pg_temp.w(p_ws)), '-') $$;
-- What u(p_n)'s personal references say of w(p_ws): status, favourite, name.
create function pg_temp.ref_of(p_n int, p_ws int) returns text language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_n);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1() -> 'refs') e
   where e ->> 'network_id' = (select network_id from public.workspaces where id = pg_temp.w(p_ws));
  return coalesce((v ->> 'status') || ' ' || (v ->> 'is_favorite') || ' ' || (v ->> 'label'), 'none');
end $$;

-- ── fixtures ──────────────────────────────────────────────────────────
-- W1: u1 the only owner, u2 a member. W2: u3 the owner, u4 a passive
-- co-owner. u5 belongs to neither.
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-9999-leave@deskilo.test', '', now(), now(), now()
  from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (pg_temp.w(1), 'Leave 9999', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev'),
       (pg_temp.w(2), 'Handover 9999', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, co_owner, status)
values (pg_temp.id('0999c0000001'), pg_temp.w(1), pg_temp.u(1), true, true, 'none', 'active'),
       (pg_temp.id('0999c0000002'), pg_temp.w(1), pg_temp.u(2), false, false, 'none', 'active'),
       (pg_temp.id('0999c0000003'), pg_temp.w(2), pg_temp.u(3), true, true, 'none', 'active'),
       (pg_temp.id('0999c0000004'), pg_temp.w(2), pg_temp.u(4), false, false, 'passive', 'active');

-- ── the door ──────────────────────────────────────────────────────────
select is(has_function_privilege('anon', 'public.leave_workspace(uuid)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.leave_workspace(uuid)', 'EXECUTE')::text,
  'false true', 'authenticated alone executes leave_workspace');
select is(pg_temp.leave(null, 1), 'P0001 not authenticated',
  'with no session nothing is left');

-- ── the owner without a handover: refused, nothing changes ───────────
select is(pg_temp.fav(2, 1), 'true', 'precondition: the member marks W1 a favourite on the account');
select is(pg_temp.leave(1, 1), 'P0001 cannot remove the last owner of a workspace',
  'SPACE-04: the only owner, with no co-owner, cannot leave');
select is(pg_temp.row_of(1, 1), 'owner:active', 'and stays the active owner');

-- ── an authorized member leaves; history and account stay ─────────────
select is(pg_temp.leave(2, 1), 'ok', 'SPACE-04: a member who is not the owner leaves');
select is(pg_temp.row_of(2, 1), 'member:exited',
  'the membership is kept as history (exited), not deleted');
select is(pg_temp.ref_of(2, 1), 'exited true Leave 9999',
  'the account still names the space, with its name and its favourite');
select is(pg_temp.row_of(1, 1), 'owner:active', 'the owner is untouched by it');

-- ── a stranger changes nobody ─────────────────────────────────────────
select is(pg_temp.leave(5, 1) || ' ' || (select string_agg(status, ',' order by user_id)
            from public.members where workspace_id = pg_temp.w(1)),
  'ok active,exited', 'a stranger''s leave changes no membership');

-- ── the handover rule: an owner with a co-owner leaves ────────────────
select is(pg_temp.leave(3, 2), 'ok', 'SPACE-04: an owner with a co-owner leaves');
select is(pg_temp.row_of(4, 2), 'owner:active', 'the co-owner becomes the owner');
select is(pg_temp.row_of(3, 2), 'owner:exited', 'the former owner''s row stays as history');

select set_config('request.jwt.claims', '', true);
select * from finish();
rollback;
