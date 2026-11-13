-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3650 (0752) -- a WhatsApp number has two forms, what its owner typed and
-- the validated international one. The person's own data export carries
-- both, and the erasure of their last membership clears both. Rolled back.
begin;
select plan(4);

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000036500' || p)::uuid
$$;
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.export_as(p_user text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  v := public.export_my_data(current_setting('deskilo.ph.ws')::uuid);
  reset role;
  return v;
end $$;
create function pg_temp.erase_as(p_user text) returns text language plpgsql as $$
declare v text := '';
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  begin
    perform public.erase_my_membership(current_setting('deskilo.ph.ws')::uuid);
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  reset role;
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@phone-erasure.test', '', now(), now(), now()
  from unnest(array['a1', 'a2']) s;
-- a1 owns the space; a2 is a member whose only membership it is.
with w as (
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Phone erasure', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a1'))
  returning id)
select set_config('deskilo.ph.ws', (select id from w)::text, true);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (current_setting('deskilo.ph.ws')::uuid, pg_temp.u('a1'), true, true, 'active', '2026-01-01'),
       (current_setting('deskilo.ph.ws')::uuid, pg_temp.u('a2'), false, false, 'active', '2026-01-01');
update public.profiles set whatsapp = '+33612345678', whatsapp_typed = '06 12 34 56 78'
 where id = pg_temp.u('a2');

select is(pg_temp.export_as('a2') -> 'profile' ->> 'whatsapp_typed', '06 12 34 56 78',
  'the person''s own export carries the number as they typed it');
select is(pg_temp.export_as('a2') -> 'profile' ->> 'whatsapp', '+33612345678',
  'and its validated international form');

select is(pg_temp.erase_as('a2'), '', 'the member erases their only membership');
select is((select whatsapp || '|' || whatsapp_typed from public.profiles where id = pg_temp.u('a2')), '|',
  'erasure clears both forms of the number');

select * from finish();
rollback;
