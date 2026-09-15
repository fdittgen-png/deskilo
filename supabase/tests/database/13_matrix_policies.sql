-- SPDX-License-Identifier: 0BSD
--
-- 0216 — #1321: a narrowed admin row narrows the rows.
--
-- The role matrix lets an owner take permissions away from admins. Ten
-- row policies asked `is_admin_of` instead, so the rows the owner hid
-- still came back from PostgREST. This file seeds one workspace with an
-- owner, an admin and a member, and reads as each of them — first under
-- the default matrix, where nothing may change, then with the admin row
-- emptied, where the admin must lose exactly what the matrix took.
--
-- Real JWT claims and `set local role authenticated`: as `postgres`
-- every policy is bypassed and every assertion would pass while proving
-- nothing.
begin;
select plan(15);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000d1';
  u_admin uuid := '00000000-0000-4000-8000-0000000000d2';
  u_member uuid := '00000000-0000-4000-8000-0000000000d3';
  ws uuid;
  m_member uuid;
begin
  -- The profile comes from the trigger on `auth.users`; never insert it.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'matrix-owner@deskilo.test', '', now(), now(), now()),
         (u_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'matrix-admin@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'matrix-member@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Matrix', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false) returning id into m_member;

  -- One row the matrix governs in each table under test. The event is
  -- ABOUT the member, so the admin can only see it through the matrix.
  insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents)
  values (ws, m_member, 'stripe', 'matrix-1321', '2026-09', 100);
  insert into public.vat_declarations (workspace_id, period_start, period_end, lines,
                                       total_net_cents, total_vat_cents)
  values (ws, '2026-01-01', '2026-03-31', '[]', 0, 0);
  insert into public.packages (workspace_id, name, days, price_cents, active)
  values (ws, 'Retired pack', 10, 100, false);
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, status)
  values (ws, 'payment', 'created', m_member, m_member, 'applied');

  perform set_config('deskilo.matrix.ws', ws::text, true);
  perform set_config('deskilo.matrix.owner', u_owner::text, true);
  perform set_config('deskilo.matrix.admin', u_admin::text, true);
  perform set_config('deskilo.matrix.member', u_member::text, true);
end
$seed$;

-- Reads as [who]: the four governed rows of the seeded workspace.
create or replace function pg_temp.counts() returns int[] language sql as $counts$
  select array[
    (select count(*)::int from public.payment_intents where workspace_id = current_setting('deskilo.matrix.ws')::uuid),
    (select count(*)::int from public.vat_declarations where workspace_id = current_setting('deskilo.matrix.ws')::uuid),
    (select count(*)::int from public.packages where workspace_id = current_setting('deskilo.matrix.ws')::uuid and not active),
    (select count(*)::int from public.events where workspace_id = current_setting('deskilo.matrix.ws')::uuid)
  ];
$counts$;
grant execute on function pg_temp.counts() to authenticated;

select pg_temp.seed();

select is(pg_temp.counts(), array[1, 1, 1, 1],
  'the seed wrote a payment intent, a VAT declaration, a retired package and an event');

-- ------------------------------------------------------------ default matrix, as the admin
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.matrix.admin'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.matrix.admin'), true);
set local role authenticated;

select is((pg_temp.counts())[1], 1, 'default matrix: the admin reads the payment intent');
select is((pg_temp.counts())[2], 1, 'default matrix: the admin reads the VAT declaration');
select is((pg_temp.counts())[3], 1, 'default matrix: the admin reads the retired package');
select is((pg_temp.counts())[4], 1, 'default matrix: the admin reads the payment event');

reset role;

-- ------------------------------------------------------------ the owner empties the admin row
update public.workspaces set role_permissions = '{"admin": []}'::jsonb
 where id = current_setting('deskilo.matrix.ws')::uuid;

select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.matrix.admin'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.matrix.admin'), true);
set local role authenticated;

select is((pg_temp.counts())[1], 0, 'narrowed: no viewFinances, no payment intents');
select is((pg_temp.counts())[2], 0, 'narrowed: no viewFinances, no VAT declarations');
select is((pg_temp.counts())[3], 0, 'narrowed: no manageServices, no retired packages');
select is((pg_temp.counts())[4], 0, 'narrowed: a payment event about someone else is gone');
select throws_ok(
  $$insert into public.accessories (workspace_id, name)
    values (current_setting('deskilo.matrix.ws')::uuid, 'Blocked lamp')$$,
  '42501', null,
  'narrowed: no manageServices, no write to the accessory catalogue');

reset role;

-- ------------------------------------------------------------ the owner still holds everything
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.matrix.owner'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.matrix.owner'), true);
set local role authenticated;

select is(pg_temp.counts(), array[1, 1, 1, 1],
  'the owner reads all four whatever the admin row says');

reset role;

-- ------------------------------------------------------------ the member keeps their own
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.matrix.member'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.matrix.member'), true);
set local role authenticated;

select is((pg_temp.counts())[1], 1, 'a member still reads their own payment intent');
select is((pg_temp.counts())[2], 0, 'a member never reads the VAT declarations');

reset role;

-- ------------------------------------------------------------ the catalogue
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ilike '%is_admin_of%' or coalesce(with_check, '') ilike '%is_admin_of%')),
  0, 'no public row policy gates on is_admin_of');

select is(
  (select count(*)::int
     from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g') m
    where c.conname = 'events_type_check'
      and public.event_type_view_permissions(m[1]) = array['manageConfiguration']),
  0, 'every event type answers to a named permission, none to the fallback');

select * from finish();
rollback;
