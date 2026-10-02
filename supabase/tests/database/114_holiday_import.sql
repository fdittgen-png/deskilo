-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2051 — the owner's open-data list, judged by the #1274 rules.
--
-- import_closure_days takes dates and names the app fetched from the
-- open-data source. Whatever the list says, only an owner may write, only
-- with holidayImport effective, never into an invoiced month, never twice
-- on one date — and the preview writes nothing.
begin;
select plan(10);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000002f1';
  u_member uuid := '00000000-0000-4000-8000-0000000002f2';
  ws uuid; m_owner uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'import-owner@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'import-member@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Import', 'DE', 'EUR', 'Europe/Berlin', u_owner) returning id into ws;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb)
                         || '{"publicHolidays": true, "holidayImport": false}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false);

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, period)
  values (ws, m_owner, m_owner, 'IMP-1', 'June', '[]'::jsonb, 5000, 'EUR',
          'Owner', 'Import', 'Owner', 'sig', '2026-06');
  insert into public.closure_days (workspace_id, day, reason)
  values (ws, date '2026-12-25', 'already');

  perform set_config('deskilo.imp.ws', ws::text, false);
  perform set_config('deskilo.imp.owner', u_owner::text, false);
  perform set_config('deskilo.imp.member', u_member::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.imp.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

-- Corpus Christi lies in the invoiced June; Christmas is already there;
-- New Year is sent twice under two names.
create or replace function pg_temp.call(p_apply boolean) returns jsonb
language sql as $$
  select public.import_closure_days(
    current_setting('deskilo.imp.ws')::uuid,
    '[{"day": "2026-01-01", "name": "Neujahr"},
      {"day": "2026-01-01", "name": "Neujahr (again)"},
      {"day": "2026-06-04", "name": "Fronleichnam"},
      {"day": "2026-12-25", "name": "Erster Weihnachtstag"}]'::jsonb,
    p_apply);
$$;

create or replace function pg_temp.closures() returns int language sql as $$
  select count(*)::int from public.closure_days
   where workspace_id = current_setting('deskilo.imp.ws')::uuid;
$$;

select pg_temp.seed();

-- --------------------------------------------------------- the gates
select pg_temp.act_as('member');
select throws_matching($$ select pg_temp.call(true) $$, 'only an owner',
  'a member may not import closure days');

select pg_temp.act_as('owner');
select throws_matching($$ select pg_temp.call(false) $$, 'not enabled',
  'an owner may not import while holidayImport is off');

update public.workspaces set feature_flags = feature_flags || '{"holidayImport": true}'
 where id = current_setting('deskilo.imp.ws')::uuid;

select throws_matching(
  format($$ select public.import_closure_days(%L, '{"day": "2026-01-01"}'::jsonb) $$,
         current_setting('deskilo.imp.ws')),
  'list of at most 400 days',
  'a payload that is not a list is refused');

-- ------------------------------------------------------- the preview
select is(jsonb_array_length(pg_temp.call(false) -> 'days'), 3,
  'the preview lists one entry per date');
select is(pg_temp.call(false) -> 'locked_months', '["2026-06"]'::jsonb,
  'the invoiced month is named');
select is(pg_temp.closures(), 1, 'the preview writes nothing');

-- --------------------------------------------------------- the apply
select is((pg_temp.call(true) ->> 'created')::int, 1,
  'only New Year is created: June is invoiced, Christmas already exists');
select is((select reason from public.closure_days
            where workspace_id = current_setting('deskilo.imp.ws')::uuid
              and day = date '2026-01-01'),
  'Neujahr', 'the closure day carries the official name, the first one sent');
select is((select count(*)::int from public.closure_days
            where workspace_id = current_setting('deskilo.imp.ws')::uuid
              and day = date '2026-06-04'),
  0, 'nothing was written into the invoiced month');
select is((pg_temp.call(true) ->> 'created')::int, 0,
  're-importing the same list creates nothing');

select * from finish();
rollback;
