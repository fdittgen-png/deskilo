-- SPDX-License-Identifier: 0BSD
--
-- #1453 — a financial row cannot point into another workspace, whoever
-- writes it. Every write here runs as the privileged role the file runs
-- as, the writer RLS never sees.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001455';
  a uuid; b uuid; ma uuid; mb uuid; inv_b uuid; pa uuid; pb uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'tenants@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Tenant A', 'FR', 'EUR', 'Europe/Paris', u) returning id into a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Tenant B', 'FR', 'EUR', 'Europe/Paris', u) returning id into b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (a, u, true, true) returning id into ma;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (b, u, true, true) returning id into mb;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (b, mb, mb, 'B-1', 'September', '[]'::jsonb, 5000, 'EUR', 'M', 'Tenant B', 'M', 'sig')
  returning id into inv_b;
  insert into public.credit_products (workspace_id, name, half_days, price_cents) values (a, 'Carnet A', 10, 5000) returning id into pa;
  insert into public.credit_products (workspace_id, name, half_days, price_cents) values (b, 'Carnet B', 10, 5000) returning id into pb;
  perform set_config('deskilo.t.a', a::text, false);
  perform set_config('deskilo.t.ma', ma::text, false);
  perform set_config('deskilo.t.mb', mb::text, false);
  perform set_config('deskilo.t.inv_b', inv_b::text, false);
  perform set_config('deskilo.t.pa', pa::text, false);
  perform set_config('deskilo.t.pb', pb::text, false);
  -- reconciliation asks who is looking; the owner of both may.
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

select throws_ok(
  $$ insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.mb')::uuid,
             'credit', 'payment', 100, 'cross', '2026-09') $$,
  '23503', null, 'a ledger row in A cannot name a member of B');

select lives_ok(
  $$ insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.ma')::uuid,
             'credit', 'payment', 100, 'same', '2026-09') $$,
  'while its own member is fine');

select throws_ok(
  $$ insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                                 total_cents, currency, member_name, workspace_name, issuer_name, signature)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.mb')::uuid,
             current_setting('deskilo.t.ma')::uuid, 'A-X', 'x', '[]'::jsonb, 100, 'EUR', 'M', 'A', 'M', 'sig') $$,
  '23503', null, 'an invoice in A cannot bill a member of B');

select throws_ok(
  $$ insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.inv_b')::uuid, 5000, 'exact') $$,
  '23503', null, 'a match in A cannot settle an invoice of B');

select throws_ok(
  $$ insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.mb')::uuid,
             'stripe', 'x-1', '2026-09', 100, 'EUR', 'PAY-X') $$,
  '23503', null, 'a payment in A cannot be for a member of B');

select throws_ok(
  $$ insert into public.member_credits (workspace_id, member_id, product_id, half_days)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.ma')::uuid,
             current_setting('deskilo.t.pb')::uuid, 10) $$,
  '23503', null, 'a credit in A cannot come from a carnet of B');

-- An optional link is released, and the child keeps its workspace.
insert into public.member_credits (workspace_id, member_id, product_id, half_days)
values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.ma')::uuid,
        current_setting('deskilo.t.pa')::uuid, 10);
delete from public.credit_products where id = current_setting('deskilo.t.pa')::uuid;
select is(
  (select count(*)::int from public.member_credits
    where workspace_id = current_setting('deskilo.t.a')::uuid and product_id is null),
  1, 'deleting a carnet nulls the credit''s link and keeps its workspace');

-- The control: without the constraint the same write goes through, so the
-- refusal above is the constraint and nothing else.
alter table public.ledger_entries drop constraint ledger_entries_member_id_same_workspace;
select lives_ok(
  $$ insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
     values (current_setting('deskilo.t.a')::uuid, current_setting('deskilo.t.mb')::uuid,
             'credit', 'payment', 100, 'cross', '2026-09') $$,
  'dropping the constraint lets the cross-workspace row in');

select ok('ledger_crosses_workspaces' in (
    select r."check" from public.reconcile_workspace(current_setting('deskilo.t.a')::uuid) r),
  'which reconciliation still reports — defence in depth');

select * from finish();
rollback;
