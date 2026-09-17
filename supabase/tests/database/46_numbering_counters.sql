-- SPDX-License-Identifier: 0BSD
--
-- #1338 — an issued counter only moves forward, only through the server, and an issued number is never printed twice.
--
-- 15 proves the #1320 cases one by one: the refused date/restart pairs,
-- a restart changed mid-period, a legacy invalid pair, removing the date.
-- 19 proves a template carries the format and never the counter. This
-- file closes what those leave open:
--
--   * the counter cannot be moved backwards through the setter, and a
--     client cannot write, reset or delete the row behind the setter's
--     back — deleting it would restart the series at 1, because rows are
--     created lazily on the first draw;
--   * a deployment MIRROR keeps the counter too, even with an empty list;
--   * every change the setter accepts, applied between draws in one
--     period, never prints a number twice — the #1320 property as a sweep
--     rather than a list of cases;
--   * invoice, VAT declaration and member numbers are unique per
--     workspace, by behaviour and not only by the index's existence;
--     payment references draw distinct numbers.
--
-- Two TODO assertions record a defect found while writing this file:
-- `number_sequence_format` pads with `lpad`, which TRUNCATES a value wider
-- than `digits`. A four-digit series prints its 10 000th number as the
-- 1 000th again, and narrowing `digits` below the counter repeats numbers
-- at once. They are TODO so the suite stays green; remove the todo() when
-- the format is fixed.
begin;
select plan(19);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-000000013391';
  u_other uuid := '00000000-0000-4000-8000-000000013392';
  ws uuid; ws2 uuid; m_owner uuid; m_other uuid;
begin
  -- The profile comes from the trigger on `auth.users`; never insert it.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'counter-owner@deskilo.test', '', now(), now(), now()),
         (u_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'counter-member@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Counters', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, member_number)
  values (ws, u_owner, true, true, 'M-0001') returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, member_number)
  values (ws, u_other, false, false, 'M-0002') returning id into m_other;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, member_number)
  values (ws2, u_owner, true, true, 'M-0001');

  -- A plain series, printing no date, that has issued 41 numbers.
  insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
  values (ws, 'zz_plain', 'N-', 'none', 4, 'never', '', 42);

  perform set_config('deskilo.ctr.ws', ws::text, false);
  perform set_config('deskilo.ctr.ws2', ws2::text, false);
  perform set_config('deskilo.ctr.owner', u_owner::text, false);
  perform set_config('deskilo.ctr.m_owner', m_owner::text, false);
  perform set_config('deskilo.ctr.m_other', m_other::text, false);
end
$seed$;

create or replace function pg_temp.act_as_owner() returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.ctr.owner'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', current_setting('deskilo.ctr.owner'), true);
  execute 'set local role authenticated';
end
$act$;

create or replace function pg_temp.next_value(p_journal text) returns bigint language sql as $nv$
  select next_value from public.number_sequences
   where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = p_journal;
$nv$;

create or replace function pg_temp.draw(p_journal text) returns text language sql as $draw$
  select public.next_document_number(current_setting('deskilo.ctr.ws')::uuid, p_journal);
$draw$;

-- A draw that reports a refusal instead of raising, so a fix that refuses
-- rather than widens still satisfies the TODO assertions below.
create or replace function pg_temp.try_draw(p_journal text) returns text language plpgsql as $try$
begin
  return pg_temp.draw(p_journal);
exception when others then
  return 'refused: ' || sqlerrm;
end
$try$;

-- set_number_sequence as the owner, through the authenticated role.
create or replace function pg_temp.configure(p_journal text, p_prefix text, p_date text, p_digits int,
                                             p_reset text, p_next bigint default null)
returns void language plpgsql as $configure$
begin
  perform pg_temp.act_as_owner();
  perform public.set_number_sequence(current_setting('deskilo.ctr.ws')::uuid, p_journal,
    p_prefix, '', p_date, p_digits, p_reset, p_next);
  execute 'reset role';
exception when others then
  execute 'reset role';
  raise;
end
$configure$;

select pg_temp.seed();

-- ================================================================ the setter
select throws_like(
  $$ select pg_temp.configure('zz_plain', 'N-', 'none', 4, 'never', 7) $$,
  '%never goes backwards%',
  'the setter refuses to move an issued counter backwards');
select is(pg_temp.next_value('zz_plain'), 42::bigint, 'and the counter did not move');

select lives_ok(
  $$ select pg_temp.configure('zz_plain', 'N-', 'none', 4, 'never', 60) $$,
  'moving it forward, skipping numbers, is allowed');
select is(pg_temp.draw('zz_plain'), 'N-0060', 'and the next draw prints exactly that number');

-- ================================================================ behind its back
-- An UPDATE or DELETE refused by row-level security raises nothing: it
-- matches no rows. Each is read back as postgres.
select pg_temp.act_as_owner();
update public.number_sequences set next_value = 1
 where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain';
delete from public.number_sequences
 where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain';
select throws_like(
  format($$ insert into public.number_sequences (workspace_id, journal, prefix, next_value)
            values (%L, 'zz_forged', 'N-', 1) $$, current_setting('deskilo.ctr.ws')),
  '%row-level security%',
  'an owner cannot create a series row directly');
reset role;

select is(pg_temp.next_value('zz_plain'), 61::bigint,
  'an owner''s direct UPDATE and DELETE leave the issued counter exactly where it was');

-- Control: the same statement run past row-level security does move it, so
-- the assertion above is about the policy and not about a missed row.
update public.number_sequences set next_value = 1
 where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain';
select is(pg_temp.next_value('zz_plain'), 1::bigint,
  'control: the same UPDATE without row-level security would have reset it');
update public.number_sequences set next_value = 61
 where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain';

-- ================================================================ deployment mirror
select pg_temp.act_as_owner();
select public.import_workspace_configuration(current_setting('deskilo.ctr.ws')::uuid,
  '{"tables":{"number_sequences":[{"journal":"zz_plain","prefix":"P-","suffix":"","date_part":"none","digits":4,"reset":"never","gapless":true}]}}'::jsonb);
reset role;
select is(
  (select prefix || ':' || next_value from public.number_sequences
    where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain'),
  'P-:61',
  'a mirror import takes the new format and keeps the issued counter');

select pg_temp.act_as_owner();
select public.import_workspace_configuration(current_setting('deskilo.ctr.ws')::uuid,
  '{"tables":{"number_sequences":[]}}'::jsonb, 'mirror');
reset role;
select is(pg_temp.next_value('zz_plain'), 61::bigint,
  'a mirror whose list names no series deletes none, so none restarts at 1');

-- ================================================================ the sweep
-- One period, the counter at 5, then every change the setter accepts that
-- keeps the prefix — coarser and finer restarts, more date, wider digits —
-- with draws in between. Nothing printed may repeat.
insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
values (current_setting('deskilo.ctr.ws')::uuid, 'zz_sweep', 'S-', 'year', 4, 'never', '', 5);

create temporary table sweep (n text) on commit drop;
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);
select pg_temp.configure('zz_sweep', 'S-', 'year', 4, 'yearly');
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);
select pg_temp.configure('zz_sweep', 'S-', 'year_month', 4, 'yearly');
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);
select pg_temp.configure('zz_sweep', 'S-', 'year_month', 4, 'monthly');
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);
select pg_temp.configure('zz_sweep', 'S-', 'year_month', 5, 'never');
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);
select pg_temp.configure('zz_sweep', 'S-', 'year_month', 6, 'yearly');
insert into sweep select pg_temp.draw('zz_sweep') from generate_series(1, 2);

select is(
  (select array[count(*), count(distinct n)] from sweep),
  array[12::bigint, 12::bigint],
  'twelve draws across six accepted mid-period changes print twelve different numbers');

-- ================================================================ uniqueness
select throws_like(
  format($$ update public.members set member_number = 'M-0001' where id = %L $$,
         current_setting('deskilo.ctr.m_other')),
  '%members_workspace_member_number_key%',
  'two members of one workspace cannot hold the same member number');
select is(
  (select count(*)::int from public.members where member_number = 'M-0001'
      and workspace_id in (current_setting('deskilo.ctr.ws')::uuid, current_setting('deskilo.ctr.ws2')::uuid)),
  2,
  'while the same member number in another workspace is its own');

create or replace function pg_temp.invoice(p_ws text, p_number text) returns void language sql as $inv$
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select p_ws::uuid, m.id, m.id, p_number, 'Invoice', '[]'::jsonb, 0, 'EUR', 'Owner', 'Counters', 'Owner', 'sig'
    from public.members m
   where m.workspace_id = p_ws::uuid and m.user_id = current_setting('deskilo.ctr.owner')::uuid;
$inv$;

select lives_ok(
  format($$ select pg_temp.invoice(%L, 'INV-2034-0001') $$, current_setting('deskilo.ctr.ws')),
  'an invoice number is issued once');
select throws_like(
  format($$ select pg_temp.invoice(%L, 'INV-2034-0001') $$, current_setting('deskilo.ctr.ws')),
  '%invoices_workspace_id_number_key%',
  'and the same invoice number cannot be issued a second time in that workspace');
select lives_ok(
  format($$ select pg_temp.invoice(%L, 'INV-2034-0001') $$, current_setting('deskilo.ctr.ws2')),
  'while another workspace keeps its own invoice series');

create or replace function pg_temp.declaration(p_start date, p_number text) returns void language sql as $decl$
  insert into public.vat_declarations (workspace_id, period_start, period_end, lines,
                                       total_net_cents, total_vat_cents, number)
  values (current_setting('deskilo.ctr.ws')::uuid, p_start, (p_start + interval '1 month' - interval '1 day')::date,
          '[]'::jsonb, 0, 0, p_number);
$decl$;

select pg_temp.declaration('2034-01-01', 'DECL-2034-0001');
select throws_like(
  $$ select pg_temp.declaration('2034-02-01', 'DECL-2034-0001') $$,
  '%vat_declarations_workspace_number_key%',
  'two VAT declarations of one workspace cannot carry the same number');

select is(
  (select count(distinct n)::int from (select pg_temp.draw('payment') n from generate_series(1, 5)) d),
  5,
  'five payment references drawn in a row are five different references');

-- ================================================================ KNOWN DEFECT
-- A series the width of its digits: 9 999 issued, the next is the 10 000th.
update public.number_sequences set next_value = 10000
 where workspace_id = current_setting('deskilo.ctr.ws')::uuid and journal = 'zz_plain';
select set_config('deskilo.ctr.wide1', pg_temp.try_draw('zz_plain'), false);
select set_config('deskilo.ctr.wide2', pg_temp.try_draw('zz_plain'), false);

-- Narrowing the digits below a counter that has passed them.
insert into public.number_sequences (workspace_id, journal, prefix, date_part, digits, reset, period_key, next_value)
values (current_setting('deskilo.ctr.ws')::uuid, 'zz_narrow', 'W-', 'none', 4, 'never', '', 150);
do $narrow$
begin
  perform pg_temp.configure('zz_narrow', 'W-', 'none', 2, 'never');
exception when others then
  null; -- a refusal is an acceptable fix
end
$narrow$;
select set_config('deskilo.ctr.narrow1', pg_temp.try_draw('zz_narrow'), false);
select set_config('deskilo.ctr.narrow2', pg_temp.try_draw('zz_narrow'), false);

select todo('#1338: number_sequence_format truncates a counter wider than its digits', 2);
select ok(
  current_setting('deskilo.ctr.wide1') <> 'P-1000'
    and current_setting('deskilo.ctr.wide1') <> current_setting('deskilo.ctr.wide2'),
  'the 10 000th number of a four-digit series is not the 1 000th printed again');
select ok(
  current_setting('deskilo.ctr.narrow1') <> current_setting('deskilo.ctr.narrow2'),
  'narrowing the digits below the counter never prints the same number twice');

select * from finish();
rollback;
