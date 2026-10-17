-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- A payment offered to the match command by a cached client list is
-- re-checked by the server under the real `authenticated` role: a payment
-- another session already consumed, an amount sized for a remainder that
-- has since moved, a payment of another workspace and a caller without the
-- issuing permission are all refused, and after every refusal the stored
-- match, the consumption junction and the event log read back unchanged.
-- Positive controls consume real payments first, so a refusal is never the
-- answer of an empty fixture. The consume-once guarantee under two
-- simultaneous sessions rests on payment_ledger_id being unique in
-- invoice_match_payments; this file proves the sequential stale case.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000258701';
  up uuid := '00000000-0000-4000-8000-000000258702';
  ux uuid := '00000000-0000-4000-8000-000000258703';
  ws uuid; wx uuid; mo uuid; mp uuid; mxo uuid;
  ia uuid; ib uuid; ic uuid; ix uuid;
  p1 uuid; p2 uuid; p3 uuid; p4 uuid; px uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@stale2587.test','',now(),now(),now()),
          (up,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','plain@stale2587.test','',now(),now(),now()),
          (ux,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','other@stale2587.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Stale 2587','FR','EUR','Europe/Paris',uo) returning id into ws;
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Stale 2587 other','FR','EUR','Europe/Paris',ux) returning id into wx;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (ws,uo,true,true) returning id into mo;
  insert into public.members(workspace_id,user_id) values (ws,up) returning id into mp;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (wx,ux,true,true) returning id into mxo;

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, mp, mo, 'S-A', 'A', '[]'::jsonb, 5000, 'EUR', 'M', 'Stale 2587', 'O', 's') returning id into ia;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, mp, mo, 'S-B', 'B', '[]'::jsonb, 5000, 'EUR', 'M', 'Stale 2587', 'O', 's') returning id into ib;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, mp, mo, 'S-C', 'C', '[]'::jsonb, 5000, 'EUR', 'M', 'Stale 2587', 'O', 's') returning id into ic;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (wx, mxo, mxo, 'X-1', 'X', '[]'::jsonb, 5000, 'EUR', 'M', 'Stale 2587 other', 'O', 's') returning id into ix;

  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
   values (ws, mp, 'credit', 'payment', 5000, 'transfer 1', '2026-09') returning id into p1;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
   values (ws, mp, 'credit', 'payment', 2000, 'transfer 2', '2026-09') returning id into p2;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
   values (ws, mp, 'credit', 'payment', 3000, 'transfer 3', '2026-09') returning id into p3;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
   values (ws, mp, 'credit', 'payment', 5000, 'transfer 4', '2026-09') returning id into p4;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
   values (wx, mxo, 'credit', 'payment', 5000, 'foreign transfer', '2026-09') returning id into px;

  perform set_config('sc.ws', ws::text, false);
  perform set_config('sc.ia', ia::text, false);
  perform set_config('sc.ib', ib::text, false);
  perform set_config('sc.ic', ic::text, false);
  perform set_config('sc.ix', ix::text, false);
  perform set_config('sc.p1', p1::text, false);
  perform set_config('sc.p2', p2::text, false);
  perform set_config('sc.p3', p3::text, false);
  perform set_config('sc.p4', p4::text, false);
  perform set_config('sc.px', px::text, false);
  perform set_config('sc.uo', uo::text, false);
  perform set_config('sc.up', up::text, false);
  perform set_config('sc.ux', ux::text, false);
end;
$seed$;

create or replace function pg_temp.g(k text) returns uuid language sql as $$
  select current_setting('sc.' || k)::uuid;
$$;
create or replace function pg_temp.act_as(who text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('sc.' || who), 'role', 'authenticated')::text, false);
end;
$$;
-- matches / consumed payments / invoice_payment events of the workspace
create or replace function pg_temp.state() returns text language sql as $$
  select (select count(*) from public.invoice_matches where workspace_id = pg_temp.g('ws'))
      || '/' || (select count(*) from public.invoice_match_payments where workspace_id = pg_temp.g('ws'))
      || '/' || (select count(*) from public.events where workspace_id = pg_temp.g('ws') and type = 'invoice_payment');
$$;

select pg_temp.seed();
set local role authenticated;
select pg_temp.act_as('uo');

-- positive control: the first attempt consumes the payment
select lives_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ia'), pg_temp.g('p1')),
  'the owner matches the whole payment to invoice A');
select is(pg_temp.state(), '1/1/1', 'one match, one consumed payment, one event are stored');
select is((select invoice_id from public.invoice_match_payments where payment_ledger_id = pg_temp.g('p1')),
          pg_temp.g('ia'), 'the payment is consumed by invoice A');

-- stale candidate: the cached list still offers p1 for invoice B
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ib'), pg_temp.g('p1')),
  'P0001', 'payment already matched', 'a payment consumed by another match is refused for a second invoice');
select is(pg_temp.state(), '1/1/1', 'the refusal changed no match, no junction row and no event');
select is((select invoice_id from public.invoice_match_payments where payment_ledger_id = pg_temp.g('p1')),
          pg_temp.g('ia'), 'the payment is still consumed by A only');
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ia'), pg_temp.g('p1')),
  'P0001', 'invoice already matched', 'retrying the same match consumes nothing twice');
select is(pg_temp.state(), '1/1/1', 'the retry changed nothing either');

-- stale remainder: invoice C takes a partial, the chooser still sized for 5000
select lives_ok(format($$ select public.match_invoice(%L, %L, 'under_accepted', 'part') $$, pg_temp.g('ic'), pg_temp.g('p2')),
  'a partial payment of 2000 stands on invoice C');
select is((select paid_cents from public.invoice_matches where invoice_id = pg_temp.g('ic')), 2000,
  'C reads back 2000 paid');
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ic'), pg_temp.g('p4')),
  'P0001', 'amount does not match the invoice', 'a 5000 payment is not exact against the 3000 that remains');
select is((select paid_cents from public.invoice_matches where invoice_id = pg_temp.g('ic')), 2000,
  'the remainder read back is unchanged after the refusal');
select ok(not exists (select 1 from public.invoice_match_payments where payment_ledger_id = pg_temp.g('p4')),
  'the refused payment stays unconsumed');
select lives_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ic'), pg_temp.g('p3')),
  'the payment that equals the remainder settles C');

-- isolation: another workspace's payment, and callers without permission
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ib'), pg_temp.g('px')),
  'P0001', 'unknown payment', 'a payment of another workspace is unknown to this workspace');
select pg_temp.act_as('up');
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ib'), pg_temp.g('p4')),
  'P0001', 'admins may not issue invoices here', 'a plain member may not match');
select pg_temp.act_as('ux');
select throws_ok(format($$ select public.match_invoice(%L, %L, 'exact', '') $$, pg_temp.g('ib'), pg_temp.g('p4')),
  'P0001', 'not a member', 'a member of another workspace may not match');

select * from finish();
rollback;
