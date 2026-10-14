-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2477 / 0427: the tax reference store. Everyone signed in reads it; only the
-- platform owner writes, and only through set_tax_reference, which validates
-- the value's shape, refuses an unsourced or overlapping version, closes the
-- version in force on the new one's first day (never an edit) and writes the
-- append-only authority audit. The seed reproduces the Dart constants it
-- replaces. Seeds run as postgres, callers as `authenticated`.
begin;
select plan(23);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002477a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2477@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002477a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2477@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000002477a1');

-- ── the seed is there, and everyone signed in reads it ─────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002477a2');
select is((select count(*)::int from public.tax_reference where domain = 'eu_member' and key = 'member'), 27,
          'a member reads the 27 EU member states of the seed');
select is((select value ->> 'percent' from public.tax_reference('rate', 'DE', '2026-06-01') where key = 'standard'),
          '19.0', 'Germany''s standard rate in the seed is 19');
select is((select count(*)::int from public.tax_reference('rate', 'DE', '2026-06-01')), 2,
          'Germany has its two rates in force');

-- ── a non-owner writes nothing ─────────────────────────────────────────
select throws_ok($$select public.set_tax_reference('rate', 'FR', 'standard',
  '{"label":"x","percent":1,"group":"standard","category":"S"}', 'src', true, '2027-01-01')$$,
  'P0001', 'platform owners only', 'a member cannot write a version');
select throws_ok($$insert into public.tax_reference (domain, country, key, valid_from, value, source)
  values ('eu_member', 'GB', 'member', '2030-01-01', '{}', 'x')$$,
  '42501', null, 'a member cannot insert into the table either');
select throws_ok($$select public.tax_reference_valid('rate', '{}')$$, '42501', null,
  'the shape check is not callable by clients');

-- ── the owner writes; a second version closes the first ────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002477a1');
select is((public.set_tax_reference('rate', 'FR', 'standard',
  '{"label":"Standard 21 %","percent":21,"group":"standard","category":"S","position":0}',
  'Finance act 2027', false, '2027-01-01')) ->> 'valid_from', '2027-01-01', 'the owner writes a new version');
select is((select valid_to::text from public.tax_reference_history('rate', 'FR', 'standard') order by valid_from limit 1),
          '2027-01-01', 'the version in force was closed on the new one''s first day');
select is((select count(*)::int from public.tax_reference_history('rate', 'FR', 'standard')), 2, 'the history lists both versions');
select is((select valid_from::text from public.tax_reference_history('rate', 'FR', 'standard') limit 1), '2027-01-01',
          'newest first');
select is((select value ->> 'percent' from public.tax_reference('rate', 'FR', '2026-06-01') where key = 'standard'), '20.0',
          'before the change the old rate is in force');
select is((select value ->> 'percent' from public.tax_reference('rate', 'FR', '2027-06-01') where key = 'standard'), '21',
          'after the change the new rate is in force');
select is((select value ->> 'percent' from public.tax_reference('rate', 'FR', '2027-01-01') where key = 'standard'), '21',
          'the boundary day belongs to the new version');

-- ── refusals ───────────────────────────────────────────────────────────
select throws_ok($$select public.set_tax_reference('rate', 'FR', 'standard',
  '{"label":"x","percent":1,"group":"standard","category":"S"}', 'src', true, '2026-06-01')$$,
  'P0001', null, 'a version cannot start before the current one began (no overlap)');
select throws_ok($$select public.set_tax_reference('rate', 'FR', 'reduced_x',
  '{"label":"x","percent":1,"group":"standard","category":"S"}', '  ', true, '2027-01-01')$$,
  'P0001', null, 'an unsourced version is refused');
select throws_ok($$select public.set_tax_reference('rate', 'FR', 'reduced_x',
  '{"label":"x"}', 'src', true, '2027-01-01')$$, 'P0001', null, 'a value of the wrong shape is refused');
select throws_ok($$select public.set_tax_reference('vat_id_pattern', 'FR', 'vat_id', '{"pattern":"("}', 'src', true, '2027-01-01')$$,
  'P0001', null, 'a pattern the database cannot compile is refused');
select throws_ok($$select public.set_tax_reference('mandate', 'FR', 'x', '{}', 'src', true, '2027-01-01')$$,
  'P0001', null, 'a domain without a shape cannot be written yet');

-- ── a delegated assistant token is not the owner ───────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002477a1', 'assistant-2477');
select throws_ok($$select public.set_tax_reference('eu_member', 'GB', 'member', '{}', 'src', true, '2030-01-01')$$,
  'P0001', 'platform owners only', 'the owner''s delegated token cannot write');

-- ── anon reads nothing ─────────────────────────────────────────────────
reset role;
set local role anon;
select throws_ok($$select * from public.tax_reference('rate', 'DE', null)$$, '42501', null, 'anon cannot call the read function');

-- ── the audit and the seed, read back as postgres ──────────────────────
reset role;
select is((select count(*)::int from public.database_authority_audit where action = 'tax_reference_set'), 1,
          'one successful write left one audit row');
select is((select count(*)::int from public.tax_reference where domain = 'rate' and country = 'FR' and key = 'standard'), 2,
          'nothing was edited: two rows for the value');
select ok(exists (select 1 from information_schema.columns where table_name = 'tax_reference' and column_name = 'modified_datetime'),
          'the table carries the system columns');

select * from finish();
rollback;
