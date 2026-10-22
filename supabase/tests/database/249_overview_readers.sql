-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2583 / 0536: the overview's own figures, current state.
-- Memberships: two active, one paused -> 2. Overdue receivables: an invoice
-- of 12.00 from January 2025 with 2.00 matched (10.00 still owed, overdue);
-- one on hold (counted apart); one whose due date is unknown (counted
-- apart); one issued today (not due yet); one voided (out). -> 10.00 over
-- one invoice. A past period gets today's value, said as not recorded; a
-- member without the analytics right, or the flag off, is refused.
begin;
select plan(9);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025830'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@overview.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025830b1','Overview','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025830a1','dev',
  '{"moneyTab":true,"invoicing":true,"dunning":true,"workspaceOverview":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025830c1','00000000-0000-4000-8000-0000025830b1','00000000-0000-4000-8000-0000025830a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025830c2','00000000-0000-4000-8000-0000025830b1','00000000-0000-4000-8000-0000025830a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000025830c3','00000000-0000-4000-8000-0000025830b1','00000000-0000-4000-8000-0000025830a3',false,false,'paused');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025830' || p)::uuid;
$$;
create function pg_temp.inv(p_id text, p_issued timestamptz, p_total int) returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at)
  values (pg_temp.u(p_id), pg_temp.u('b1'), pg_temp.u('c2'), pg_temp.u('c1'), 'O-' || p_id, 'T', '[]'::jsonb,
          p_total, 'EUR', 'A', 'Overview', 'Owner', 'sig', p_issued);
$$;
create function pg_temp.call(p_user text, p_fn text, p_from text, p_to text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  execute format('select public.%I(%L, %L, %L)', p_fn, pg_temp.u('b1'), p_from, p_to) into v;
  return v;
end;
$$;

select pg_temp.inv('d1', '2025-01-10 10:00+01', 1200);
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, note, by_name)
values (pg_temp.u('b1'), pg_temp.u('d1'), 200, 'under_accepted', 'confirmed', 'fixture', 'Owner');
select pg_temp.inv('d2', '2025-02-10 10:00+01', 500);
insert into public.invoice_dunning_holds (workspace_id, invoice_id, reason) values (pg_temp.u('b1'), pg_temp.u('d2'), 'dispute');
select pg_temp.inv('d3', '2025-03-10 10:00+01', 300);
delete from public.invoice_maturities where invoice_id = pg_temp.u('d3');
select pg_temp.inv('d4', now(), 800);
select pg_temp.inv('d5', '2025-01-05 10:00+01', 700);
update public.invoices set voided_at = now() where id = pg_temp.u('d5');

set local role authenticated;
select set_config('t.now', to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'), true);
select set_config('t.overdue',
  pg_temp.call('a1', 'kpi_overdue_receivables', current_setting('t.now'), current_setting('t.now'))::text, true);

select is(pg_temp.call('a1', 'kpi_memberships_current', current_setting('t.now'), current_setting('t.now')) ->> 'value',
  '2', 'two active memberships; the paused one is not counted');
select is(current_setting('t.overdue')::jsonb ->> 'value', '1000',
  'overdue: 12.00 less the 2.00 matched; the held, undated, not-yet-due and voided invoices are not in it');
select is((current_setting('t.overdue')::jsonb ->> 'count')::int, 1, 'over one invoice');
select is((current_setting('t.overdue')::jsonb ->> 'held_count')::int, 1, 'the invoice on hold is counted apart');
select is((current_setting('t.overdue')::jsonb ->> 'unknown_due_count')::int, 1,
  'the invoice with no proven due date is counted apart');
select is(current_setting('t.overdue')::jsonb -> 'quality', '[]'::jsonb, 'the current month is today''s figure');
select ok(pg_temp.call('a1', 'kpi_memberships_current', '2025-01', '2025-01') -> 'reasons' ? 'current_state',
  'a past period gets today''s value, said as such');
select throws_ok($q$select pg_temp.call('a2', 'kpi_memberships_current', '2026-01', '2026-01')$q$,
  '42501', null, 'a member without the analytics right is refused');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"workspaceOverview": false}' where id = pg_temp.u('b1');
set local role authenticated;
select throws_ok($q$select pg_temp.call('a1', 'kpi_overdue_receivables', '2026-01', '2026-01')$q$,
  '42501', null, 'with the overview off, nothing is read');

select * from finish();
rollback;
