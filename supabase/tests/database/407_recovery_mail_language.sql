-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3812 (0743, part of #3657): the recovery e-mail reads in the account's
-- language, because the server writes it into the account's Auth metadata
-- whenever it changes: the interface language first, the document language
-- otherwise, no key when neither is set; other metadata is left as it was.
-- Rolled back.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare u uuid := '00000000-0000-4000-8000-000000003812';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at, raw_user_meta_data)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'recovery-language@deskilo.test', '', now(), now(), now(), '{"display_hint": "kept"}'::jsonb);
  perform set_config('t.u', u::text, false);
end;
$seed$;
select pg_temp.seed();

-- Sets the member's own preferences, as the app does.
create or replace function pg_temp.prefer(p_patch jsonb) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.set_personal_preferences(p_patch);
  reset role;
  perform set_config('request.jwt.claims', '', true);
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.meta() returns jsonb language sql as $f$
  select raw_user_meta_data from auth.users where id = current_setting('t.u')::uuid
$f$;

select ok(not (pg_temp.meta() ? 'locale'), 'an account with no language has no locale: the default language reads');

select pg_temp.prefer('{"ui_locale": "fr"}');
select is(pg_temp.meta() ->> 'locale', 'fr', 'the interface language is written to the account');

select pg_temp.prefer('{"ui_locale": "de"}');
select is(pg_temp.meta() ->> 'locale', 'de', 'and follows when it changes');

select pg_temp.prefer('{"ui_locale": "", "preferred_locale": "it"}');
select is(pg_temp.meta() ->> 'locale', 'it', 'without one, the document language is written');

select pg_temp.prefer('{"preferred_locale": ""}');
select ok(not (pg_temp.meta() ? 'locale'), 'with neither, the key goes: the default language reads');

select is(pg_temp.meta() ->> 'display_hint', 'kept', 'the account''s other metadata is left as it was');

select is((select count(*)::int from information_schema.role_routine_grants
            where routine_schema = 'public'
              and routine_name in ('sync_auth_locale', 'account_auth_locale')
              and grantee in ('anon', 'authenticated', 'PUBLIC')), 0,
  'no client calls the write or the read itself');

select * from finish();
rollback;
