-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0374: favourites and 0-5 star ratings on bookable places.
begin;
select plan(12);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000295a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fb-own@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000295a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fb-m2@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000295a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fb-m3@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');

select pg_temp.act_as('00000000-0000-4000-8000-0000000295a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('FB', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select set_config('t.b', public.create_workspace('FB other', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.b')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000000295a2');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000000295a3');
select public.finalize_identity_binding();
reset role;
update public.workspaces set role_permissions = '{"member":["makeReservations"]}'::jsonb
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status) values
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000295a2', 'active'),
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000295a3', 'active');
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
select set_config('t.other', (select id::text from public.seats where workspace_id = current_setting('t.b')::uuid order by name limit 1), true);

select pg_temp.act_as('00000000-0000-4000-8000-0000000295a2');
select set_config('t.f1', public.set_favorite(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, true)::text, true);
select set_config('t.mine', public.my_favorites(current_setting('t.a')::uuid)::text, true);
select set_config('t.r1', public.set_rating(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, 4)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000295a3');
select set_config('t.r2', public.set_rating(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, 2)::text, true);
select set_config('t.seen', (select count(*) from public.resource_favorites)::text, true);
select set_config('t.zero', public.set_rating(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, 0)::text, true);
select set_config('t.m3fav', public.my_favorites(current_setting('t.a')::uuid)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000295a2');
select set_config('t.f0', public.set_favorite(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, false)::text, true);
select set_config('t.cleared', public.set_rating(current_setting('t.a')::uuid, 'seat', current_setting('t.seat')::uuid, null)::text, true);
reset role;

select is(current_setting('t.f1')::jsonb->>'favorite', 'true', 'a member marks a seat as a favourite');
select is(jsonb_array_length(current_setting('t.mine')::jsonb), 1, 'and reads it back');
select ok(current_setting('t.mine')::jsonb->0->>'label' <> '', 'with the label the other tools use');
select is((current_setting('t.r2')::jsonb->>'average')::numeric, 3.00, 'the average is over everybody who rated');
select is((current_setting('t.r2')::jsonb->>'count')::int, 2, 'with how many gave one');
select is((current_setting('t.r1')::jsonb->>'mine')::int, 4, 'and the member sees their own');
select is((current_setting('t.zero')::jsonb->>'mine')::int, 0, 'zero stars is a rating');
select is(current_setting('t.seen'), '0', 'another member sees none of the first one''s favourites');
select is(jsonb_array_length(current_setting('t.m3fav')::jsonb), 0, 'nor through the favourites list');
select is(current_setting('t.f0')::jsonb->>'favorite', 'false', 'taking a favourite back removes it');
select is(current_setting('t.cleared')::jsonb->>'mine', null, 'and a null rating takes one back');

select pg_temp.act_as('00000000-0000-4000-8000-0000000295a2');
select throws_ok(format($q$select public.set_rating(%L::uuid, 'seat', %L::uuid, 6)$q$, current_setting('t.a'), current_setting('t.seat')),
  null, 'a rating is from 0 to 5 stars', 'six stars is refused');
reset role;

select * from finish();
rollback;
