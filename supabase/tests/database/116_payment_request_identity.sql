-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2014 B (0330) — a payment request has a durable identity. The same
-- request id opens ONE intent (one payment number) however often it is
-- sent; a different payment under that id is a conflict; no request id
-- keeps the old one-intent-per-call behaviour; ids are per workspace.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000002014';
  ws uuid; m uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'request-id@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Request id', 'FR', 'EUR', 'Europe/Paris', u, '{"onlinePayments": true}') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  perform set_config('deskilo.req.ws', ws::text, false);
  perform set_config('deskilo.req.m', m::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.open(p_amount int, p_request uuid, p_provider text default 'stripe')
returns table(id uuid, reference text, reused boolean) language sql as $$
  select o.id, o.reference, o.reused from public.open_payment_intent(
    current_setting('deskilo.req.ws')::uuid, current_setting('deskilo.req.m')::uuid,
    p_provider, '2026-10', p_amount, 'EUR', p_request) o;
$$;

create temp table first_call as
  select * from pg_temp.open(2500, '11111111-1111-4111-8111-111111111111');
create temp table second_call as
  select * from pg_temp.open(2500, '11111111-1111-4111-8111-111111111111');

select is((select reused from first_call), false, 'the first call with a request id opens an intent');
select is((select reused from second_call), true, 'the retry with the same id is answered as a reuse');
select is((select id from second_call), (select id from first_call), 'and names the SAME intent');
select is((select reference from second_call), (select reference from first_call),
  'with the same payment number: none is drawn for the retry');
select is(
  (select count(*)::int from public.payment_intents
    where workspace_id = current_setting('deskilo.req.ws')::uuid),
  1, 'one intent exists for the request');

select throws_like(
  $$select * from pg_temp.open(2600, '11111111-1111-4111-8111-111111111111')$$,
  '%payment request conflict%', 'another amount under the same id is a conflict');
select throws_like(
  $$select * from pg_temp.open(2500, '11111111-1111-4111-8111-111111111111', 'paypal')$$,
  '%payment request conflict%', 'another provider under the same id is a conflict');

select isnt(
  (select id from pg_temp.open(2500, null)),
  (select id from pg_temp.open(2500, null)),
  'without a request id every call opens its own intent (the old behaviour)');

select ok(
  (select indexdef like '%(workspace_id, request_id)%' from pg_indexes
    where indexname = 'payment_intents_request_once'),
  'request ids are unique per workspace, not across installations'' workspaces');

select * from finish();
rollback;
