-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2357 — input VAT on fixed assets and on scheduled expenses (0413). An
-- expense that bought a fixed asset keeps `asset` in its VAT, and the
-- return files its deductible VAT under the category `asset` (CA3 line
-- 19); an ordinary one stays `S`. A scheduled expense states its VAT once:
-- only the member who scheduled it (or an expense approver) sets it, with
-- the same 0..100 rules, and the expense an occurrence files carries it.
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-000000235731';
  u_m uuid := '00000000-0000-4000-8000-000000235732';
  ws uuid; mo uuid; sched uuid; occ uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'vatassets-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags)
  values ('Assets FR', 'FR', 'EUR', 'Europe/Paris', u_o, 'vat_registered',
          '{"vatManagement": true, "vatDeclarations": true, "inputVat": true}') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_m, false, false);

  -- Approved in September: a laptop (a fixed asset) and paper.
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id,
                             payload, status, decided_at)
  values
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 120000, "category": "equipment", "note": "",
       "vat": {"percent": 20, "deductible_pct": 100, "asset": true}}',
     'confirmed', '2026-09-10 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 1200, "category": "supplies", "note": "",
       "vat": {"percent": 20, "deductible_pct": 100}}',
     'confirmed', '2026-09-11 10:00+00');

  -- An internet subscription, validated, with one occurrence due.
  insert into public.expense_schedules (workspace_id, member_id, title, amount_cents,
                                        starts_on, unit, status, next_due)
  values (ws, mo, 'Internet', 6000, '2026-09-01', 'month', 'active', '2026-10-01')
  returning id into sched;
  insert into public.expense_occurrences (schedule_id, workspace_id, member_id, due_on, amount_cents)
  values (sched, ws, mo, '2026-09-01', 6000) returning id into occ;

  perform set_config('va.ws', ws::text, false);
  perform set_config('va.sched', sched::text, false);
  perform set_config('va.occ', occ::text, false);
  perform set_config('va.owner', u_o::text, false);
  perform set_config('va.member', u_m::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('va.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

select pg_temp.seed();
select pg_temp.act_as('owner');

-- ---------------------------------------------------------- fixed assets
select set_config('va.e1', public.submit_expense(current_setting('va.ws')::uuid, 90000,
  'equipment', 'Printer', null, '{"percent": 20, "asset": true}')::text, false);
select is(
  (select payload -> 'vat' from public.events where id = current_setting('va.e1')::uuid),
  '{"percent": 20, "deductible_pct": 100, "asset": true}'::jsonb,
  'an expense on a fixed asset says so in its VAT');
select results_eq(
  $$ select category, vat_cents from public.compute_vat_return(
       current_setting('va.ws')::uuid, '2026-09-01', '2026-09-30') where direction = 'input'
     order by category collate "C" $$,
  $$ values ('S'::text, 200::bigint), ('asset', 20000) $$,
  'the return files the laptop''s VAT as a fixed asset, the paper''s as ordinary');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('va.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  'September is prepared');
select is(
  (select count(*)::int from public.vat_declarations d,
          jsonb_array_elements(d.lines) l
    where d.workspace_id = current_setting('va.ws')::uuid
      and l ->> 'category' = 'asset' and l ->> 'direction' = 'input'),
  1, 'and the stored return keeps the fixed asset on a line of its own');

-- ---------------------------------------------------------- schedules
select pg_temp.act_as('member');
select throws_like(
  $$ select public.set_expense_schedule_vat(current_setting('va.sched')::uuid, '{"percent": 20}') $$,
  '%not allowed%', 'a member who neither scheduled it nor approves expenses sets nothing');
select pg_temp.act_as('owner');
select throws_like(
  $$ select public.set_expense_schedule_vat(current_setting('va.sched')::uuid, '{"percent": 0}') $$,
  '%between 0 and 100%', 'a schedule''s VAT follows the expense rules');
select lives_ok(
  $$ select public.set_expense_schedule_vat(current_setting('va.sched')::uuid,
       '{"percent": 20, "deductible_pct": 100}') $$,
  'the member who scheduled it states its VAT');
select is(
  (select vat from public.expense_schedules where id = current_setting('va.sched')::uuid),
  '{"percent": 20, "deductible_pct": 100}'::jsonb, 'kept on the schedule');
select lives_ok(
  $$ select public.confirm_expense_occurrence(current_setting('va.occ')::uuid, 6000) $$,
  'the occurrence is confirmed at the validated amount');
select is(
  (select e.payload -> 'vat' from public.expense_occurrences o
     join public.events e on e.id = o.event_id
    where o.id = current_setting('va.occ')::uuid),
  '{"percent": 20, "deductible_pct": 100}'::jsonb,
  'the expense it files carries the schedule''s VAT');
select lives_ok(
  $$ select public.set_expense_schedule_vat(current_setting('va.sched')::uuid, null) $$,
  'and the VAT can be cleared');

select * from finish();
rollback;
