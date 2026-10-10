-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0399 (#2332): the currency and the country are fixed once a space holds
-- money, and members who cannot book are a required readiness step.
begin;
select plan(7);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002332a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'guard@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000002332a1","role":"authenticated"}', true);
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c332', 'Guarded', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.free', public.create_workspace_once('00000000-0000-4000-8000-00000000c333', 'Still free', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);

create function pg_temp.members_section() returns jsonb language sql as $$
  select e from jsonb_array_elements(public.workspace_readiness(current_setting('t.ws')::uuid)) e
   where e->>'section' = 'member_permissions'
$$;

select is(pg_temp.members_section()->>'state' || '/' || (pg_temp.members_section()->>'required') || '/' || (pg_temp.members_section()->>'reason'),
  'needs_configuration/true/members_cannot_book', 'a new space grants plain members nothing: a required step');

update public.workspaces set role_permissions = jsonb_build_object('member', jsonb_build_array('makeReservations', 'viewCalendar'))
 where id = current_setting('t.ws')::uuid;
select is(pg_temp.members_section()->>'state' || '/' || (pg_temp.members_section()->>'count'),
  'ready/2', 'granting makeReservations readies it; the count is the everyday permissions granted');

-- Money recorded: the currency and the country no longer move.
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
select current_setting('t.ws')::uuid, m.id, 'charge', 'subscription', 1000, 'A subscription', '2026-10'
  from public.members m where m.workspace_id = current_setting('t.ws')::uuid and m.is_owner;

select throws_ok(format('update public.workspaces set currency_code = %L where id = %L', 'CHF', current_setting('t.ws')),
  'DK423', null, 'the currency of a space holding money is fixed');
select throws_ok(format('update public.workspaces set country_code = %L where id = %L', 'DE', current_setting('t.ws')),
  'DK423', null, 'and so is its country');
select lives_ok(format('update public.workspaces set currency_code = %L, name = %L where id = %L', 'EUR', 'Guarded', current_setting('t.ws')),
  'writing the same currency again is no change');
select lives_ok(format('update public.workspaces set currency_code = %L where id = %L', 'CHF', current_setting('t.free')),
  'a space with no money yet may still change it');
select is((select currency_code from public.workspaces where id = current_setting('t.free')::uuid), 'CHF', 'and the change is kept');

select * from finish();
rollback;
