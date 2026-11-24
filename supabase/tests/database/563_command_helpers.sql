-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4399 (0948): `command_actor` answers the acting member and refuses as the stock helpers do (the same answer, the
-- same code, the same words as `stock_ops_actor`); `request_begin` / `request_finish` store a command's answer once:
-- a replay answers the stored result, another digest or another operation under the same request id is refused, and
-- another business is independent. Rolled back.
begin;
select plan(16);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004399' || lpad(n::text, 4, '0'))::uuid;
$$;
-- the answer of a statement run as a signed-in user (null = nobody), or ERR, its code and its message
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', case when n is null then '' else json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text end, true);
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate || ' ' || sqlerrm;
  end;
  return coalesce(v, 'null');
end $f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'cmd' || n || '@example.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Commands on', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": true}', '{"admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Commands off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": false}', '{"admin": ["manageStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
  (pg_temp.u(211), pg_temp.u(102), pg_temp.u(1), true, true, 'active', '2026-01-01');

create function pg_temp.helper(n int, p_ws int) returns text language sql as $$
  select pg_temp.as_user(n, format($q$select public.command_actor(%L, 'manageStock', 'stockManagement', 'not allowed to move stock', 'stock management is off', 'DKG01')::text$q$, pg_temp.u(p_ws)))
$$;
create function pg_temp.old(n int, p_ws int) returns text language sql as $$
  select pg_temp.as_user(n, format($q$select public.stock_ops_actor(%L)::text$q$, pg_temp.u(p_ws)))
$$;

-- ── the actor: the same answer as the stock helper, for every kind of caller ──
select is(pg_temp.helper(1, 101), pg_temp.u(201)::text, 'the owner is the acting member');
select is(pg_temp.helper(1, 101), pg_temp.old(1, 101), 'and the stock helper answers the same');
select is(pg_temp.helper(2, 101), 'ERR DKN01 not allowed to move stock', 'a member without the permission is refused in the caller''s words');
select is(pg_temp.helper(2, 101), pg_temp.old(2, 101), 'as the stock helper refuses');
select is(pg_temp.helper(3, 101), pg_temp.old(3, 101), 'a stranger is refused alike');
select is(left(pg_temp.helper(null, 101), 10), 'ERR DKN01 ', 'nobody signed in is refused');
select is(pg_temp.helper(1, 102), 'ERR DKG01 stock management is off', 'a business with the feature off is refused with the domain''s own code');
select is(pg_temp.helper(1, 102), pg_temp.old(1, 102), 'as the stock helper refuses');
select is(pg_temp.as_user(1, format($q$select public.command_actor(%L, 'manageStock')::text$q$, pg_temp.u(102))), pg_temp.u(211)::text,
  'with no feature named the feature is not asked about');

-- ── the request pair ──
create function pg_temp.begin(p_ws int, p_req int, p_op text, p_digest text) returns text language sql as $$
  select pg_temp.as_user(1, format($q$select public.request_begin(%L, %L, %L, %L)::text$q$, pg_temp.u(p_ws), pg_temp.u(p_req), p_op, p_digest))
$$;
create function pg_temp.finish(p_ws int, p_req int, p_op text, p_digest text, p_result text) returns text language sql as $$
  select pg_temp.as_user(1, format($q$select public.request_finish(%L, %L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(p_ws), pg_temp.u(p_req), p_op, p_digest, p_result))
$$;
select is(pg_temp.begin(101, 901, 'op_a', 'd1'), 'null', 'a new request is not stored: the command goes on');
select is(pg_temp.finish(101, 901, 'op_a', 'd1', '{"ok": 1}'), '{"ok": 1}', 'finishing stores its result and answers it');
select is(pg_temp.begin(101, 901, 'op_a', 'd1'), '{"ok": 1}', 'a replay answers the stored result');
select is(pg_temp.begin(101, 901, 'op_a', 'd2'), 'ERR DKG07 this request id was already used for a different request', 'another digest under the same request id is refused');
select is(left(pg_temp.begin(101, 901, 'op_b', 'd1'), 11), 'ERR DKG07 t', 'so is another operation');
select is(pg_temp.begin(102, 901, 'op_a', 'd1'), 'null', 'another business is independent');
select is(left(pg_temp.begin(101, 902, 'op_a', ''), 11), 'ERR DKG07 a', 'a command without a digest is refused before it can be stored');

select * from finish();
rollback;
