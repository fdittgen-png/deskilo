-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4517 (1003): the owner's list of the till boards says of each whether it asks for a cashier and who sells on it
-- until when; whom may sell reads the paired boards, whether each asks, and whether they sell on it themselves, or the
-- display name of who does; a member who may not sell reads nothing; no token, nonce or hash is ever read. Rolled back.
begin;
select plan(12);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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
create or replace function pg_temp.owner_list(p_user int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.till_terminals_v1(%L)::text', pg_temp.u(101)))
$f$;
create or replace function pg_temp.cashier_list(p_user int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.till_terminal_cashier_boards_v1(%L)::text', pg_temp.u(101)))
$f$;
create or replace function pg_temp.board(p_list text, p_id int) returns jsonb language sql as $f$
  select x from jsonb_array_elements(p_list::jsonb) x where x ->> 'id' = pg_temp.u(p_id)::text
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tcashier-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 3) n;
update public.profiles set display_name = 'Camille' where id = pg_temp.u(2);
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, role_permissions, feature_flags) values
  (pg_temp.u(101), 'Cashier reads FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"admin": ["issueInvoices"]}',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterEmbeddedTerminal": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active'),    -- a cashier: an admin, who may sell
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active');   -- a member who may not sell
insert into public.counter_tills (id, workspace_id, name, active) values
  (pg_temp.u(401), pg_temp.u(101), 'Front counter', true), (pg_temp.u(402), pg_temp.u(101), 'Back counter', true);
insert into public.till_terminals (id, workspace_id, till_id, device_id, board_profile, fingerprint, firmware, protocol, secret_hash, status, approved_at)
values (pg_temp.u(601), pg_temp.u(101), pg_temp.u(401), pg_temp.u(501), 'lcdwiki_e32r40t_v1', 'AB12-CD34', '1.0.4', 'v1', repeat('a', 64), 'paired', now()),
       (pg_temp.u(602), pg_temp.u(101), pg_temp.u(402), pg_temp.u(502), 'lcdwiki_e32r40t_v1', 'AB12-CD35', '1.0.4', 'v1', repeat('b', 64), 'paired', now());
-- board 601 asks for a cashier; board 602 is sold on by Camille until a minute from now
insert into public.till_terminal_leases (id, workspace_id, terminal_id, till_id, lease_hash, request_expires_at) values
  (pg_temp.u(701), pg_temp.u(101), pg_temp.u(601), pg_temp.u(401), repeat('1', 64), now() + interval '5 minutes');
insert into public.till_terminal_leases (id, workspace_id, terminal_id, till_id, lease_hash, request_expires_at, member_id, user_id, auth_session_id,
  token_ciphertext, token_nonce, granted_at, expires_at) values
  (pg_temp.u(702), pg_temp.u(101), pg_temp.u(602), pg_temp.u(402), repeat('2', 64), now() + interval '5 minutes', pg_temp.u(202), pg_temp.u(2),
   pg_temp.u(801), '\x0102', '\x000102030405060708090a0b', now(), now() + interval '1 minute');

-- the owner's list
select is(pg_temp.board(pg_temp.owner_list(1), 601) ->> 'cashier_asked', 'true', 'the owner sees that the front board asks for a cashier');
select is(pg_temp.board(pg_temp.owner_list(1), 601) -> 'lease', 'null'::jsonb, 'and that nobody sells on it');
select is(pg_temp.board(pg_temp.owner_list(1), 602) #>> '{lease,member_name}', 'Camille', 'the owner sees who sells on the back board');
select is(pg_temp.board(pg_temp.owner_list(1), 602) #>> '{lease,id}', pg_temp.u(702)::text, 'with the lease they may end');
select ok(pg_temp.owner_list(1) !~ '(lease_hash|token|nonce|secret)', 'the list carries no token, nonce or hash');
select is(left(pg_temp.owner_list(2), 9), 'ERR DKN01', 'a cashier does not read the owner''s list');

-- the cashiers' list
select is(pg_temp.board(pg_temp.cashier_list(2), 601) ->> 'cashier_asked', 'true', 'a cashier sees the board that asks for one');
select is(pg_temp.board(pg_temp.cashier_list(2), 602) ->> 'mine', 'true', 'and the board they sell on');
select is(pg_temp.board(pg_temp.cashier_list(1), 602) ->> 'mine', 'false', 'another who may sell sees it is not theirs');
select is(pg_temp.board(pg_temp.cashier_list(1), 602) #>> '{lease,member_name}', 'Camille', 'and who sells on it, by display name');
select is(left(pg_temp.cashier_list(3), 9), 'ERR DKN01', 'a member who may not sell reads no board');
update public.till_terminal_leases set expires_at = now() - interval '1 second' where id = pg_temp.u(702);
select is(pg_temp.board(pg_temp.cashier_list(2), 602) -> 'lease', 'null'::jsonb, 'an ended lease is nobody''s');

select * from finish();
rollback;
