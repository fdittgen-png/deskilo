-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1453, second checkpoint — the relations that are not money: a note,
-- a negotiation, cannot name a member of another workspace either.
begin;
select plan(4);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001456';
  a uuid; b uuid; ma uuid; mb uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'people@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('People A', 'FR', 'EUR', 'Europe/Paris', u) returning id into a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('People B', 'FR', 'EUR', 'Europe/Paris', u) returning id into b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (a, u, true, true) returning id into ma;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (b, u, true, true) returning id into mb;
  perform set_config('deskilo.p.a', a::text, false);
  perform set_config('deskilo.p.ma', ma::text, false);
  perform set_config('deskilo.p.mb', mb::text, false);
end;
$seed$;

select pg_temp.seed();

select throws_ok(
  $$ insert into public.member_notes (workspace_id, from_member_id, to_member_id, body)
     values (current_setting('deskilo.p.a')::uuid, current_setting('deskilo.p.ma')::uuid,
             current_setting('deskilo.p.mb')::uuid, 'to a stranger') $$,
  '23503', null, 'a note in A cannot be addressed to a member of B');

select lives_ok(
  $$ insert into public.member_notes (workspace_id, from_member_id, to_member_id, body)
     values (current_setting('deskilo.p.a')::uuid, current_setting('deskilo.p.ma')::uuid,
             null, 'to the admins') $$,
  'a broadcast note, with no addressee, is still allowed');

select is(
  (select count(*)::int from pg_constraint where conname like '%\_same\_workspace' and convalidated),
  40, 'forty relations are held to one workspace (22 financial + 18 others)');

alter table public.member_notes drop constraint member_notes_to_member_id_same_workspace;
select lives_ok(
  $$ insert into public.member_notes (workspace_id, from_member_id, to_member_id, body)
     values (current_setting('deskilo.p.a')::uuid, current_setting('deskilo.p.ma')::uuid,
             current_setting('deskilo.p.mb')::uuid, 'to a stranger') $$,
  'without the constraint the same note goes through — the refusal is the constraint');

select * from finish();
rollback;
