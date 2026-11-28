-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4454 (0995): a paired till board sells as the cashier who authorized it. The board asks with its proof and the
-- sha256 of a lease token; a cashier who may sell, in their own signed-in session, attaches themselves; each command
-- of the board is then resolved to that cashier's binding and encrypted token while the lease runs, the cashier is an
-- active member and their sign-in exists. A wrong proof, a revoked board, the boards switched off, a member without
-- the sale right, an assistant, a token without its session, another board's token, an expired lease, a removed
-- member, a deleted sign-in and a revoked lease are each refused with their reason; a new request ends the earlier
-- lease; a revoked board ends its leases; no client role reads the leases. Rolled back.
begin;
select plan(26);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_session uuid default null, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_session is not null then jsonb_build_object('session_id', p_session) else '{}'::jsonb end
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.secret(n int) returns text language sql immutable as $f$
  select lpad(to_hex(n), 64, '0')
$f$;
create or replace function pg_temp.sha(n int) returns text language sql immutable as $f$
  select encode(extensions.digest(decode(pg_temp.secret(n), 'hex'), 'sha256'), 'hex')
$f$;
-- the cashier [p_user] (in sign-in [p_session]) grants the board [p_terminal]
create or replace function pg_temp.grant_(p_user int, p_terminal int, p_session int, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format(
    'select public.till_terminal_lease_grant_v1(%L, %L::bytea, %L::bytea, %L)::text',
    pg_temp.u(p_terminal), '\x0102', '\x000102030405060708090a0b', now() + interval '1 hour'),
    case when p_session > 0 then pg_temp.u(p_session) end, p_delegated)
$f$;
create or replace function pg_temp.reason(p jsonb) returns text language sql immutable as $f$
  select case when (p ->> 'ok')::boolean then 'ok' else p ->> 'reason' end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tlease-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into auth.sessions (id, user_id, created_at, updated_at) values
  (pg_temp.u(701), pg_temp.u(2), now(), now()),
  (pg_temp.u(702), pg_temp.u(4), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, role_permissions, feature_flags) values
  (pg_temp.u(101), 'Till leases FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"admin": ["issueInvoices"]}',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterEmbeddedTerminal": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active'),    -- a cashier: an admin, who may sell
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active'),   -- a member without the sale right
  (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, true, 'active');
insert into public.counter_tills (id, workspace_id, name, active) values (pg_temp.u(401), pg_temp.u(101), 'Front counter', true);
insert into public.till_terminals (id, workspace_id, till_id, device_id, board_profile, fingerprint, firmware, protocol, secret_hash, status, approved_at)
values (pg_temp.u(601), pg_temp.u(101), pg_temp.u(401), pg_temp.u(501), 'lcdwiki_e32r40t_v1', 'AB12-CD34', '1.0.4', 'v1', pg_temp.sha(1), 'paired', now()),
       (pg_temp.u(602), pg_temp.u(101), pg_temp.u(401), pg_temp.u(502), 'lcdwiki_e32r40t_v1', 'AB12-CD35', '1.0.4', 'v1', pg_temp.sha(2), 'paired', now());

-- the board asks
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(9), pg_temp.sha(11))), 'pair_proof_invalid',
  'a board with a wrong secret asks for nothing');
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(11))), 'ok',
  'the paired board asks for a cashier with its lease token''s sha256');
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(11))), 'operator_pending',
  'until a cashier authorizes it, it sells nothing');

-- the cashier authorizes
select is(pg_temp.grant_(3, 601, 0), 'ERR DKN01', 'a member without the sale right cannot authorize a board');
select is(pg_temp.grant_(2, 601, 701, true), 'ERR DKN01', 'nor an assistant on the cashier''s behalf');
select is(pg_temp.grant_(2, 601, 0), 'ERR DKL02 {"reason": "operator_token"}', 'nor a token without its sign-in');
select is(pg_temp.grant_(2, 602, 701), 'ERR DKL02 {"reason": "no_request"}', 'nor a board that has not asked');
select is(pg_temp.grant_(2, 601, 701)::jsonb ->> 'member_id', pg_temp.u(202)::text, 'the cashier authorizes the board, as themselves');
select ok((select expires_at <= now() + interval '30 minutes' + interval '1 second' from public.till_terminal_leases where lease_hash = pg_temp.sha(11)),
  'for at most the operator minutes');

-- each command of the board
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(11))), 'ok',
  'the board''s command resolves to its cashier');
select is(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(11)) ->> 'token_nonce',
  encode('\x000102030405060708090a0b'::bytea, 'base64'), 'with the encrypted token and its nonce');
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(502), pg_temp.secret(2), pg_temp.sha(11))), 'scope_mismatch',
  'another board presenting the token is refused');
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(9), pg_temp.sha(11))), 'pair_proof_invalid',
  'so is the token without the board''s secret');

-- what ends a lease
delete from auth.sessions where id = pg_temp.u(701);
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(11))), 'operator_revoked',
  'the cashier signed out: the board sells no more');
select is((select token_ciphertext from public.till_terminal_leases where lease_hash = pg_temp.sha(11)), null, 'and the token is erased');
insert into auth.sessions (id, user_id, created_at, updated_at) values (pg_temp.u(703), pg_temp.u(2), now(), now());
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(12))), 'ok', 'the board asks again');
select ok(pg_temp.grant_(2, 601, 703) like '{%', 'and is authorized again');
update public.till_terminal_leases set expires_at = now() - interval '1 second' where lease_hash = pg_temp.sha(12);
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(12))), 'operator_expired',
  'an expired lease sells nothing');
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(13))), 'ok', 'a third request');
select ok(pg_temp.grant_(4, 601, 702) like '{%', 'another cashier authorizes it');
update public.members set status = 'paused' where id = pg_temp.u(204);
select is(pg_temp.reason(public.till_terminal_lease_resolve_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(13))), 'operator_revoked',
  'a cashier who is no longer an active member sells no more');
update public.members set status = 'active' where id = pg_temp.u(204);
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(14))), 'ok', 'a fourth request');
select is(pg_temp.reason(public.till_terminal_lease_request_v1(pg_temp.u(501), pg_temp.secret(1), pg_temp.sha(15))), 'ok',
  'and a fifth, which ends the fourth');
select is((select revoked_reason from public.till_terminal_leases where lease_hash = pg_temp.sha(14)), 'replaced', 'replaced, not left open');
update public.till_terminals set status = 'revoked', revoked_at = now(), approved_at = null where id = pg_temp.u(601);
select is((select count(*)::int from public.till_terminal_leases where terminal_id = pg_temp.u(601) and revoked_at is null), 0,
  'a revoked board ends all its leases');
select is(pg_temp.run_as(pg_temp.u(1), 'select count(*)::text from public.till_terminal_leases'), 'ERR 42501',
  'and no client role reads a lease, not even the owner');

select * from finish();
rollback;
