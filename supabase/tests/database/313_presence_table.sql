-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0616 (#3123) — the presence heartbeat writes public.presence, which is
-- not published, and leaves the published profiles row alone; the
-- projections still answer last_seen_at.
--
-- Real JWT claims and `set local role authenticated` for the heartbeat:
-- touch_last_seen reads auth.uid(). All rows are seeded first.
begin;
select plan(6);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000003123';
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'presence@deskilo.test', '', now(), now(), now());
  perform set_config('t.u', u::text, true);
  perform set_config('t.profile_before',
    (select modified_datetime::text from public.profiles where id = u), true);
end;
$seed$;

select pg_temp.seed();

select has_column('public', 'profiles', 'last_seen_at',
  'profiles keeps the column, unwritten, for apps that still read it');
select is((select count(*)::int from pg_publication_tables
            where pubname = 'supabase_realtime' and tablename = 'presence'), 0,
  'presence is not published');

select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.touch_last_seen();
reset role;

select is((select count(*)::int from public.presence
            where user_id = current_setting('t.u')::uuid), 1,
  'the heartbeat writes the presence row');
select is((select modified_datetime::text from public.profiles
            where id = current_setting('t.u')::uuid),
  current_setting('t.profile_before'),
  'and leaves the profiles row untouched');
select isnt(public.member_profile_projection(current_setting('t.u')::uuid,
              array['community']) -> 'community' ->> 'last_seen_at', null,
  'the member projection still answers last_seen_at');
select isnt(public.account_projection(current_setting('t.u')::uuid,
              array['presence']) -> 'presence' ->> 'last_seen_at', null,
  'and so does the account projection');

select * from finish();
rollback;
