-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4498 (0986): a save keeps what it did not change on the server. A question with help texts in two languages: a save that gives only
-- the labels keeps both help texts and its grouping, order, validation rules, visibility, requiredness and active state; a new question
-- takes the defaults. A choice key is immutable: a single-choice answer on choice `b` is not left pointing at a choice that is no longer
-- there: removing or renaming `b` is refused (DKW01), retiring it is accepted and the answer stays readable. Rolled back.
begin;
select plan(12);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
-- a save of the question `pet`: the labels, then what else is given
create or replace function pg_temp.save_pet(p_labels text, p_rest text default '') returns text language sql as $f$
  select pg_temp.run_as(format('select public.save_workspace_field(%L, ''pet'', ''single_choice'', %L::jsonb%s)::text', pg_temp.u(101), p_labels, p_rest))
$f$;
create or replace function pg_temp.opts(p_options text) returns text language sql as $f$
  select pg_temp.run_as(format('select public.set_workspace_field_options((select id from public.workspace_field_definitions where workspace_id = %L and key = ''pet''), %L::jsonb)::text', pg_temp.u(101), p_options))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'savekeeps-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions, default_locale) values
  (pg_temp.u(101), 'Save keeps', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"customFields": true}', '{}', 'en');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');

-- a question with everything set, and two choices
select isnt(pg_temp.save_pet('{"en": "Pet", "fr": "Animal"}',
  ', p_required => true, p_personal_data => false, p_visibility => ''managers'', p_group_key => ''pets'', p_sort_order => 7, p_validation => ''{"max_length": 10}'', p_active => true, p_options => ''[{"key": "a", "labels": {"en": "A"}}, {"key": "b", "labels": {"en": "B"}}]''::jsonb'),
  null, 'the owner defines a question with its attributes and its choices');
update public.workspace_field_labels set help_text = 'Which pet?' where locale = 'en' and definition_id = (select id from public.workspace_field_definitions where workspace_id = pg_temp.u(101) and key = 'pet');
update public.workspace_field_labels set help_text = 'Quel animal ?' where locale = 'fr' and definition_id = (select id from public.workspace_field_definitions where workspace_id = pg_temp.u(101) and key = 'pet');

-- a save of the labels alone
select isnt(pg_temp.save_pet('{"en": "The pet", "fr": "L''animal"}'), null, 'a save that gives only the labels is accepted');
select is((select string_agg(locale || '=' || label || '/' || help_text, ' ' order by locale) from public.workspace_field_labels
            where definition_id = (select id from public.workspace_field_definitions where workspace_id = pg_temp.u(101) and key = 'pet')),
  'en=The pet/Which pet? fr=L''animal/Quel animal ?', 'the labels changed and both help texts are kept');
select is((select required::text || ' ' || personal_data::text || ' ' || visibility || ' ' || group_key || ' ' || sort_order::text || ' ' || validation::text || ' ' || active::text
             from public.workspace_field_definitions where workspace_id = pg_temp.u(101) and key = 'pet'),
  'true false managers pets 7 {"max_length": 10} true', 'and so are the requiredness, the visibility, the grouping, the order, the rules and the active state');
select is((select count(*)::int from public.workspace_field_options o join public.workspace_field_definitions d on d.id = o.definition_id where d.key = 'pet' and d.workspace_id = pg_temp.u(101)),
  2, 'a save that gives no choices leaves the choices alone');

-- a new question takes the defaults
select isnt(pg_temp.run_as(format('select public.save_workspace_field(%L, ''nick'', ''text'', ''{"en": "Nickname"}''::jsonb)::text', pg_temp.u(101))), null, 'a new question is saved with its labels alone');
select is((select required::text || ' ' || personal_data::text || ' ' || visibility || ' ' || group_key || ' ' || sort_order::text || ' ' || contexts::text || ' ' || active::text
             from public.workspace_field_definitions where workspace_id = pg_temp.u(101) and key = 'nick'),
  'false true self general 0 {profile} true', 'and takes the defaults of a new question');

-- a single-choice answer on b
insert into public.workspace_field_values (workspace_id, member_id, definition_id, text_value)
select pg_temp.u(101), pg_temp.u(201), d.id, 'b' from public.workspace_field_definitions d where d.workspace_id = pg_temp.u(101) and d.key = 'pet';
select is(pg_temp.opts('[{"key": "a", "labels": {"en": "A"}}]'), 'ERR DKW01', 'removing the choice an answer holds is refused');
select is(pg_temp.opts('[{"key": "a", "labels": {"en": "A"}}, {"key": "c", "labels": {"en": "B"}}]'), 'ERR DKW01', 'renaming it (a removal and an addition) is refused');
select isnt(pg_temp.opts('[{"key": "a", "labels": {"en": "A"}}, {"key": "b", "active": false, "labels": {"en": "B"}}]'), 'ERR DKW01', 'retiring it is accepted');
select is((select text_value from public.workspace_field_values v join public.workspace_field_definitions d on d.id = v.definition_id where d.key = 'pet' and d.workspace_id = pg_temp.u(101)), 'b',
  'and the answer still reads b');
select is((select o.active::text from public.workspace_field_options o join public.workspace_field_definitions d on d.id = o.definition_id where d.key = 'pet' and d.workspace_id = pg_temp.u(101) and o.key = 'b'), 'false',
  'the retired choice is kept, no longer offered');

select * from finish();
rollback;
