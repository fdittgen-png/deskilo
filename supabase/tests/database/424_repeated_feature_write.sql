-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3890 (0765): a guarded feature write repeated after its answer was lost
-- answers the row and writes nothing; a read-set that moved for another
-- reason is still a conflict. Rolled back.
begin;
select plan(5);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003890' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'flags@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values (pg_temp.u(101), 'Flags', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"publicListings": false, "spaceInquiries": false}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
grant execute on all functions in schema pg_temp to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
set local role authenticated;

select ok(public.set_feature_flags(pg_temp.u(101), '{"publicListings": true}', '{"publicListings": false}')
          ->> 'publicListings' = 'true',
  'the owner switches the public page on, against what they read');
-- the answer was lost; the same call again, with the same read-set
select lives_ok($$ select public.set_feature_flags('00000000-0000-4000-8000-000038900101',
  '{"publicListings": true}', '{"publicListings": false}') $$,
  'the same write again is no conflict');
select ok(public.set_feature_flags(pg_temp.u(101), '{"publicListings": true}', '{"publicListings": false}')
          ->> 'publicListings' = 'true',
  'and answers the row as it stands');

-- another write moved what this one read
reset role;
update public.workspaces set feature_flags = feature_flags || '{"spaceInquiries": true}' where id = pg_temp.u(101);
set local role authenticated;
select throws_ok($$ select public.set_feature_flags('00000000-0000-4000-8000-000038900101',
  '{"publicListings": false}', '{"spaceInquiries": false}') $$, 'DK409', null,
  'a read-set another write moved is still a conflict');
select throws_ok($$ select public.set_feature_flags('00000000-0000-4000-8000-000038900101',
  '{"publicListings": true, "spaceInquiries": false}', '{"spaceInquiries": false}') $$, 'DK409', null,
  'and so is a write the row does not already hold in full');
reset role;

select * from finish();
rollback;
