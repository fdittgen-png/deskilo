-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3294 / 0671: the customer figures, each proven from a hand-built March
-- 2025 (Paris, EUR). Invoices falling due in March:
--   d1 c2 12.00 due 10th, paid (ledger date) the 8th, matched 30 April -> on time, -2 days
--   d8 c3  9.00 due 1st,  paid the 11th after a reminder of the 5th      -> late, +10 days
--   d3 c3 10.00 due 15th, 4.00 accepted, nothing written off             -> partial
--   d4 c3  5.00 due 20th, nothing paid, two reminders (levels 1 and 2)   -> open
--   d5 c4  3.00 due 20th, under a dispute hold, one reminder             -> held
--   d6 c4  8.00 (6.40 net) due 5th, 2.00 paid, the rest written off      -> written off
--   a7 c5  6.00 due 12th and a8 c5 4.00 due 18th, regrouped into the
--      settlement f1 (10.00): open while f1 is unpaid, late (+13, +7) once
--      f1 is paid on the 25th; f1 itself is never counted apart
--   d7 c2  4.00 issued in March, no due date                             -> unknown due
--   e1 c2 -2.00 (-1.60 net) credit note of d1, issued in March.
-- Outside the due months: d9 c6 5.00 issued in March without a VAT
-- breakdown and b5 c6 4.00 whose second rate lacks its net (neither net
-- proven: left out of the net, counted), a9 c6 7.00 of January, unpaid
-- (a debtor with no proven March sales), and c7's February sale b3 3.00
-- credited in March by b4 (-1.00, -0.80 net).
-- Unpaid settlement: on time 1 of 2 settled; median -2, P90 10, weighted
-- (-2*1200+10*900)/2100 = 3.1 days. Four reminders on three of eight
-- invoices due, one paid after its reminder. Credited 2.40 net, written off
-- 6.00 * 6.40/8.00 = 4.80 net. Sales by signed net: c3 24.00, c2 14.40,
-- c5 10.00, c4 9.40, c7 -0.80 = 57.00. Debtors now: c6 16.00, c3 11.00,
-- c5 10.00 (f1), c2 4.00, c4 3.00, c7 2.00 = 46.00: another population
-- and another order.
-- Paid settlement: late 3 (19.00); delays -2, 7, 10, 13 -> median 7, P90 13,
-- weighted 17200/3100 = 5.5; c5 owes nothing, 36.00 owed by five debtors.
-- The owner reads names; an analyst without viewPersonalData reads ranks
-- only; without viewFinances, or with the status flag off, nothing is read;
-- a dollar invoice leaves every amount unknown (currency_mix) while the
-- counts stay.
begin;
select plan(33);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000032940'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@customers.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6','e7']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000032940b1','Customers','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032940a1','dev',
  '{"admin":["viewAnalytics","viewFinances"],"member":["viewAnalytics"]}',
  '{"moneyTab":true,"invoicing":true,"dunning":true,"workspaceStatus":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000032940c1','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000032940c2','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a2',false,true,'active'),
 ('00000000-0000-4000-8000-0000032940c3','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000032940c4','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a4',false,false,'active'),
 ('00000000-0000-4000-8000-0000032940c5','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a5',false,false,'active'),
 ('00000000-0000-4000-8000-0000032940c6','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940a6',false,false,'active'),
 ('00000000-0000-4000-8000-0000032940c7','00000000-0000-4000-8000-0000032940b1','00000000-0000-4000-8000-0000032940e7',false,false,'active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000032940' || p)::uuid;
$$;
-- An invoice; without p_vat its frozen breakdown proves it zero-rated
-- (net = gross); '[]' is a missing breakdown.
create function pg_temp.inv(p_id text, p_member text, p_total int, p_due date,
                            p_kind text default 'full', p_vat jsonb default null,
                            p_replaces text default null, p_period text default '2025-03')
returns void language plpgsql as $$
begin
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at,
                               period, kind, vat_totals, replaces_invoice_id)
  values (pg_temp.u(p_id), pg_temp.u('b1'), pg_temp.u(p_member), pg_temp.u('c1'), 'K-' || p_id, 'T', '[]'::jsonb,
          p_total, 'EUR', 'Name ' || p_member, 'Customers', 'Owner', 'sig',
          (p_period || '-01 10:00+01')::timestamptz, p_period, p_kind,
          coalesce(p_vat, jsonb_build_array(jsonb_build_object('percent', 0, 'category', 'Z',
            'gross_cents', p_total, 'net_cents', p_total, 'vat_cents', 0))),
          case when p_replaces is not null then pg_temp.u(p_replaces) end);
  if p_due is null then
    delete from public.invoice_maturities where invoice_id = pg_temp.u(p_id);
  else
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, evidence)
    values (pg_temp.u('b1'), pg_temp.u(p_id), p_due, 'document_term', 'fixture')
    on conflict (invoice_id) do update set due_on = excluded.due_on, basis = excluded.basis;
  end if;
end;
$$;
-- A payment reported paid on p_paid, matched at p_matched.
create function pg_temp.pay(p_id text, p_member text, p_cents int, p_resolution text,
                            p_paid date, p_matched timestamptz) returns void language plpgsql as $$
declare v_pay uuid;
begin
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents,
                                     description, period, occurred_on)
  values (pg_temp.u('b1'), pg_temp.u(p_member), 'credit', 'payment', p_cents, 'transfer',
          to_char(p_paid, 'YYYY-MM'), p_paid)
  returning id into v_pay;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, note,
                                      by_name, payment_ledger_id, matched_at)
  values (pg_temp.u('b1'), pg_temp.u(p_id), p_cents, p_resolution, 'confirmed', 'fixture', 'Owner',
          v_pay, p_matched);
end;
$$;
create function pg_temp.call(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  select public.kpi_customer_quality(pg_temp.u('b1'), p_from, p_to) into v;
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.inv('d1', 'c2', 1200, '2025-03-10');
select pg_temp.pay('d1', 'c2', 1200, 'exact', '2025-03-08', '2025-04-30 12:00+02');
select pg_temp.inv('d8', 'c3', 900, '2025-03-01');
select pg_temp.pay('d8', 'c3', 900, 'exact', '2025-03-11', '2025-03-12 12:00+01');
insert into public.invoice_reminders (workspace_id, invoice_id, sent_at, by_name, level)
values (pg_temp.u('b1'), pg_temp.u('d8'), '2025-03-05 09:00+01', 'Owner', 1);
select pg_temp.inv('d3', 'c3', 1000, '2025-03-15', 'subscription');
select pg_temp.pay('d3', 'c3', 400, 'under_accepted', '2025-03-14', '2025-03-14 12:00+01');
select pg_temp.inv('d4', 'c3', 500, '2025-03-20', 'usage');
insert into public.invoice_reminders (workspace_id, invoice_id, sent_at, by_name, level) values
 (pg_temp.u('b1'), pg_temp.u('d4'), '2025-03-21 09:00+01', 'Owner', 1),
 (pg_temp.u('b1'), pg_temp.u('d4'), '2025-03-28 09:00+01', 'Owner', 2);
select pg_temp.inv('d5', 'c4', 300, '2025-03-20');
insert into public.invoice_dunning_holds (workspace_id, invoice_id, reason) values (pg_temp.u('b1'), pg_temp.u('d5'), 'dispute');
insert into public.invoice_reminders (workspace_id, invoice_id, sent_at, by_name, level)
values (pg_temp.u('b1'), pg_temp.u('d5'), '2025-03-21 09:00+01', 'Owner', 1);
select pg_temp.inv('d6', 'c4', 800, '2025-03-05', 'subscription',
  '[{"percent":25,"category":"S","gross_cents":800,"net_cents":640,"vat_cents":160}]');
select pg_temp.pay('d6', 'c4', 200, 'under_accepted', '2025-03-06', '2025-03-06 12:00+01');
update public.invoice_matches set writeoff_at = '2025-03-31 12:00+02' where invoice_id = pg_temp.u('d6');
select pg_temp.inv('d7', 'c2', 400, null, 'subscription');
select pg_temp.inv('e1', 'c2', -200, null, 'usage',
  '[{"percent":25,"category":"S","gross_cents":-200,"net_cents":-160,"vat_cents":-40}]', 'd1');
-- The settlement of c5's two March invoices (0148): the document to pay.
select pg_temp.inv('a7', 'c5', 600, '2025-03-12');
select pg_temp.inv('a8', 'c5', 400, '2025-03-18', 'subscription');
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at, period,
                             kind, vat_totals)
values (pg_temp.u('f1'), pg_temp.u('b1'), pg_temp.u('c5'), pg_temp.u('c1'), 'K-f1', 'T', '[]', 1000, 'EUR',
        'Name c5', 'Customers', 'Owner', 'sig', '2025-03-20 10:00+01', null, 'settlement',
        '[{"percent":0,"category":"Z","gross_cents":1000,"net_cents":1000,"vat_cents":0}]');
update public.invoices set settled_by_invoice_id = pg_temp.u('f1') where id in (pg_temp.u('a7'), pg_temp.u('a8'));
-- A taxable invoice without its breakdown, and a January debtor.
select pg_temp.inv('d9', 'c6', 500, '2025-04-10', 'full', '[]');
select pg_temp.inv('a9', 'c6', 700, '2025-01-31', 'full', null, null, '2025-01');
-- A two-rate breakdown with one net missing: not proven either.
select pg_temp.inv('b5', 'c6', 400, '2025-04-10', 'subscription',
  '[{"percent":20,"category":"S","gross_cents":250,"net_cents":200,"vat_cents":50},
    {"percent":10,"category":"AA","gross_cents":150,"vat_cents":15}]');
-- c7: a February sale credited in March (-1.00, -0.80 net).
select pg_temp.inv('b3', 'c7', 300, '2025-02-28', 'full', null, null, '2025-02');
select pg_temp.inv('b4', 'c7', -100, null, 'full',
  '[{"percent":25,"category":"S","gross_cents":-100,"net_cents":-80,"vat_cents":-20}]', 'b3');

set local role authenticated;
select set_config('t.owner', pg_temp.call('a1')::text, true);
select set_config('t.analyst', pg_temp.call('a2')::text, true);

select is(current_setting('t.owner')::jsonb -> 'payment' -> 'cohorts',
  '{"on_time":{"count":1,"minor":"1200"},"late":{"count":1,"minor":"900"},"undated":{"count":0,"minor":"0"},
    "partial":{"count":1,"minor":"1000"},"open":{"count":3,"minor":"1500"},"held":{"count":1,"minor":"300"},
    "written_off":{"count":1,"minor":"800"},"unknown_due":{"count":1,"minor":"400"}}'::jsonb,
  'each invoice due in March is in one cohort; a source of an unpaid settlement is open, not settled');
select is((current_setting('t.owner')::jsonb -> 'payment' ->> 'median_days')::int, -2,
  'the median delay is dated by the reported payment, never by the match');
select is((current_setting('t.owner')::jsonb -> 'payment' ->> 'p90_days')::int, 10, 'the 90th percentile');
select is((current_setting('t.owner')::jsonb -> 'payment' ->> 'weighted_days')::numeric, 3.1,
  'the delay weighted by amount');
select is(current_setting('t.owner')::jsonb -> 'dunning' ->> 'due_invoices', '8',
  'eight invoices fell due; the one without a due date is not among them');
select is(current_setting('t.owner')::jsonb -> 'dunning' ->> 'reminders', '4', 'four reminders');
select is(current_setting('t.owner')::jsonb -> 'dunning' ->> 'reminded_invoices', '3', 'on three invoices');
select is(current_setting('t.owner')::jsonb -> 'dunning' -> 'by_level', '{"1":3,"2":1}'::jsonb, 'by level');
select is(current_setting('t.owner')::jsonb -> 'dunning' ->> 'paid_after_reminder', '1',
  'one reminded invoice was paid after its first reminder');
select is(current_setting('t.owner')::jsonb -> 'credit' ->> 'credited_minor', '240',
  'the credit notes, net of VAT, the one against a February sale included');
select is(current_setting('t.owner')::jsonb -> 'credit' ->> 'written_off_minor', '480',
  'the written-off remainder, in proportion to its invoice''s net');
select is(current_setting('t.owner')::jsonb -> 'credit' -> 'months',
  '[{"month":"2025-03","credited_minor":"240","written_off_minor":"480"}]'::jsonb, 'by the invoice''s month');
select is(current_setting('t.owner')::jsonb -> 'concentration' ->> 'net_minor', '5700',
  'net invoiced, the credit notes deducted (c7''s against a February sale too), the settlement not counted again');
select is(current_setting('t.owner')::jsonb -> 'concentration' ->> 'net_unknown', '2',
  'an invoice without its breakdown, or with a rate missing its net, is left out of the net and counted');
select ok(current_setting('t.owner')::jsonb -> 'reasons' ? 'net_not_proven', '... and said');
select is(current_setting('t.owner')::jsonb -> 'concentration' -> 'rows',
  '[{"rank":1,"name":"Name c3","minor":"2400"},{"rank":2,"name":"Name c2","minor":"1440"},
    {"rank":3,"name":"Name c5","minor":"1000"},{"rank":4,"name":"Name c4","minor":"940"},
    {"rank":5,"name":"Name c7","minor":"-80"}]'::jsonb,
  'the owner reads the customers by name, by signed net: a credit-only month ranks last, not dropped');
select is(current_setting('t.owner')::jsonb -> 'concentration' ->> 'top_net_minor', '5700',
  'the five largest against the same total');
select is(current_setting('t.owner')::jsonb -> 'concentration' ->> 'open_minor', '4600',
  'owed now by every debtor, the January one and the settlement included');
select is(current_setting('t.owner')::jsonb -> 'concentration' -> 'debtor_rows',
  '[{"rank":1,"name":"Name c6","minor":"1600"},{"rank":2,"name":"Name c3","minor":"1100"},
    {"rank":3,"name":"Name c5","minor":"1000"},{"rank":4,"name":"Name c2","minor":"400"},
    {"rank":5,"name":"Name c4","minor":"300"},{"rank":6,"name":"Name c7","minor":"200"}]'::jsonb,
  'the debtors are ranked by what they owe: another population, another order');
select is(current_setting('t.owner')::jsonb -> 'quality', '[]'::jsonb, 'a past month in one currency is whole');
select is(current_setting('t.analyst')::jsonb ->> 'names_visible', 'false',
  'an analyst without viewPersonalData is told names are withheld');
select is((select count(*)::int from jsonb_array_elements(
             (current_setting('t.analyst')::jsonb -> 'concentration' -> 'rows')
             || (current_setting('t.analyst')::jsonb -> 'concentration' -> 'debtor_rows')) r
            where r ->> 'name' is not null), 0, '... and reads no name');
select is(current_setting('t.analyst')::jsonb -> 'concentration' -> 'rows' -> 0 ->> 'minor', '2400',
  '... but the same ranked figures');
select throws_ok($q$select pg_temp.call('a3')$q$, '42501', null,
  'an analyst without viewFinances is refused');
select throws_ok($q$select pg_temp.call('a1', '2025-03', '2027-03')$q$, '22023', null,
  'more than 24 months is refused');

-- The settlement is paid on the 25th: its sources are late, c5 owes nothing.
reset role;
select is(public.kpi_invoice_net('[{"net_cents":"12"},{"net_cents":1.5}]'), null::bigint,
  'a malformed net is unknown, never an aborted figure');
select pg_temp.pay('f1', 'c5', 1000, 'exact', '2025-03-25', '2025-03-26 12:00+01');
set local role authenticated;
select set_config('t.paid', pg_temp.call('a1')::text, true);
select is(current_setting('t.paid')::jsonb -> 'payment' -> 'cohorts' -> 'late',
  '{"count":3,"minor":"1900"}'::jsonb, 'the sources of the paid settlement are late by its payment date');
select is(array[(current_setting('t.paid')::jsonb -> 'payment' ->> 'median_days')::numeric,
                (current_setting('t.paid')::jsonb -> 'payment' ->> 'p90_days')::numeric,
                (current_setting('t.paid')::jsonb -> 'payment' ->> 'weighted_days')::numeric],
  array[7, 13, 5.5]::numeric[], 'their delays count, once each');
select is(current_setting('t.paid')::jsonb -> 'concentration' ->> 'open_minor', '3600',
  'the paid settlement is owed by nobody');
select is(current_setting('t.paid')::jsonb -> 'concentration' ->> 'debtors', '5', 'five debtors left');

reset role;
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at, period, kind)
values (pg_temp.u('b1'), pg_temp.u('c4'), pg_temp.u('c1'), 'K-usd', 'T', '[]', 700, 'USD', 'Name c4',
        'Customers', 'Owner', 'sig', '2025-03-02 10:00+01', '2025-03', 'usage');
set local role authenticated;
select set_config('t.mixed', pg_temp.call('a1')::text, true);
select ok(current_setting('t.mixed')::jsonb -> 'reasons' ? 'currency_mix'
          and current_setting('t.mixed')::jsonb -> 'concentration' ->> 'net_minor' is null
          and current_setting('t.mixed')::jsonb -> 'credit' ->> 'credited_minor' is null,
  'a dollar invoice leaves every amount unknown, never summed');
select is(current_setting('t.mixed')::jsonb -> 'payment' -> 'cohorts' -> 'on_time' ->> 'count', '1',
  '... while the counts stay');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"workspaceStatus": false}' where id = pg_temp.u('b1');
set local role authenticated;
select throws_ok($q$select pg_temp.call('a1')$q$, '42501', null, 'with the status flag off, nothing is read');

select * from finish();
rollback;
