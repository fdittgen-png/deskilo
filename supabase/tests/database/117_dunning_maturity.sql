-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1913: whether a reminder is due follows the invoice's frozen maturity
-- and what is still collectible, never the invoice's age. Issued
-- 1 September with a 30-day term, the invoice is not overdue on
-- 20 September and is on 1 October in Paris — already at 23:30 UTC the
-- evening before. Month end and 29 February come out of the calendar,
-- not 30-day arithmetic. An explicit term, the unconfigured default and
-- an invoice from before the migration are three different outcomes, and
-- only the first lets the sweep escalate. 120 with 60 confirmed is 60
-- outstanding; a credit note lowers it; a write-off ends it; a pending
-- payment holds without making the balance disappear; a credit note in
-- another currency holds instead of being added. Only whoever issues
-- invoices in that space places a hold; a held invoice is not reminded,
-- by hand or by the sweep. A reminder states the remainder, not the
-- total. A second sweep adds nothing, and a space that never chose
-- automation is not swept.
begin;
select plan(30);

-- a1 owner of b1 · a2 member A of b1 · a3 plain member C of b1 ·
-- a4 owner of the foreign b2 · a5 owner of b3 (no term configured).
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001913'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@dunning.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,dunning_rules) values
 ('00000000-0000-4000-8000-0000001913b1','Dunning','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001913a1','dev',
  '{"paymentReminders":true}','{"levels":3,"first_after_days":30,"between_days":14,"automatic":true}'),
 ('00000000-0000-4000-8000-0000001913b2','Foreign dunning','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001913a4','dev','{}','{}'),
 ('00000000-0000-4000-8000-0000001913b3','No terms','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001913a5','dev',
  '{"paymentReminders":true}','{"levels":3}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001913c1','00000000-0000-4000-8000-0000001913b1','00000000-0000-4000-8000-0000001913a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001913c2','00000000-0000-4000-8000-0000001913b1','00000000-0000-4000-8000-0000001913a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001913c3','00000000-0000-4000-8000-0000001913b1','00000000-0000-4000-8000-0000001913a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001913c4','00000000-0000-4000-8000-0000001913b2','00000000-0000-4000-8000-0000001913a4',true,true,'active'),
 ('00000000-0000-4000-8000-0000001913c5','00000000-0000-4000-8000-0000001913b3','00000000-0000-4000-8000-0000001913a5',true,true,'active');

create or replace function pg_temp.inv(p_id text, p_ws text, p_member text, p_issued timestamptz, p_total int,
                                       p_currency text default 'EUR', p_replaces text default null)
returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at, replaces_invoice_id)
  values (('00000000-0000-4000-8000-0000001913' || p_id)::uuid, ('00000000-0000-4000-8000-0000001913' || p_ws)::uuid,
          ('00000000-0000-4000-8000-0000001913' || p_member)::uuid,
          ('00000000-0000-4000-8000-0000001913' || case p_ws when 'b3' then 'c5' else 'c1' end)::uuid,
          'D-' || p_id, 'T', '[]'::jsonb, p_total, p_currency, 'A', 'Dunning', 'Owner', 'sig', p_issued,
          case when p_replaces is null then null else ('00000000-0000-4000-8000-0000001913' || p_replaces)::uuid end);
$$;
create or replace function pg_temp.st(p_id text, p_at timestamptz default now()) returns jsonb language sql as $$
  select public.invoice_dunning_state_core(('00000000-0000-4000-8000-0000001913' || p_id)::uuid, p_at);
$$;
create or replace function pg_temp.match(p_id text, p_status text, p_paid int, p_resolution text) returns void language sql as $$
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, note, by_name)
  values ('00000000-0000-4000-8000-0000001913b1', ('00000000-0000-4000-8000-0000001913' || p_id)::uuid,
          p_paid, p_resolution, p_status, 'fixture', 'Owner');
$$;

select pg_temp.inv('d1', 'b1', 'c2', '2026-09-01 10:00+02', 12000);
select pg_temp.inv('d2', 'b1', 'c2', '2026-01-31 12:00+01', 12000);
select pg_temp.inv('d3', 'b1', 'c2', '2028-01-30 12:00+01', 12000);
select pg_temp.inv('d4', 'b3', 'c5', now() - interval '60 days', 12000);
select pg_temp.inv('d5', 'b1', 'c2', now() - interval '60 days', 12000);
select pg_temp.inv('d6', 'b1', 'c2', now() - interval '60 days', 12000);
select pg_temp.inv('e6', 'b1', 'c2', now() - interval '59 days', -100, 'USD', 'd6');
select pg_temp.inv('d7', 'b1', 'c2', now() - interval '60 days', 12000);
select pg_temp.inv('d8', 'b1', 'c2', now() - interval '60 days', 12000);
select pg_temp.inv('d9', 'b1', 'c2', now() - interval '40 days', 12000);
select pg_temp.inv('da', 'b1', 'c2', now() - interval '10 days', 12000);
-- d5 stands for an invoice issued before the migration.
update public.invoice_maturities set basis = 'unknown', due_on = null, terms_days = null, evidence = 'legacy'
 where invoice_id = '00000000-0000-4000-8000-0000001913d5';

-- ── the maturity is frozen and calendar-true ────────────────────────
select is((select due_on from public.invoice_maturities where invoice_id = '00000000-0000-4000-8000-0000001913d1'), '2026-10-01'::date,
  'issued 1 September with a 30-day term: due 1 October');
select is(pg_temp.st('d1', '2026-09-20 12:00+02')->>'phase', 'pre_due', '20 September is not overdue');
select is(pg_temp.st('d1', '2026-10-01 00:30+02')->>'phase', 'overdue', '1 October is');
select is(pg_temp.st('d1', '2026-09-30 23:30+00')->>'level_due', '1', 'already at 23:30 UTC the evening before, in Paris');
select is(pg_temp.st('d1', '2026-09-30 21:30+00')->>'phase', 'pre_due', 'but not at 23:30 Paris time');
select is((select due_on from public.invoice_maturities where invoice_id = '00000000-0000-4000-8000-0000001913d2'), '2026-03-02'::date,
  '31 January + 30 days is 2 March');
select is((select due_on from public.invoice_maturities where invoice_id = '00000000-0000-4000-8000-0000001913d3'), '2028-02-29'::date,
  '30 January 2028 + 30 days is 29 February');

-- ── three kinds of maturity ─────────────────────────────────────────
select is(pg_temp.st('d1')->>'maturity_basis', 'document_term', 'an explicit term is the document''s term');
select ok(pg_temp.st('d4')->>'maturity_basis' = 'default_term' and not (pg_temp.st('d4')->>'automatic_allowed')::boolean,
  'the unconfigured 14-day default is overdue but may not escalate on its own');
select ok(pg_temp.st('d5')->>'phase' = 'unknown_maturity' and pg_temp.st('d5')->'due_on' = 'null'::jsonb,
  'an invoice from before the migration has no invented date');

-- ── what is collectible ─────────────────────────────────────────────
select pg_temp.match('d1', 'confirmed', 6000, 'under_accepted');
select is(pg_temp.st('d1')->>'collectible_cents', '6000', '120 with 60 confirmed is 60 outstanding');
select pg_temp.inv('e1', 'b1', 'c2', now(), -2000, 'EUR', 'd1');
select is(pg_temp.st('d1')->>'collectible_cents', '4000', 'a credit note lowers it');
select is(pg_temp.st('d6')->>'hold', 'mixed_currency', 'a credit note in another currency holds rather than being added');
select pg_temp.match('d7', 'pending', 12000, 'exact');
select ok(pg_temp.st('d7')->>'hold' = 'pending_payment' and pg_temp.st('d7')->>'collectible_cents' = '12000',
  'a pending payment holds without making the balance disappear');

-- ── holds ────────────────────────────────────────────────────────────
create temp table seen(k text primary key, v jsonb);
grant select, insert on seen to authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.place_dunning_hold('00000000-0000-4000-8000-0000001913d8','dispute')$$,
  'only whoever issues the invoices of this space places a hold', 'a plain member cannot place a hold');
select throws_ok($$select public.invoice_dunning_state('00000000-0000-4000-8000-0000001913d8')$$,
  'not allowed to read the dunning state of this invoice', 'nor read another member''s dunning state');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a4","role":"authenticated"}',true);
select throws_ok($$select public.place_dunning_hold('00000000-0000-4000-8000-0000001913d8','dispute')$$,
  'only whoever issues the invoices of this space places a hold', 'the owner of another space cannot either, by id');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a2","role":"authenticated"}',true);
insert into seen values ('own', public.invoice_dunning_state('00000000-0000-4000-8000-0000001913d1'));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a1","role":"authenticated"}',true);
select lives_ok($$select public.place_dunning_hold('00000000-0000-4000-8000-0000001913d8','dispute','the member contests the amount')$$,
  'the owner places a dispute hold');
select throws_like($$select public.record_invoice_reminder('00000000-0000-4000-8000-0000001913d8')$$,
  'this invoice is on hold%', 'a held invoice is not reminded by hand');
select lives_ok($$select public.record_invoice_reminder('00000000-0000-4000-8000-0000001913d1')$$,
  'the owner reminds the half-paid invoice by hand');
select lives_ok($$select public.sweep_payment_reminders('00000000-0000-4000-8000-0000001913b1')$$, 'the sweep runs');
insert into seen values ('second', to_jsonb(public.sweep_payment_reminders('00000000-0000-4000-8000-0000001913b1')));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a5","role":"authenticated"}',true);
insert into seen values ('b3', to_jsonb(public.sweep_payment_reminders('00000000-0000-4000-8000-0000001913b3')));
reset role;

select is((select v->>'collectible_cents' from seen where k = 'own'), '4000', 'the member reads their own invoice''s state');
select is((select (e.payload->>'amount_cents') from public.events e
            where e.type = 'invoice_reminder' and e.payload->>'invoice_id' = '00000000-0000-4000-8000-0000001913d1'),
  '4000', 'the reminder states the remainder, not the total');
select is((select count(*)::int from public.invoice_reminders where invoice_id = '00000000-0000-4000-8000-0000001913d9' and automatic), 1,
  'the sweep reminds the overdue invoice with an explicit term');
select is((select count(*)::int from public.invoice_reminders where invoice_id = '00000000-0000-4000-8000-0000001913da'), 0,
  'not the one still before its due date');
select is((select count(*)::int from public.invoice_reminders where invoice_id in
            ('00000000-0000-4000-8000-0000001913d5','00000000-0000-4000-8000-0000001913d6',
             '00000000-0000-4000-8000-0000001913d7','00000000-0000-4000-8000-0000001913d8')), 0,
  'nor the unknown maturity, the mixed currency, the pending payment or the dispute');
select is((select v from seen where k = 'second'), '0'::jsonb, 'a second sweep adds nothing');
select is((select v from seen where k = 'b3'), '0'::jsonb, 'a space that never chose automation is not swept');

-- ── a write-off ends it ─────────────────────────────────────────────
update public.invoice_matches set writeoff_at = now() where invoice_id = '00000000-0000-4000-8000-0000001913d1';
select is(pg_temp.st('d1')->>'collectible_cents', '0', 'after a validated write-off nothing is collectible');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001913a1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.record_invoice_reminder('00000000-0000-4000-8000-0000001913d1')$$,
  'nothing is outstanding on this invoice', 'and nothing can be reminded');
reset role;

select * from finish();
rollback;
