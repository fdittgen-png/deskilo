-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2565 / 0438: a planned tax_reference version is confirmed when the law
-- passes (the one permitted update: nothing but the flag, and the source
-- completed) or withdrawn when it does not come into force (the future,
-- unconfirmed version is deleted and its predecessor is open again). A
-- version in force or confirmed is history; a member and a delegated token
-- can do neither; both acts are audited.
begin;
select plan(17);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002565a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2565@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002565a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2565@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000002565a1');

-- The scenario: a value in force since 2024 and a planned change for 2028.
select pg_temp.act_as('00000000-0000-4000-8000-0000002565a1');
select public.set_tax_reference('rate', 'CH', 't2565',
  '{"label":"Standard 8.1 %","percent":8.1,"group":"standard","category":"S","position":0}',
  'Federal act 2024', true, '2024-01-01');
select set_config('t2565.planned', (public.set_tax_reference('rate', 'CH', 't2565',
  '{"label":"Standard 8.5 %","percent":8.5,"group":"standard","category":"S","position":0}',
  'Parliament proposal', false, '2028-01-01') ->> 'id'), true);
select set_config('t2565.inforce', (select id::text from public.tax_reference_history('rate', 'CH', 't2565')
  where valid_from = '2024-01-01'), true);

select is((select valid_to::text from public.tax_reference_history('rate', 'CH', 't2565') where valid_from = '2024-01-01'),
  '2028-01-01', 'the planned version closed the one in force on its first day');

-- ── nobody else, and nothing in force or confirmed ─────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002565a2');
select throws_ok($$select public.confirm_tax_reference(current_setting('t2565.planned')::uuid, 'x')$$,
  'P0001', 'platform owners only', 'a member cannot confirm');
select throws_ok($$select public.withdraw_tax_reference(current_setting('t2565.planned')::uuid, 'x')$$,
  'P0001', 'platform owners only', 'a member cannot withdraw');
select pg_temp.act_as('00000000-0000-4000-8000-0000002565a1', 'assistant-2565');
select throws_ok($$select public.withdraw_tax_reference(current_setting('t2565.planned')::uuid, 'x')$$,
  'P0001', 'platform owners only', 'the owner''s delegated token cannot withdraw');
select pg_temp.act_as('00000000-0000-4000-8000-0000002565a1');
select throws_ok($$select public.withdraw_tax_reference(current_setting('t2565.inforce')::uuid, 'x')$$,
  'P0001', 'a confirmed version is history and is only superseded', 'a confirmed version is not withdrawn');
select throws_ok($$select public.withdraw_tax_reference(current_setting('t2565.planned')::uuid, '  ')$$,
  'P0001', 'a reason is required', 'a withdrawal needs a reason');
select throws_ok($$select public.confirm_tax_reference(current_setting('t2565.inforce')::uuid, null)$$,
  'P0001', 'the version is already confirmed', 'a confirmed version is not confirmed twice');

-- ── withdraw: the planned version is gone, the predecessor is open ─────
select lives_ok($$select public.withdraw_tax_reference(current_setting('t2565.planned')::uuid, 'The vote failed')$$,
  'the owner withdraws a future unconfirmed version');
select is((select count(*)::int from public.tax_reference_history('rate', 'CH', 't2565')), 1, 'it is gone');
select ok((select valid_to from public.tax_reference_history('rate', 'CH', 't2565')) is null,
  'and the version in force is open again');

-- ── confirm: re-add and confirm; only the flag and the source move ─────
select set_config('t2565.planned', (public.set_tax_reference('rate', 'CH', 't2565',
  '{"label":"Standard 8.5 %","percent":8.5,"group":"standard","category":"S","position":0}',
  'Parliament proposal', false, '2028-01-01') ->> 'id'), true);
select is((public.confirm_tax_reference(current_setting('t2565.planned')::uuid, 'Federal Gazette 2027') ->> 'confirmed'),
  'true', 'the owner confirms the planned version');
select is((select source from public.tax_reference_history('rate', 'CH', 't2565') where valid_from = '2028-01-01'),
  'Parliament proposal | confirmed: Federal Gazette 2027', 'the source is completed with the act');
select is((select value ->> 'percent' from public.tax_reference_history('rate', 'CH', 't2565') where valid_from = '2028-01-01'),
  '8.5', 'the value is untouched');
select throws_ok($$select public.withdraw_tax_reference(current_setting('t2565.planned')::uuid, 'x')$$,
  'P0001', 'a confirmed version is history and is only superseded', 'a confirmed planned version is no longer withdrawable');

-- ── the audit and the grants ───────────────────────────────────────────
reset role;
select is((select count(*)::int from public.database_authority_audit
            where action = 'tax_reference_withdraw' and detail -> 'version' ->> 'valid_from' = '2028-01-01'
              and detail -> 'version' -> 'value' ->> 'percent' = '8.5'), 1,
  'the withdrawal is audited with the withdrawn value');
select is((select count(*)::int from public.database_authority_audit where action = 'tax_reference_confirm'), 1,
  'the confirmation is audited');
select ok(not has_function_privilege('anon', 'public.confirm_tax_reference(uuid, text)', 'execute')
      and not has_function_privilege('anon', 'public.withdraw_tax_reference(uuid, text)', 'execute'),
  'anon can call neither');

select * from finish();
rollback;
