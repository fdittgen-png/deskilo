-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4168 (0836): a recorded configuration stage is never changed, and never
-- deleted while its business exists, but it goes with its business: deleting
-- a business that has confirmed a kind deletes its recorded stages with it.
begin;
select plan(5);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000048701', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ev4168@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('00000000-0000-4000-8000-000000048710', 'Events A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000048701'),
       ('00000000-0000-4000-8000-000000048711', 'Events B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000048701');
insert into public.configuration_choice_events (workspace_id, request_id, stage, outcome, actor_user_id, source)
values ('00000000-0000-4000-8000-000000048710', '00000000-0000-4000-8000-000000048720', 'kind', 'applied', '00000000-0000-4000-8000-000000048701', '{}'),
       ('00000000-0000-4000-8000-000000048710', '00000000-0000-4000-8000-000000048720', 'flags', 'applied', '00000000-0000-4000-8000-000000048701', '{}'),
       ('00000000-0000-4000-8000-000000048711', '00000000-0000-4000-8000-000000048721', 'kind', 'applied', '00000000-0000-4000-8000-000000048701', '{}');

select throws_ok($$update public.configuration_choice_events set outcome = 'refused'$$, 'DKK02',
  'a recorded stage is never changed');
select throws_ok($$delete from public.configuration_choice_events where workspace_id = '00000000-0000-4000-8000-000000048710'$$, 'DKK02',
  'nor deleted while its business exists');
select lives_ok($$delete from public.workspaces where id = '00000000-0000-4000-8000-000000048710'$$,
  'a business that confirmed a kind can be deleted');
select is((select count(*)::int from public.configuration_choice_events where workspace_id = '00000000-0000-4000-8000-000000048710'), 0,
  'its recorded stages went with it');
select is((select count(*)::int from public.configuration_choice_events where workspace_id = '00000000-0000-4000-8000-000000048711'), 1,
  'another business keeps its own');

select * from finish();
rollback;
