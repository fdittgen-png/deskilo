-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3095 / 0617: the caller's right is checked before the state of the row.
-- A signed-in owner of ANOTHER workspace gets one answer from void_invoice,
-- record_invoice_reminder and settle_credit_invoice whether the invoice is
-- unknown, voided or live; add_conversation_participant answers a stranger
-- the same for a missing and an existing group; set_room_rental_fees_v1
-- refuses a role, plan or member of another workspace.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000003140aa';
  u_b uuid := '00000000-0000-4000-8000-0000003140bb';
  ws_a uuid; ws_b uuid; m_a uuid; m_b uuid; v_inv uuid; v_conv uuid; v_rental uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'a314@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'b314@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Space A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Space B', 'FR', 'EUR', 'Europe/Paris', u_b) returning id into ws_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_b, u_b, true, true) returning id into m_b;
  -- one voided and one live invoice of Space A
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, voided_at)
  values (ws_a, m_a, m_a, 'A-V', 'A', '[]'::jsonb, 10000, 'EUR', 'A', 'Space A', 'A', 'sig', now());
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws_a, m_a, m_a, 'A-L', 'A', '[]'::jsonb, -10000, 'EUR', 'A', 'Space A', 'A', 'sig');
  insert into public.conversations (workspace_id, kind, title, created_by)
  values (ws_a, 'group', 'G314', m_a) returning id into v_conv;
  perform set_config('deskilo.test.u_b', u_b::text, false);
  perform set_config('deskilo.test.ws_a', ws_a::text, false);
  perform set_config('deskilo.test.ws_b', ws_b::text, false);
  perform set_config('deskilo.test.m_b', m_b::text, false);
  perform set_config('deskilo.test.voided', (select id::text from public.invoices where number = 'A-V'), false);
  perform set_config('deskilo.test.live', (select id::text from public.invoices where number = 'A-L'), false);
  perform set_config('deskilo.test.conv', v_conv::text, false);
end;
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select pg_temp.seed();

set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.u_b'), 'role', 'authenticated')::text, true);

select throws_ok($$select public.void_invoice('00000000-0000-4000-8000-0000000000ff')$$,
  'P0001', 'not a member', 'void_invoice: an unknown invoice reads like a foreign one');
select throws_ok(format('select public.void_invoice(%L)', current_setting('deskilo.test.voided')),
  'P0001', 'not a member', 'void_invoice: a foreign VOIDED invoice does not say it is voided');
select throws_ok(format('select public.record_invoice_reminder(%L)', current_setting('deskilo.test.voided')),
  'P0001', 'not a member', 'record_invoice_reminder: a foreign voided invoice does not say it is voided');
select throws_ok(format('select public.settle_credit_invoice(%L)', current_setting('deskilo.test.voided')),
  'P0001', 'not a member', 'settle_credit_invoice: a foreign voided invoice does not say it is voided');
select throws_ok(format('select public.settle_credit_invoice(%L)', current_setting('deskilo.test.live')),
  'P0001', 'not a member', 'settle_credit_invoice: a foreign credit note is refused as a non-member');
select throws_ok($$select public.add_conversation_participant('00000000-0000-4000-8000-0000000000ff', gen_random_uuid())$$,
  'P0001', 'only a group admin can add people', 'add_conversation_participant: an unknown group reads like one the caller does not administer');
select throws_ok(format('select public.add_conversation_participant(%L, gen_random_uuid())', current_setting('deskilo.test.conv')),
  'P0001', 'only a group admin can add people', 'add_conversation_participant: a foreign group gives the same answer');
reset role;

select ok(position('a fee entry is not of this space' in pg_get_functiondef('public.set_room_rental_fees_v1(uuid,uuid,jsonb)'::regprocedure)) > 0
          and position('a fee entry is not of this space' in pg_get_functiondef('public.set_room_rental_fees_v1(uuid,uuid,jsonb)'::regprocedure))
              < position('insert into public.room_rental_fees' in pg_get_functiondef('public.set_room_rental_fees_v1(uuid,uuid,jsonb)'::regprocedure)),
  'set_room_rental_fees_v1 checks each entry against its own workspace before the insert');
select ok(position('issuing_member' in pg_get_functiondef('public.void_invoice(uuid)'::regprocedure))
          < position('invoice is settled' in pg_get_functiondef('public.void_invoice(uuid)'::regprocedure)),
  'void_invoice asks the actor check before any state-specific refusal');

select * from finish();
rollback;
