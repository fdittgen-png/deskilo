-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0296: the readiness checklist says whether a space has been used —
-- one booking that was not cancelled or released — and never requires it.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000296a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fb@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000296a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c296', 'First booking', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.r0', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;

insert into public.levels (id, workspace_id, name)
values ('00000000-0000-4000-8000-0000000296b1', current_setting('t.ws')::uuid, 'Ground');
insert into public.reservations (workspace_id, member_id, level_id, starts_at, ends_at, status)
select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000000296b1', now() + interval '1 day', now() + interval '1 day 4 hours', 'cancelled'
  from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1;
set local role authenticated;
select set_config('t.r1', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;

update public.reservations set status = 'reserved' where workspace_id = current_setting('t.ws')::uuid;
set local role authenticated;
select set_config('t.r2', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;

create function pg_temp.fb(p text) returns jsonb language sql as $$
  select e from jsonb_array_elements(current_setting(p)::jsonb) e where e->>'section' = 'first_booking'
$$;
select is(pg_temp.fb('t.r0')->>'state', 'needs_configuration', 'a new space has not been used yet');
select is(pg_temp.fb('t.r1')->>'state', 'needs_configuration', 'a cancelled booking is not a first booking');
select is(pg_temp.fb('t.r2')->>'state', 'ready', 'one booking that stands is');
select is((pg_temp.fb('t.r0')->>'required')::boolean, false, 'and it never blocks anything');

select * from finish();
rollback;
