-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4454 (0984): a till board is connected to a business, the code bound to the board's id and secret hash its QR named. Only an owner, in their own session and with the till boards
-- switched on, makes a code, for an active till and the board its QR named; a cashier, an assistant and a stranger
-- are refused; the list of boards is for whoever may open the business's settings. The board presenting its code waits for approval; the same presentation answers the same, another
-- request or a second board is refused, a wrong board or proof spends an attempt until the code is used up, and an
-- expired or withdrawn code connects nothing. The owner approves with the board's fingerprint only; a new approval of
-- the same board revokes the earlier one; a revoked board is told so. No client role reads a code, a secret or a hash,
-- and the board's functions are the service role's alone. Rolled back.
begin;
select plan(33);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
-- a secret of 32 bytes (64 hex) and the sha256 the board sends at its claim
create or replace function pg_temp.secret(n int) returns text language sql immutable as $f$
  select lpad(to_hex(n), 64, '0')
$f$;
create or replace function pg_temp.hash(n int) returns text language sql immutable as $f$
  select encode(extensions.digest(decode(pg_temp.secret(n), 'hex'), 'sha256'), 'hex')
$f$;
create or replace function pg_temp.fp(n int) returns text language sql immutable as $f$
  select upper(substr(pg_temp.hash(n), 1, 4) || '-' || substr(pg_temp.hash(n), 5, 4))
$f$;
create or replace function pg_temp.code_for(p_user int, p_device int, p_secret int, p_ws int default 101, p_till int default 401)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format(
    'select public.till_terminal_code_create_v1(%L, %L, %L, %L, %L)::text',
    pg_temp.u(p_ws), pg_temp.u(p_till), pg_temp.u(p_device), 'lcdwiki_e32r40t_v1', pg_temp.hash(p_secret)))
$f$;
create or replace function pg_temp.claim(p_code text, p_device int, p_secret int, p_req int) returns jsonb language sql as $f$
  select public.till_terminal_claim_v1(p_code, pg_temp.u(p_device), pg_temp.hash(p_secret), '1.0.3', 'v1', pg_temp.u(p_req))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tboard-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags) values
  (pg_temp.u(101), 'Till boards FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterEmbeddedTerminal": true}'),
  (pg_temp.u(102), 'Till boards off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.counter_tills (id, workspace_id, name, active) values
  (pg_temp.u(401), pg_temp.u(101), 'Front counter', true),
  (pg_temp.u(402), pg_temp.u(101), 'Old counter', false),
  (pg_temp.u(403), pg_temp.u(102), 'Counter', true);

-- who makes a code
select is(pg_temp.code_for(2, 501, 1), 'ERR 42501', 'a cashier makes no code');
select is(pg_temp.code_for(3, 501, 1), 'ERR 42501', 'nor an owner of another business');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_code_create_v1(%L, %L, %L, %L, %L)::text',
  pg_temp.u(101), pg_temp.u(401), pg_temp.u(501), 'lcdwiki_e32r40t_v1', pg_temp.hash(1)), true), 'ERR 42501', 'nor the owner''s assistant');
select is(pg_temp.code_for(3, 503, 3, 102, 403), 'ERR 42501', 'nor an owner whose till boards are off');
select is(pg_temp.code_for(1, 501, 1, 101, 402), 'ERR 22023', 'a till that is not active takes no board');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_code_create_v1(%L, %L, %L, %L, %L)::text',
  pg_temp.u(101), pg_temp.u(401), pg_temp.u(501), 'some_other_board', pg_temp.hash(1))), 'ERR 22023', 'nor a board of an unknown profile');

select set_config('t.c1', pg_temp.code_for(1, 501, 1), false);
select ok(current_setting('t.c1')::jsonb ->> 'code' ~ '^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$',
  'the owner is given a code of 12 Crockford characters, in three groups');
select is((select count(*)::int from public.till_terminal_codes
            where code_hash = encode(extensions.digest(replace(current_setting('t.c1')::jsonb ->> 'code', '-', ''), 'sha256'), 'hex')),
  1, 'the server keeps the code''s hash');
select is((select count(*)::int from public.till_terminal_codes where code_hash ~ (current_setting('t.c1')::jsonb ->> 'code')),
  0, 'never the code');

-- the board presents it
select is(pg_temp.claim(current_setting('t.c1')::jsonb ->> 'code', 509, 1, 601) ->> 'reason', 'pair_proof_invalid',
  'another board with the code is refused');
select is(pg_temp.claim(current_setting('t.c1')::jsonb ->> 'code', 501, 9, 601) ->> 'reason', 'pair_proof_invalid',
  'and so is the right board with another secret');
select is(public.till_terminal_claim_v1(current_setting('t.c1')::jsonb ->> 'code', pg_temp.u(501),
  substr(pg_temp.hash(1), 1, 8) || repeat('0', 56), '1.0.3', 'v1', pg_temp.u(601)) ->> 'reason', 'pair_proof_invalid',
  'and a hash that only shares the fingerprint: the code is bound to the whole hash the QR named');
select is((select attempts_left from public.till_terminal_codes where id = (current_setting('t.c1')::jsonb ->> 'code_id')::uuid),
  2, 'each spends an attempt');
select is(public.till_terminal_claim_v1(current_setting('t.c1')::jsonb ->> 'code', pg_temp.u(501), pg_temp.hash(1), '1.0.3', 'v2', pg_temp.u(601)) ->> 'reason',
  'protocol_unsupported', 'a protocol the server does not speak is refused');
select set_config('t.k1', pg_temp.claim(lower(replace(current_setting('t.c1')::jsonb ->> 'code', '-', ' ')), 501, 1, 601)::text, false);
select is(current_setting('t.k1')::jsonb ->> 'status', 'pending_approval', 'the board with its own proof waits for approval, the code typed in any case');
select is(pg_temp.claim(current_setting('t.c1')::jsonb ->> 'code', 501, 1, 601)::text, current_setting('t.k1'),
  'the same presentation, its answer lost, answers the same');
select is(pg_temp.claim(current_setting('t.c1')::jsonb ->> 'code', 501, 1, 602) ->> 'reason', 'pair_used', 'another request with the code is refused');
select is(public.till_terminal_status_v1(pg_temp.u(501), pg_temp.secret(1)) ->> 'status', 'pending_approval', 'the board, proving its secret, learns it waits');
select is(public.till_terminal_status_v1(pg_temp.u(501), pg_temp.secret(2)) ->> 'reason', 'pair_proof_invalid', 'another secret learns nothing');

-- the owner approves with the fingerprint
select is(pg_temp.run_as(pg_temp.u(2), format('select public.till_terminal_approve_v1(%L, %L)::text', current_setting('t.k1')::jsonb ->> 'terminal_id', pg_temp.fp(1))),
  'ERR 42501', 'a cashier approves no board');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_approve_v1(%L, %L)::text', current_setting('t.k1')::jsonb ->> 'terminal_id', pg_temp.fp(2))),
  'ERR 22023', 'another fingerprint approves nothing');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_approve_v1(%L, %L)::jsonb ->> %L', current_setting('t.k1')::jsonb ->> 'terminal_id', lower(pg_temp.fp(1)), 'status')),
  'paired', 'the board''s own fingerprint approves it');
select is(public.till_terminal_status_v1(pg_temp.u(501), pg_temp.secret(1)) ->> 'till_id', pg_temp.u(401)::text, 'and the board learns its till from the server');
select ok(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminals_v1(%L)::text', pg_temp.u(101))) !~ pg_temp.hash(1),
  'the owner''s list carries no hash');
select is(pg_temp.run_as(pg_temp.u(2), format('select public.till_terminals_v1(%L)::text', pg_temp.u(101))), 'ERR 42501',
  'a cashier, who may not open the settings, reads no list');

-- a code withdrawn, expired or used up connects nothing; a new approval of the same board revokes the earlier one
select set_config('t.c2', pg_temp.code_for(1, 501, 5), false);
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_code_cancel_v1(%L)::text', current_setting('t.c2')::jsonb ->> 'code_id')), 'true', 'the owner withdraws a code');
select is(pg_temp.claim(current_setting('t.c2')::jsonb ->> 'code', 501, 5, 603) ->> 'reason', 'pair_expired', 'a withdrawn code connects nothing');
select set_config('t.c3', pg_temp.code_for(1, 501, 5), false);
update public.till_terminal_codes set expires_at = now() - interval '1 second' where id = (current_setting('t.c3')::jsonb ->> 'code_id')::uuid;
select is(pg_temp.claim(current_setting('t.c3')::jsonb ->> 'code', 501, 5, 604) ->> 'reason', 'pair_expired', 'nor an expired one');
select set_config('t.c4', pg_temp.code_for(1, 501, 5), false);
update public.till_terminal_codes set attempts_left = 0 where id = (current_setting('t.c4')::jsonb ->> 'code_id')::uuid;
select is(pg_temp.claim(current_setting('t.c4')::jsonb ->> 'code', 501, 5, 605) ->> 'reason', 'pair_used', 'nor one whose attempts are spent');
select set_config('t.c5', pg_temp.code_for(1, 501, 5), false);
select set_config('t.k5', pg_temp.claim(current_setting('t.c5')::jsonb ->> 'code', 501, 5, 606)::text, false);
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_approve_v1(%L, %L)::jsonb ->> %L', current_setting('t.k5')::jsonb ->> 'terminal_id', pg_temp.fp(5), 'status')),
  'paired', 'the same board, with a new secret, is approved again');
select is(public.till_terminal_status_v1(pg_temp.u(501), pg_temp.secret(1)) ->> 'reason', 'device_revoked', 'and its earlier enrollment is told it is revoked');

-- no client role reads the tables; the board's functions are the service role's alone
select is(pg_temp.run_as(pg_temp.u(1), 'select count(*)::text from public.till_terminals'), 'ERR 42501', 'an owner reads no board row directly');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.till_terminal_claim_v1(%L, %L, %L, %L, %L, %L)::text',
  current_setting('t.c1')::jsonb ->> 'code', pg_temp.u(501), pg_temp.hash(1), '1.0.3', 'v1', pg_temp.u(601))), 'ERR 42501', 'and calls no board function');

select * from finish();
rollback;
