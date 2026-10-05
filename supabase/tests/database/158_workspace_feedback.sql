-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0376: a workspace can be favourited and rated by anybody who can see it;
-- services join the places a member can favourite.
begin;
select plan(8);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000297a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wf-own@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000297a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wf-out@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');

select pg_temp.act_as('00000000-0000-4000-8000-0000000297a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('WF', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000297a2');
select public.finalize_identity_binding();
select set_config('t.unlisted', (select public.workspace_feedback_of(array[current_setting('t.a')::uuid]))::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000297a1');
select set_config('t.f1', public.set_workspace_favorite(current_setting('t.a')::uuid, true)::text, true);
select set_config('t.r1', public.set_workspace_rating(current_setting('t.a')::uuid, 4)::text, true);
select public.set_workspace_visibility(current_setting('t.a')::uuid, 'public');
select pg_temp.act_as('00000000-0000-4000-8000-0000000297a2');
select set_config('t.r2', public.set_workspace_rating(current_setting('t.a')::uuid, 2)::text, true);
select set_config('t.seen', (select count(*) from public.workspace_ratings)::text, true);
select set_config('t.zero', public.set_workspace_rating(current_setting('t.a')::uuid, 0)::text, true);
select set_config('t.cleared', public.set_workspace_rating(current_setting('t.a')::uuid, null)::text, true);
select set_config('t.batch', public.workspace_feedback_of(array[current_setting('t.a')::uuid])::text, true);
reset role;

select is(current_setting('t.unlisted'), '{}', 'an unlisted workspace is invisible to an outsider');
select is(current_setting('t.f1')::jsonb->>'favorite', 'true', 'a member favourites their workspace');
select is((current_setting('t.r2')::jsonb->>'average')::numeric, 3.00, 'the average is over everybody who rated it');
select is((current_setting('t.r2')::jsonb->>'count')::int, 2, 'with how many gave one');
select is(current_setting('t.seen'), '1', 'an outsider reads only their own rating row');
select is((current_setting('t.zero')::jsonb->>'mine')::int, 0, 'zero stars is a rating');
select is(current_setting('t.cleared')::jsonb->>'mine', null, 'and a null rating takes it back');
select is(current_setting('t.batch')::jsonb->current_setting('t.a')->>'favorite', 'false', 'a screenful of listed workspaces answers per workspace');

select * from finish();
rollback;
