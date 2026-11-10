-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3552 (0711): a service carries a description, a duration, a category, a
-- public flag and an order. The checks refuse a duration outside 5..1440, a
-- blank or too long category and an overlong description; is_public is
-- writable only by whoever may edit services (manageServices); another tenant
-- sees nothing. Rolled back.
begin;
select plan(11);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The error updating the service with [p_set] (a SET clause), or null.
create function pg_temp.update_error(p_set text) returns text language plpgsql as $$
begin
  execute format('update public.services set %s where id = %L', p_set, '00000000-0000-4000-8000-0000003552c1');
  return null;
exception when others then return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000003552a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-3552@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000003552a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-3552@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000003552a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-3552@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by) values
 ('00000000-0000-4000-8000-0000003552b1', 'Services 3552 A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003552a1'),
 ('00000000-0000-4000-8000-0000003552b2', 'Services 3552 B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003552a3');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values
 ('00000000-0000-4000-8000-0000003552b1', '00000000-0000-4000-8000-0000003552a1', true, true, '2026-01-01'),
 ('00000000-0000-4000-8000-0000003552b1', '00000000-0000-4000-8000-0000003552a2', false, false, '2026-01-01'),
 ('00000000-0000-4000-8000-0000003552b2', '00000000-0000-4000-8000-0000003552a3', true, true, '2026-01-01');
insert into public.services (id, workspace_id, name, price_cents) values
 ('00000000-0000-4000-8000-0000003552c1', '00000000-0000-4000-8000-0000003552b1', 'Massage', 6000);

select is((select is_public from public.services where id = '00000000-0000-4000-8000-0000003552c1'),
          false, 'a service is not public until the business says so');

select pg_temp.act_as('00000000-0000-4000-8000-0000003552a1');
select is(pg_temp.update_error($$description = 'Sixty minutes, oils included', duration_minutes = 60,
                                 category = 'Massage', is_public = true, sort_order = 1$$),
          null, 'the owner writes the details');
select is((select duration_minutes || '|' || category || '|' || is_public from public.services
            where id = '00000000-0000-4000-8000-0000003552c1'),
          '60|Massage|true', 'the details are stored');
select alike(pg_temp.update_error('duration_minutes = 3'), '%services_duration_range%', 'a duration under 5 minutes is refused');
select alike(pg_temp.update_error('duration_minutes = 1441'), '%services_duration_range%', 'a duration over a day is refused');
select is(pg_temp.update_error('duration_minutes = null'), null, 'no duration: not time-based');
select alike(pg_temp.update_error($$category = '   '$$), '%services_category_shape%', 'a blank category is refused');
select alike(pg_temp.update_error(format('category = %L', repeat('x', 41))), '%services_category_shape%',
             'a category over 40 characters is refused');
select alike(pg_temp.update_error(format('description = %L', repeat('x', 2001))), '%services_description_length%',
             'an overlong description is refused');

select pg_temp.act_as('00000000-0000-4000-8000-0000003552a2');
select pg_temp.update_error('is_public = false');
reset role;
select is((select is_public from public.services where id = '00000000-0000-4000-8000-0000003552c1'),
          true, 'a member without manageServices cannot change is_public');

select pg_temp.act_as('00000000-0000-4000-8000-0000003552a3');
select is((select count(*)::int from public.services where workspace_id = '00000000-0000-4000-8000-0000003552b1'),
          0, 'another tenant sees none of its services');

select * from finish();
rollback;
