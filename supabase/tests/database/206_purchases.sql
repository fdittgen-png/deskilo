-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2573 / 0461 (C1 of #2464): ONE purchase document for supplier bills and
-- member expenses. Real roles throughout (authenticated through the definer
-- RPCs and the RLS policies); every refusal is followed by a readback proving
-- nothing changed.
--   A history: every expense event has its document; partial tax stays NULL
--   B the trigger: an old client's submit_expense files the same document
--   C approval and rejection follow the expense validation; ONE credit
--   D a frozen document; the composite keys; one source funds one purchase
--   E the native path: draft, replay, stale revision, submit through the event
--   F tax: eligible, half deductible, unqualified, mixed rates
--   G supplier bills: capture, who may, the flag, partial is not zero
--   H linking an invoice: once, to the purchase of its own expense
--   I who reads what (own, the finances, a foreign workspace), no client write
--   J the catalogues
begin;
select plan(102);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- The refusal text of running [p_sql] as [p_user]; '' when it worked.
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

-- The result of calling [p_sql] (a select returning jsonb) as [p_user].
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;

-- The refusal text of a statement run as the table owner.
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002573' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int, w text) returns uuid language sql as $$
  select id from public.members
   where user_id = pg_temp.u(n) and workspace_id = current_setting(w)::uuid;
$$;

-- A draft receipt payload: one line, EUR 120.00 with 20 % tax, [rec] recoverable.
create function pg_temp.receipt(p_purchase uuid, p_rec text, p_rate text default '20') returns text language sql as $$
  select jsonb_build_object(
    'kind', 'member_receipt', 'category', 'cleaning',
    'purchase_id', p_purchase,
    'lines', jsonb_build_array(jsonb_build_object(
      'description', 'Cleaning', 'gross_cents', 12000, 'net_cents', 10000, 'tax_cents', 2000,
      'tax_rate_percent', p_rate::numeric, 'recoverable_tax_cents', nullif(p_rec, '')::bigint)))::text;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@purchases.test', '', now(), now(), now()
  from generate_series(1, 6) i;
-- 1 owner of A, 2 and 3 plain members of A, 4 an admin of A, 5 owner of B, 6 a member of A.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Purchases A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Purchases B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"services": true, "supplyExpenses": true, "purchases": true, "invoicing": true,
          "vatManagement": true, "vatDeclarations": true, "inputVat": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, true, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(6), false, false, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name) values
 ('00000000-0000-4000-8000-0000257300a1', current_setting('t.a')::uuid, '1', 'ACME Sarl'),
 ('00000000-0000-4000-8000-0000257300b1', current_setting('t.b')::uuid, '1', 'Other Ltd');

-- ── A: the history of the expense events ───────────────────────────────
create temp table before_ledger as select count(*) as n from public.ledger_entries;
-- a pending expense with VAT, an approved one without any, a rejected asset
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 ('00000000-0000-4000-8000-000025730e01', current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'),
  '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning", "vat": {"percent": 20, "deductible_pct": 100}}', 'pending', null),
 ('00000000-0000-4000-8000-000025730e02', current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'),
  '{"amount_cents": 5000, "category": "coffee", "note": "Coffee beans"}', 'confirmed', now() - interval '3 days'),
 ('00000000-0000-4000-8000-000025730e03', current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(3, 't.a'), pg_temp.mem(3, 't.a'),
  '{"amount_cents": 33000, "category": "equipment", "note": "Printer", "vat": {"percent": 10, "deductible_pct": 50, "asset": true}}', 'rejected', now() - interval '2 days');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
values (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 5000, 'Coffee beans', to_char(now(), 'YYYY-MM'),
        '00000000-0000-4000-8000-000025730e02');
create temp table ledger_after_seed as select count(*) as n from public.ledger_entries;
create temp table docs_digest as
  select d.id, md5(row(d.kind, d.state, d.currency, d.category, d.submitter_member_id, d.payer_kind, d.payer_member_id,
                       d.approved_event_id, d.legacy_qualification, d.classification_status)::text
                   || (select string_agg(row(l.line_no, l.gross_cents, l.net_cents, l.tax_cents, l.tax_rate_percent,
                                              l.recoverable_tax_cents, l.nonrecoverable_tax_cents, l.recognition_kind)::text, ',' order by l.line_no)
                         from public.purchase_lines l where l.purchase_id = d.id)) as digest,
         (select s.source_id from public.purchase_sources s where s.purchase_id = d.id and s.source_kind = 'expense_event') as event_id
    from public.purchase_documents d where d.workspace_id = current_setting('t.a')::uuid;

select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.a')::uuid), 3,
  'A: golden: each of the three expense events has its document');
select is((select string_agg(d.state, ',' order by s.source_id) from public.purchase_documents d
             join public.purchase_sources s on s.purchase_id = d.id and s.source_kind = 'expense_event'
            where d.workspace_id = current_setting('t.a')::uuid), 'pending,approved,rejected',
  'A: the state follows the event (pending, confirmed, rejected)');
select is((select d.legacy_qualification || '/' || d.classification_status || '/' || d.kind || '/' || d.payer_kind
             from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = '00000000-0000-4000-8000-000025730e01'), 'legacy_unverified/legacy/member_receipt/member',
  'A: a filed expense is a legacy, unverified member receipt');
select is((select concat_ws('/', l.gross_cents, l.net_cents, l.tax_cents, l.recoverable_tax_cents, l.nonrecoverable_tax_cents, l.tax_rate_percent)
             from public.purchase_lines l join public.purchase_sources s on s.purchase_id = l.purchase_id
            where s.source_id = '00000000-0000-4000-8000-000025730e01'), '12000/10000/2000/2000/0/20.0000',
  'A: EUR 120 with 20 % tax: net 100, tax 20, all recoverable');
select is((select concat_ws('/', l.gross_cents, coalesce(l.net_cents::text, 'null'), coalesce(l.tax_cents::text, 'null'),
                            coalesce(l.tax_rate_percent::text, 'null'), l.recognition_kind)
             from public.purchase_lines l join public.purchase_sources s on s.purchase_id = l.purchase_id
            where s.source_id = '00000000-0000-4000-8000-000025730e02'), '5000/null/null/null/unresolved',
  'A: an expense that stated no VAT keeps its tax UNKNOWN (null), not zero, and its class unresolved');
select is((select concat_ws('/', l.net_cents, l.tax_cents, l.recoverable_tax_cents, l.nonrecoverable_tax_cents, l.recognition_kind)
             from public.purchase_lines l join public.purchase_sources s on s.purchase_id = l.purchase_id
            where s.source_id = '00000000-0000-4000-8000-000025730e03'), '30000/3000/1500/1500/asset',
  'A: a half-deductible asset keeps its split and its asset class');
select is((select d.approved_event_id from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = '00000000-0000-4000-8000-000025730e02'), '00000000-0000-4000-8000-000025730e02'::uuid,
  'A: the approved document points at the event that approved it');
select is((select d.legacy_decided_at from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = '00000000-0000-4000-8000-000025730e02'),
          (select decided_at from public.events where id = '00000000-0000-4000-8000-000025730e02'),
  'A: the legacy decision time is kept as provenance');
select is((select count(*)::int from public.ledger_entries), (select n::int from ledger_after_seed),
  'A: filing the documents wrote no ledger row: the existing credit stays the only one');

-- the backfill alone: drop the documents, run the one bridge path twice
delete from public.purchase_documents where workspace_id = current_setting('t.a')::uuid;
select public.purchase_bridge_expense(e) from public.events e where e.type = 'expense' and e.workspace_id = current_setting('t.a')::uuid;
select public.purchase_bridge_expense(e) from public.events e where e.type = 'expense' and e.workspace_id = current_setting('t.a')::uuid;
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.a')::uuid), 3,
  'A: running the backfill twice still gives one document per event');
select is((select count(*)::int from docs_digest d join public.purchase_sources s
              on s.source_id = d.event_id and s.source_kind = 'expense_event'
             join public.purchase_documents p on p.id = s.purchase_id
            where md5(row(p.kind, p.state, p.currency, p.category, p.submitter_member_id, p.payer_kind, p.payer_member_id,
                          p.approved_event_id, p.legacy_qualification, p.classification_status)::text
                      || (select string_agg(row(l.line_no, l.gross_cents, l.net_cents, l.tax_cents, l.tax_rate_percent,
                                                 l.recoverable_tax_cents, l.nonrecoverable_tax_cents, l.recognition_kind)::text, ',' order by l.line_no)
                            from public.purchase_lines l where l.purchase_id = p.id)) = d.digest), 3,
  'A: the rebuilt documents are identical to the first ones');
select is((select count(*)::int from public.ledger_entries), (select n::int from ledger_after_seed),
  'A: and the backfill touched no ledger row either');

-- ── B / C: an old client, the validation, ONE credit ───────────────────
select set_config('t.e4', pg_temp.as_json(pg_temp.u(2),
  format('select to_jsonb(public.submit_expense(%L, 12000, ''cleaning'', ''Cleaning'', null, %L::jsonb))',
         current_setting('t.a'), '{"percent": 20, "deductible_pct": 100}'))#>>'{}', true);
select is((select count(*)::int from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e4')::uuid and d.state = 'pending'), 1,
  'B: an old client''s submit_expense files its document, pending');
select is((select count(*)::int from public.events where id = current_setting('t.e4')::uuid and not payload ? 'purchase_id'), 1,
  'B: the event of an old client is unchanged (no purchase id stamped on it)');
select is(pg_temp.as_err(pg_temp.u(2), format('select public.respond_to_event(%L, true)', current_setting('t.e4'))),
  'you are not an eligible validator for this event', 'C: the submitter cannot approve their own expense');
select is((select state from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e4')::uuid), 'pending', 'C: and the document stays pending');
select is(pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, true)', current_setting('t.e4'))), '',
  'C: another admin approves it');
select is((select d.state || '/' || (d.approved_event_id = current_setting('t.e4')::uuid)::text
             from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e4')::uuid), 'approved/true',
  'C: the document is approved by that event');
select is((select count(*)::int from public.ledger_entries where event_id = current_setting('t.e4')::uuid and kind = 'credit' and amount_cents = 12000), 1,
  'C: exactly ONE member credit of EUR 120 was issued, by the existing path');
select ok((select recipient_snapshot ->> 'name' = 'Purchases A' from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e4')::uuid), 'C: the recipient identity is snapshotted at approval');
select set_config('t.e5', pg_temp.as_json(pg_temp.u(2),
  format('select to_jsonb(public.submit_expense(%L, 800, ''stamps'', ''Stamps'', null, null))', current_setting('t.a')))#>>'{}', true);
select pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, false)', current_setting('t.e5')));
select is((select state from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e5')::uuid), 'rejected', 'C: a rejection rejects the document');
select is((select count(*)::int from public.ledger_entries where event_id = current_setting('t.e5')::uuid), 0, 'C: and issues no credit');
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.a')::uuid), 5,
  'C: five events, five documents: no event has two');

-- ── D: frozen, composite keys, one source one purchase ────────────────
select ok((pg_temp.owner_err(format('update public.purchase_documents set category = ''x'' where approved_event_id = %L', current_setting('t.e4')))) like '%frozen%', 'D: an approved document cannot be edited, even by the table owner');
select ok((pg_temp.owner_err(format('update public.purchase_lines set gross_cents = 1 where purchase_id = (select purchase_id from public.purchase_sources where source_id = %L)', current_setting('t.e4')))) like '%frozen%', 'D: nor its lines');
select ok((pg_temp.owner_err(format('update public.purchase_documents set category = ''x'' where id = (select purchase_id from public.purchase_sources where source_id = %L)', '00000000-0000-4000-8000-000025730e01'))) like '%awaiting approval%', 'D: a pending document cannot be edited either');
select is((select category from public.purchase_documents d join public.purchase_sources s on s.purchase_id = d.id
            where s.source_id = current_setting('t.e4')::uuid), 'cleaning', 'D: readback: nothing changed');
select ok((pg_temp.owner_err(format('insert into public.purchase_sources (workspace_id, purchase_id, source_kind, source_id) select workspace_id, purchase_id, ''expense_event'', source_id from public.purchase_sources where source_id = %L', current_setting('t.e4')))) like '%duplicate key%', 'D: a source cannot fund two purchases');
select ok((pg_temp.owner_err(format('insert into public.purchase_documents (workspace_id, kind, currency, submitter_member_id, payer_kind, payer_member_id, supplier_id) values (%L, ''bill'', ''EUR'', %L, ''unpaid'', null, ''00000000-0000-4000-8000-0000257300b1'')',
    current_setting('t.a'), pg_temp.mem(1, 't.a')))) like '%foreign key%', 'D: a supplier of another workspace is refused by the composite key');
select ok((pg_temp.owner_err(format('insert into public.purchase_documents (workspace_id, kind, currency, submitter_member_id, payer_kind) values (%L, ''bill'', ''EUR'', %L, ''unpaid'')',
    current_setting('t.a'), pg_temp.mem(5, 't.b')))) like '%foreign key%', 'D: a submitter of another workspace is refused');
select ok((pg_temp.owner_err('insert into public.purchase_lines (workspace_id, purchase_id, line_no, gross_cents, net_cents, tax_cents) select workspace_id, id, 9, 1000, 800, 100 from public.purchase_documents where state = ''pending'' limit 1')) like '%frozen%', 'D: a line cannot be added to a submitted document');

-- ── E: the native path ─────────────────────────────────────────────────
select set_config('t.req1', 'a0000000-0000-4000-8000-000000000001', true);
select set_config('t.r1', pg_temp.as_json(pg_temp.u(2), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), current_setting('t.req1'), pg_temp.receipt(null, '2000')))::text, true);
select is((current_setting('t.r1')::jsonb ->> 'revision') || '/' || (current_setting('t.r1')::jsonb ->> 'state'), '1/draft',
  'E: golden: a member saves a draft receipt (revision 1)');
select set_config('t.p1', current_setting('t.r1')::jsonb ->> 'purchase_id', true);
select is((select count(*)::int from public.events where type = 'expense' and workspace_id = current_setting('t.a')::uuid), 5,
  'E: a draft files no expense yet');
select is((select concat_ws('/', d.kind, d.payer_kind, (d.payer_member_id = pg_temp.mem(2, 't.a'))::text, d.legacy_qualification)
             from public.purchase_documents d where d.id = current_setting('t.p1')::uuid), 'member_receipt/member/true/none',
  'E: the payer and the submitter are derived from the caller, the document is not legacy');
select is(pg_temp.as_json(pg_temp.u(2), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), current_setting('t.req1'), pg_temp.receipt(null, '2000'))),
  current_setting('t.r1')::jsonb, 'E: the same request id with the same entries returns the committed result');
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.a')::uuid), 6, 'E: and creates nothing');
select ok((pg_temp.as_json(pg_temp.u(2), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), current_setting('t.req1'), pg_temp.receipt(null, '1000')))::text) like '%different request%', 'E: the same request id with other entries is refused');
select ok((pg_temp.as_json(pg_temp.u(3), format(
  'select public.save_purchase_draft_v1(%L, %L, 1, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000002', pg_temp.receipt(current_setting('t.p1')::uuid, '2000')))::text) like '%not your purchase%', 'E: another member cannot edit the draft');
select ok((pg_temp.as_json(pg_temp.u(2), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000003', pg_temp.receipt(current_setting('t.p1')::uuid, '2000')))::text) like '%stale revision%', 'E: a stale revision is refused');
select is((select revision from public.purchase_documents where id = current_setting('t.p1')::uuid), 1, 'E: readback: still revision 1');
select is((pg_temp.as_json(pg_temp.u(2), format(
  'select public.save_purchase_draft_v1(%L, %L, 1, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000004', pg_temp.receipt(current_setting('t.p1')::uuid, '2000'))) ->> 'revision')::int, 2,
  'E: an edit at the right revision moves it to 2');
select set_config('t.s1', pg_temp.as_json(pg_temp.u(2), format(
  'select public.submit_purchase_v1(%L, %L, 2, %L)', current_setting('t.a'), current_setting('t.p1'), 'a0000000-0000-4000-8000-000000000005'))::text, true);
select is(current_setting('t.s1')::jsonb ->> 'state', 'pending', 'E: submitting files the expense and the document is pending');
select is((select count(*)::int from public.events where type = 'expense' and workspace_id = current_setting('t.a')::uuid), 6,
  'E: exactly one new expense event');
select is((select count(*)::int from public.purchase_sources where purchase_id = current_setting('t.p1')::uuid and source_kind = 'expense_event'), 1,
  'E: and it is the source of THIS document');
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.a')::uuid), 6,
  'E: no second document was filed for the event');
select is((select e.payload ->> 'purchase_id' || '/' || (e.payload ->> 'payer') || '/' || (e.payload #>> '{vat,percent}') || '/' || (e.payload #>> '{vat,deductible_pct}')
             from public.events e where e.id = (current_setting('t.s1')::jsonb ->> 'event_id')::uuid),
  current_setting('t.p1') || '/member/20/100', 'E: the event carries the purchase id, the payer mode and the VAT');
select is(pg_temp.as_json(pg_temp.u(2), format(
  'select public.submit_purchase_v1(%L, %L, 2, %L)', current_setting('t.a'), current_setting('t.p1'), 'a0000000-0000-4000-8000-000000000005')),
  current_setting('t.s1')::jsonb, 'E: replaying the submit returns the same result');
select is((select count(*)::int from public.events where type = 'expense' and workspace_id = current_setting('t.a')::uuid), 6, 'E: and files no second event');
select ok((pg_temp.as_json(pg_temp.u(2), format(
  'select public.submit_purchase_v1(%L, %L, 2, %L)', current_setting('t.a'), current_setting('t.p1'), 'a0000000-0000-4000-8000-000000000006'))::text) like '%only a draft%', 'E: another request for a submitted document is refused');
select pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, true)', current_setting('t.s1')::jsonb ->> 'event_id'));
select is((select count(*)::int from public.ledger_entries where event_id = (current_setting('t.s1')::jsonb ->> 'event_id')::uuid and kind = 'credit' and amount_cents = 12000), 1,
  'E: approval issues ONE credit of EUR 120');
select is((select state from public.purchase_documents where id = current_setting('t.p1')::uuid), 'approved', 'E: and approves the document');
select is((select string_agg(v.net_cents::text || '+' || (v.gross_cents - v.net_cents)::text, ',') from public.vat_input_amounts(
  current_setting('t.a')::uuid, current_date - 1, current_date + 1) v where v.expense_id = (current_setting('t.s1')::jsonb ->> 'event_id')::uuid),
  '10000+2000', 'E: the input-VAT source reads cost 100.00 and input tax 20.00 (via the legacy payload, once)');

-- ── F: tax qualification ───────────────────────────────────────────────
select set_config('t.pf', (pg_temp.as_json(pg_temp.u(3), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000010', pg_temp.receipt(null, ''))) ->> 'purchase_id'), true);
select ok((pg_temp.as_json(pg_temp.u(3), format(
  'select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.pf'), 'a0000000-0000-4000-8000-000000000011'))::text) like '%qualify the deductible tax%', 'F: an unqualified deductible share is refused, never defaulted to 100 %');
select is((select state from public.purchase_documents where id = current_setting('t.pf')::uuid), 'draft', 'F: readback: still a draft');
select is((select count(*)::int from public.events where type = 'expense' and workspace_id = current_setting('t.a')::uuid), 6, 'F: readback: no event');
select pg_temp.as_json(pg_temp.u(3), format(
  'select public.save_purchase_draft_v1(%L, %L, 1, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000012', pg_temp.receipt(current_setting('t.pf')::uuid, '1000')));
select set_config('t.sf', pg_temp.as_json(pg_temp.u(3), format(
  'select public.submit_purchase_v1(%L, %L, 2, %L)', current_setting('t.a'), current_setting('t.pf'), 'a0000000-0000-4000-8000-000000000013'))::text, true);
select pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, true)', current_setting('t.sf')::jsonb ->> 'event_id'));
select is((select string_agg(v.gross_cents::text || '/' || v.net_cents::text, ',') from public.vat_input_amounts(
  current_setting('t.a')::uuid, current_date - 1, current_date + 1) v where v.expense_id = (current_setting('t.sf')::jsonb ->> 'event_id')::uuid),
  '11000/10000', 'F: half deductible: cost 110.00 and input tax 10.00');
select set_config('t.pm', (pg_temp.as_json(pg_temp.u(3), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000014',
  jsonb_build_object('kind', 'member_receipt', 'category', 'mixed', 'lines', jsonb_build_array(
    jsonb_build_object('gross_cents', 12000, 'net_cents', 10000, 'tax_cents', 2000, 'tax_rate_percent', 20, 'recoverable_tax_cents', 2000),
    jsonb_build_object('gross_cents', 1100, 'net_cents', 1000, 'tax_cents', 100, 'tax_rate_percent', 10, 'recoverable_tax_cents', 100)))::text)) ->> 'purchase_id'), true);
select ok((pg_temp.as_json(pg_temp.u(3), format(
  'select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.pm'), 'a0000000-0000-4000-8000-000000000015'))::text) like '%several tax rates%', 'F: a receipt with several rates is refused until the posting model, its lines kept exactly');
select is((select sum(gross_cents)::int || '/' || count(*)::int from public.purchase_lines where purchase_id = current_setting('t.pm')::uuid), '13100/2',
  'F: a mixed-rate draft is stored line by line, summing exactly');
select ok((pg_temp.as_json(pg_temp.u(3), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000016',
  jsonb_build_object('kind', 'member_receipt', 'category', 'x', 'lines', jsonb_build_array(
    jsonb_build_object('gross_cents', 1000, 'net_cents', 900, 'tax_cents', 50)))::text))::text) like '%net plus tax%', 'F: net plus tax must be the gross amount');

-- ── G: supplier bills ──────────────────────────────────────────────────
select set_config('t.bill', pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000020',
  jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000257300a1', 'original_reference', 'F-2026-7',
    'due_on', '2026-11-30', 'lines', jsonb_build_array(jsonb_build_object('description', 'Rent', 'gross_cents', 90000)))::text))::text, true);
select is(current_setting('t.bill')::jsonb ->> 'state', 'draft', 'G: golden: the owner captures a supplier bill as a draft');
select set_config('t.pb', current_setting('t.bill')::jsonb ->> 'purchase_id', true);
select is((select concat_ws('/', d.kind, d.payer_kind, d.supplier_id::text, d.due_on::text) from public.purchase_documents d where d.id = current_setting('t.pb')::uuid),
  'bill/unpaid/00000000-0000-4000-8000-0000257300a1/2026-11-30', 'G: kind, creditor-side payer, supplier and due date are stored');
select is((select coalesce(l.tax_cents::text, 'null') || '/' || coalesce(l.net_cents::text, 'null') from public.purchase_lines l where l.purchase_id = current_setting('t.pb')::uuid),
  'null/null', 'G: a bill that states no tax keeps it unknown: partial, not zero');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.a'), current_setting('t.pb'))) #>> '{supplier,name}',
  'ACME Sarl', 'G: the detail names the supplier');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.pb'), 'a0000000-0000-4000-8000-000000000021'))::text) like '%payable exists%', 'G: a bill is not submitted yet: its payable is the next checkpoint');
select ok((pg_temp.as_json(pg_temp.u(3), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000022',
  '{"kind":"bill","lines":[{"gross_cents":100}]}'))::text) like '%not allowed to capture supplier bills%', 'G: a plain member cannot capture a bill');
select ok((pg_temp.as_json(pg_temp.u(4), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000023',
  '{"kind":"bill","lines":[{"gross_cents":100}]}'))::text) like '%not allowed to capture supplier bills%', 'G: nor an admin who was not given managePurchases');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000024',
  '{"kind":"bill","supplier_id":"00000000-0000-4000-8000-0000257300b1","lines":[{"gross_cents":100}]}'))::text) like '%unknown supplier%', 'G: a supplier of another workspace is unknown');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000025',
  '{"kind":"bill","currency":"USD","lines":[{"gross_cents":100}]}'))::text) like '%currency of the space%', 'G: another currency than the space is refused');
select is((select count(*)::int from public.purchase_documents where kind = 'bill' and workspace_id = current_setting('t.a')::uuid), 1, 'G: readback: only the owner''s bill exists');
update public.workspaces set role_permissions = jsonb_build_object('member', jsonb_build_array('managePurchases')) where id = current_setting('t.a')::uuid;
select is((pg_temp.as_json(pg_temp.u(3), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000026',
  '{"kind":"bill","lines":[{"gross_cents":100}]}')) ->> 'state'), 'draft', 'G: positive control: a role given managePurchases captures a bill');
update public.workspaces set role_permissions = '{}'::jsonb where id = current_setting('t.a')::uuid;
update public.workspaces set feature_flags = feature_flags || '{"purchases": false}' where id = current_setting('t.a')::uuid;
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'), 'a0000000-0000-4000-8000-000000000027',
  '{"kind":"bill","lines":[{"gross_cents":100}]}'))::text) like '%switched off%', 'G: with the flag off nothing new is captured');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.a'), current_setting('t.pb'))) ->> 'state', 'draft',
  'G: but the stored document stays readable');
update public.workspaces set feature_flags = feature_flags || '{"purchases": true}' where id = current_setting('t.a')::uuid;

select ok((pg_temp.owner_err(format('insert into public.purchase_lines (workspace_id, purchase_id, line_no, gross_cents) select %L, id, 9, 1 from public.purchase_documents where id = %L',
    current_setting('t.b'), current_setting('t.pb')))) like '%foreign key%', 'G: a line cannot carry another workspace than its document');

-- ── H: linking an invoice ──────────────────────────────────────────────
insert into public.einvoice_inbox (id, workspace_id, syntax, document_hash, source_xml, invoice_number, issue_date, currency, supplier_name, net_cents, tax_cents, gross_cents) values
 ('00000000-0000-4000-8000-000025730f01', current_setting('t.a')::uuid, 'ubl', repeat('a', 64), '<i/>', 'F-2026-7', '2026-10-01', 'EUR', 'ACME Sarl', 75000, 15000, 90000),
 ('00000000-0000-4000-8000-000025730f02', current_setting('t.a')::uuid, 'ubl', repeat('b', 64), '<i/>', 'F-2026-8', '2026-10-01', 'EUR', 'ACME Sarl', 10000, 2000, 12000),
 ('00000000-0000-4000-8000-000025730f03', current_setting('t.a')::uuid, 'ubl', repeat('c', 64), '<i/>', 'F-2026-9', '2026-10-01', 'USD', 'ACME Sarl', 10000, 2000, 12000),
 ('00000000-0000-4000-8000-000025730f04', current_setting('t.b')::uuid, 'ubl', repeat('d', 64), '<i/>', 'F-B-1', '2026-10-01', 'EUR', 'Other Ltd', 10000, 2000, 12000);
select set_config('t.l1', pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f01', 'a0000000-0000-4000-8000-000000000030'))::text, true);
select is(current_setting('t.l1')::jsonb ->> 'source_kind', 'inbox', 'H: golden: a manager links a received invoice to the bill');
select is((select original_hash from public.purchase_sources where source_id = '00000000-0000-4000-8000-000025730f01'), repeat('a', 64),
  'H: the link keeps the invoice''s own hash as evidence');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f01', 'a0000000-0000-4000-8000-000000000030')),
  current_setting('t.l1')::jsonb, 'H: replaying the link returns the same result');
select is((select count(*)::int from public.purchase_sources where purchase_id = current_setting('t.pb')::uuid), 1, 'H: and links it once');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 2, %L)',
  current_setting('t.a'), current_setting('t.p1'), '00000000-0000-4000-8000-000025730f01', 'a0000000-0000-4000-8000-000000000031'))::text) like '%already linked to another purchase%', 'H: an invoice cannot fund a second purchase');
update public.einvoice_inbox set status = 'matched', matched_event_id = current_setting('t.e4')::uuid, decided_at = now()
 where id = '00000000-0000-4000-8000-000025730f02';
select is((select count(*)::int from public.purchase_sources s join public.purchase_sources o on o.purchase_id = s.purchase_id
            where s.source_id = '00000000-0000-4000-8000-000025730f02' and o.source_id = current_setting('t.e4')::uuid), 1,
  'H: an invoice matched to an expense joins the purchase of THAT expense as evidence');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f02', 'a0000000-0000-4000-8000-000000000032'))::text) like '%already funds another expense%', 'H: it cannot also be linked to a bill (no second expense for one acquisition)');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f03', 'a0000000-0000-4000-8000-000000000033'))::text) like '%another currency%', 'H: another currency is refused');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f04', 'a0000000-0000-4000-8000-000000000034'))::text) like '%unknown supplier invoice%', 'H: an invoice of another workspace is unknown');
select ok((pg_temp.as_json(pg_temp.u(3), format('select public.link_purchase_source_v1(%L, %L, ''inbox'', %L, 1, %L)',
  current_setting('t.a'), current_setting('t.pb'), '00000000-0000-4000-8000-000025730f02', 'a0000000-0000-4000-8000-000000000035'))::text) like '%not allowed to link%', 'H: a plain member cannot link');
select is((select count(*)::int from public.purchase_sources where workspace_id = current_setting('t.a')::uuid and source_kind = 'inbox'), 2,
  'H: readback: two invoice links in all, none added by a refusal');

-- ── I: who reads what, no client write ─────────────────────────────────
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.purchase_documents where submitter_member_id <> pg_temp.mem(2, 't.a')), 0,
  'I: a member sees none of the others'' documents');
select ok((select count(*) from public.purchase_documents) >= 1, 'I: positive control: and sees their own');
select is((select count(*)::int from public.purchase_lines l where not exists (
  select 1 from public.purchase_documents d where d.id = l.purchase_id and d.submitter_member_id = pg_temp.mem(2, 't.a'))), 0, 'I: nor their lines');
select is((select count(*)::int from public.purchase_sources), (select count(*)::int from public.purchase_sources s
  join public.purchase_documents d on d.id = s.purchase_id), 'I: nor the evidence of a document they cannot read');
select is(pg_temp.as_err(pg_temp.u(2), 'insert into public.purchase_documents (workspace_id, kind, currency, submitter_member_id, payer_kind) values (gen_random_uuid(), ''bill'', ''EUR'', gen_random_uuid(), ''unpaid'')'),
  'permission denied for table purchase_documents', 'I: no client can write a document directly');
select is(pg_temp.as_err(pg_temp.u(1), format('update public.purchase_documents set state = ''approved'' where id = %L', current_setting('t.pb'))),
  'permission denied for table purchase_documents', 'I: not even the owner can forge a state');
select is(pg_temp.as_err(pg_temp.u(1), 'select * from public.purchase_requests'), 'permission denied for table purchase_requests',
  'I: the request ledger is not readable');
select is(pg_temp.as_json(pg_temp.u(3), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.a'), current_setting('t.p1'))) ->> 'error', 'unknown purchase',
  'I: another member''s detail is refused');
select is(pg_temp.as_json(pg_temp.u(2), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.a'), current_setting('t.p1'))) ->> 'state', 'approved',
  'I: positive control: one''s own detail is returned');
select is(pg_temp.as_json(pg_temp.u(5), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.b'), current_setting('t.p1'))) ->> 'error', 'unknown purchase',
  'I: a foreign workspace''s owner asking under their own workspace finds nothing');
select is(pg_temp.as_json(pg_temp.u(5), format('select public.purchase_detail_v1(%L, %L)', current_setting('t.a'), current_setting('t.p1'))) ->> 'error', 'unknown purchase',
  'I: nor under the workspace of the document');
select pg_temp.as_err(pg_temp.u(5), format('select public.submit_expense(%L, 700, ''tea'', ''Tea'', null, null)', current_setting('t.b')));
select pg_temp.act_as(pg_temp.u(5));
select is((select count(*)::int from public.purchase_documents where workspace_id <> current_setting('t.b')::uuid), 0,
  'I: the owner of B reads no document of A');
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.b')::uuid), 1,
  'I: positive control: and reads their own workspace''s document');
select pg_temp.act_as(pg_temp.u(1));
select ok((select count(*) from public.purchase_documents where workspace_id = current_setting('t.a')::uuid) >= 7, 'I: positive control: the owner of A reads the workspace''s documents');
select pg_temp.act_as(pg_temp.u(4));
select ok((select count(*) from public.purchase_documents) >= 7, 'I: an admin reads them through viewFinances');
reset role;

-- ── J: the catalogues ──────────────────────────────────────────────────
select ok('managePurchases' = any(public.role_permission_catalog()), 'J: managePurchases is in the permission catalogue');
select is(public.feature_registry() -> 'purchases' ->> 'parent', 'moneyTab', 'J: purchases sits under moneyTab');
select is(public.feature_registry() -> 'purchases' ->> 'default', 'false', 'J: and is off by default');
select is(pg_temp.as_json(pg_temp.u(4), format('select to_jsonb(public.has_permission(%L, ''managePurchases''))', current_setting('t.a'))), 'false'::jsonb,
  'J: an admin does not hold managePurchases by default');
select is(pg_temp.as_json(pg_temp.u(1), format('select to_jsonb(public.has_permission(%L, ''managePurchases''))', current_setting('t.a'))), 'true'::jsonb,
  'J: an owner holds it');

select * from finish();
rollback;
