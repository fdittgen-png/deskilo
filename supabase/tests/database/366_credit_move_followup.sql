-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3346 (0690) -- follow-up to the credit move: the biller never moves a
-- payment onto, or off, their own account; the receiving member's month must
-- be open too (a voided invoice does not close it); a moved credit can no
-- longer be matched to an invoice, by either match table; and the refusals the
-- review listed as untested are pinned: a closed book period, bankImport off,
-- another workspace's credit, the invoice_match_payments branch.
begin;
select plan(17);

create or replace function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003346' || p)::uuid
$$;
create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.fu.ws')::uuid
$$;
create or replace function pg_temp.m(p text) returns uuid language sql as $$
  select id from public.members where workspace_id = pg_temp.ws() and user_id = pg_temp.u(p)
$$;
create or replace function pg_temp.act_as(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
create or replace function pg_temp.mv(p_credit uuid, p_to text, p_req text)
returns jsonb language sql as $$
  select public.move_payment_credit_v1(p_credit, pg_temp.m(p_to), 'paid by the colleague', md5(p_req)::uuid)
$$;
create or replace function pg_temp.credit(p_who text, p_cents int, p_period text, p_day date) returns uuid
language plpgsql as $$
declare v uuid;
begin
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (pg_temp.ws(), pg_temp.m(p_who), 'credit', 'payment', p_cents, 'Bank transfer', p_period, p_day)
  returning id into v;
  return v;
end;
$$;
create or replace function pg_temp.invoice(p_who text, p_number text, p_period text, p_voided boolean default false)
returns uuid language plpgsql as $$
declare v uuid;
begin
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, kind, voided_at)
  values (pg_temp.ws(), pg_temp.m(p_who), pg_temp.m('a1'), p_number, p_period, p_period, '[]', 0, 'EUR', p_who, 'W', 'O',
          repeat('s', 64), 'full', case when p_voided then now() end)
  returning id into v;
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@credit-follow.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a5', 'a6']) s;
-- a1 owner (the biller), a2 the wrong payer, a3 and a5 receivers, a6 another space's owner.
with w as (
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Follow a credit move', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a1'),
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb)
  returning id)
select set_config('deskilo.fu.ws', (select id from w)::text, true);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.ws(), pg_temp.u('a1'), true, true, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a2'), false, false, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a3'), false, false, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a5'), false, false, 'active', '2026-01-01');
select set_config('deskilo.fu.c1', pg_temp.credit('a2', 4200, '2026-03', '2026-03-10')::text, true);
select set_config('deskilo.fu.own', pg_temp.credit('a1', 1000, '2026-03', '2026-03-12')::text, true);

-- 1-2. finding 1: not to, nor from, the biller's own account
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c1')::uuid, 'a1', 'f1') $$,
  '42501', 'you may not move a payment to or from your own account', 'not onto the biller''s own account');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.own')::uuid, 'a3', 'f2') $$,
  '42501', 'you may not move a payment to or from your own account', 'nor off it');
reset role;

-- 3-4. finding 2: the receiving member's month; a voided invoice does not close it
select pg_temp.invoice('a3', 'F-1', '2026-03');
select pg_temp.invoice('a5', 'F-V', '2026-03', true);
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c1')::uuid, 'a3', 'f3') $$,
  '22023', 'this month is already invoiced to the receiving member: correct that invoice first',
  'a month already invoiced to the receiver is not reopened');
select lives_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c1')::uuid, 'a5', 'f4') $$,
  'a voided invoice does not block the receiving month');
reset role;

-- 5-8. finding 3: a moved credit is never matched, by either match table
select ok(exists (select 1 from public.ledger_credit_moves where from_credit_id = current_setting('deskilo.fu.c1')::uuid),
  'the credit was moved');
select throws_ok($$ insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, payment_ledger_id)
                    select pg_temp.ws(), id, 4200, 'exact', 'confirmed', current_setting('deskilo.fu.c1')::uuid
                      from public.invoices where number = 'F-1' $$,
  '22023', 'this credit was moved: it cannot pay an invoice', 'a moved credit cannot be matched');
select throws_ok($$ insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution)
                    select pg_temp.ws(), id, current_setting('deskilo.fu.c1')::uuid, 4200, 'exact'
                      from public.invoices where number = 'F-1' $$,
  '22023', 'this credit was moved: it cannot pay an invoice', 'nor by the partial-payment table');
select set_config('deskilo.fu.c6', pg_temp.credit('a3', 100, '2026-03', '2026-03-20')::text, true);
select lives_ok($$ insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, payment_ledger_id)
                   select pg_temp.ws(), id, 100, 'exact', 'confirmed', current_setting('deskilo.fu.c6')::uuid
                     from public.invoices where number = 'F-1' $$,
  'a credit that was not moved matches as before');

-- 9-10. the invoice_match_payments branch of the move's own check
select set_config('deskilo.fu.c4', pg_temp.credit('a2', 700, '2026-04', '2026-04-03')::text, true);
select pg_temp.invoice('a3', 'F-2', '2026-05');
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution)
select pg_temp.ws(), id, current_setting('deskilo.fu.c4')::uuid, 700, 'exact' from public.invoices where number = 'F-2';
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c4')::uuid, 'a3', 'f5') $$,
  '22023', 'this credit pays an invoice: undo the match first', 'a credit paying through the partial table is not moved');
reset role;
select is((select count(*)::int from public.ledger_credit_moves where from_credit_id = current_setting('deskilo.fu.c4')::uuid),
  0, 'and no move was recorded');

-- 11. a closed period of the books
select set_config('deskilo.fu.c3', pg_temp.credit('a2', 300, '2026-02', '2026-02-10')::text, true);
insert into public.book_periods (workspace_id, period_from, period_to, reason, closed_by_member_id)
values (pg_temp.ws(), '2026-02-01', '2026-02-28', 'owner', pg_temp.m('a1'));
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c3')::uuid, 'a3', 'f6') $$,
  '22023', 'this credit is dated inside a closed period of the books', 'a closed period is not moved into');
reset role;

-- 12. bankImport off
update public.workspaces set feature_flags = feature_flags || '{"bankImport": false}'::jsonb where id = pg_temp.ws();
select set_config('deskilo.fu.c5', pg_temp.credit('a2', 200, '2026-06', '2026-06-04')::text, true);
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.fu.c5')::uuid, 'a3', 'f7') $$,
  '0A000', 'bank statements are switched off in this space', 'with bankImport off nothing moves');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"bankImport": true}'::jsonb where id = pg_temp.ws();

-- 13. another workspace's credit
with w as (
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a6'),
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb)
  returning id)
select set_config('deskilo.fu.ws2', (select id from w)::text, true);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (current_setting('deskilo.fu.ws2')::uuid, pg_temp.u('a6'), true, true, 'active', '2026-01-01');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
select ws, id, 'credit', 'payment', 500, 'Elsewhere', '2026-03', '2026-03-05'
  from (select current_setting('deskilo.fu.ws2')::uuid ws, (select id from public.members
         where workspace_id = current_setting('deskilo.fu.ws2')::uuid) id) x;
select pg_temp.act_as('a1');
select throws_ok($$ select public.move_payment_credit_v1(
    (select id from public.ledger_entries where workspace_id = current_setting('deskilo.fu.ws2')::uuid),
    pg_temp.m('a3'), 'not mine', md5('f8')::uuid) $$,
  '42501', null, 'another space''s credit is not the biller''s to move');
reset role;

-- 14-17. the move's exactly-once guarantees still hold for the first move
select is((select count(*)::int from public.ledger_credit_moves where workspace_id = pg_temp.ws()), 1,
  'exactly one move was made in this space');
select is((select count(*)::int from public.ledger_credit_moves where to_member_id = pg_temp.m('a1') or from_member_id = pg_temp.m('a1')),
  0, 'none touches the biller');
select is((select count(*)::int from public.ledger_credit_moves where to_member_id = pg_temp.m('a3')),
  0, 'none landed in the invoiced month');
select ok(public.book_period_closed(pg_temp.ws(), '2026-02-10'), 'the closed period stayed closed');

select * from finish();
rollback;
