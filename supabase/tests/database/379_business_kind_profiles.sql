-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3550 (0709): a kind proposes features through its profile. Coworking
-- proposes nothing; the four other kinds switch the places off. A profile
-- names registered flags only, each with a boolean: a typo or a non-boolean
-- is refused when written. Every key of every seeded profile is registered.
-- Rolled back.
begin;
select plan(7);

-- The error writing [p_profile] onto kind [p_code], or null.
create function pg_temp.profile_error(p_code text, p_profile jsonb) returns text language plpgsql as $$
begin
  update public.business_kinds set feature_profile = p_profile where code = p_code;
  return null;
exception when others then return sqlerrm;
end;
$$;

select is((select feature_profile from public.business_kinds where code = 'coworking'),
          '{}'::jsonb, 'coworking proposes nothing: today''s defaults');
select is((select count(*)::int from public.business_kinds
            where code in ('studio', 'practice', 'salon', 'service')
              and feature_profile -> 'placeBooking' = 'false'::jsonb),
          4, 'the four other kinds switch the places off');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where not (public.feature_registry() ? key)),
          0, 'every key of every seeded profile is a registered flag');
select alike(pg_temp.profile_error('studio', '{"placeBookng": false}'),
             '%unknown feature placeBookng%', 'a typo in a profile is refused');
select alike(pg_temp.profile_error('studio', '{"placeBooking": "no"}'),
             '%needs true or false%', 'a profile value is a boolean');
select is(pg_temp.profile_error('studio', '{"placeBooking": false, "services": true}'),
          null, 'a valid profile is written');
select ok(not has_table_privilege('authenticated', 'public.business_kinds', 'update'),
          'no client edits a profile');

select * from finish();
rollback;
