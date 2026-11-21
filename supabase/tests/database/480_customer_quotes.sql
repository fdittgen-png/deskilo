-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4166 (0828, cut 1): a customer quote, as the real roles. The issuer drafts,
-- sends (freezes) and amends; a finance reader reads and writes nothing; a
-- coworker, a stranger and a delegated token get no quote at all. A sent revision
-- never changes; an accepted revision is what the ISSUER recorded; expiry stops a
-- late acceptance and never an accepted quote; one quote makes ONE initial invoice
-- whatever the request id; a changed invoice context needs its reviewed digest; and
-- nothing financial exists until the invoice is issued by #4165's issuer.
begin;
select plan(82);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004166' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'quote' || n || '@example.test', '', now(), now(), now() from generate_series(1, 6) n;
-- 1 owner and issuer, 2 finance reader (admin holding only viewFinances), 3 coworker,
-- 4 stranger (owner of another business), 5 a second issuer
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address, role_permissions)
values (pg_temp.u(101), 'Quotes 4166', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true, "standaloneInvoicing": true, "customerQuotes": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas', '{"admin": ["viewFinances"], "member": ["makeReservations"]}'),
       (pg_temp.u(102), 'Other 4166', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"invoicing": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active', '2026-01-01'),
       (pg_temp.u(205), pg_temp.u(101), pg_temp.u(5), true, true, 'active', '2026-01-01');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01')
on conflict do nothing;

create function pg_temp.as_user(n int, p_sql text, p_claims jsonb default '{}'::jsonb) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::jsonb || p_claims)::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'no error'; exception when others then return sqlstate; end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.line(p_qty text, p_price text, p_id uuid default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('line_id', p_id, 'description', 'Consulting', 'quantity', p_qty,
    'unit_price', p_price, 'basis', 'net', 'supply', 'general', 'base_quantity', '1',
    'unit', jsonb_build_object('code', 'hour', 'label', 'h', 'un_ece_code', 'HUR')))
$$;
-- the money the quotes must leave alone
create function pg_temp.books() returns text language sql as $$
  select (select count(*) from public.invoices where workspace_id = pg_temp.u(101))::text || '|' ||
         (select count(*) from public.ledger_entries where workspace_id = pg_temp.u(101))::text || '|' ||
         coalesce((select next_value::text from public.number_sequences
                    where workspace_id = pg_temp.u(101) and journal = 'invoice'), '-')
$$;

-- the customer: a billing customer with no account, billed as a French business
select set_config('t.customer', pg_temp.as_user(1, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Atelier Lumi", "street": "1 rue du Port", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR12345678901"}'::jsonb, 'business')::text$s$,
  pg_temp.u(101))), false);
select ok(current_setting('t.customer') ~ '^[0-9a-f-]{36}$', 'a billing customer with no account is the quote''s customer');
select set_config('t.books', pg_temp.books(), false);

-- ── drafting ──
select set_config('q.a', pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, 'PO-7', '', 'First offer', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'), jsonb_build_array(pg_temp.line('1.5', '80'))::text)), false);
select is(current_setting('q.a')::jsonb ->> 'revision' || '|' || (current_setting('q.a')::jsonb ->> 'version'), '1|1',
  'the issuer drafts a quote: revision 1, version 1');
select is((select status from public.customer_quotes where id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid), 'draft',
  'it is a draft, with no reference yet');
select ok((select reference is null from public.customer_quotes where id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid),
  'and takes no number before it is sent');
select ok((select (lines -> 0 ->> 'line_id') is not null from public.customer_quote_revisions
            where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid), 'every line gets a stable line_id');
select is(pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, %L, 5, %L, null, null, '', '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), current_setting('t.customer'),
  jsonb_build_array(pg_temp.line('1.5', '80'))::text)), 'ERR DKQ02', 'a stale draft version is refused');
select set_config('q.a', pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, %L, 1, %L, null, null, 'PO-7', '', 'First offer', %L::jsonb)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), current_setting('t.customer'),
  (select lines::text from public.customer_quote_revisions where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid))), false);
select is(current_setting('q.a')::jsonb ->> 'version', '2', 'an edit at the version read bumps it, keeping the line ids');
select is(pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', '', '[{"description": ""}]'::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'))), 'ERR DKQ06', 'an incomplete line is refused with its missing facts');
select is(pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), pg_temp.u(204), jsonb_build_array(pg_temp.line('1', '1'))::text)), 'ERR DKI01',
  'a customer that is not the business''s own is refused');

-- ── who may ──
select is(pg_temp.as_user(2, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'), jsonb_build_array(pg_temp.line('1', '1'))::text)) <> 'ok', true,
  'a finance reader does not draft');
select is(pg_temp.as_user(2, format($s$select jsonb_array_length(public.customer_quotes_v1(%L))::text$s$, pg_temp.u(101))), '1',
  'but reads the quotes');
select is(pg_temp.as_user(3, format($s$select jsonb_array_length(public.customer_quotes_v1(%L))::text$s$, pg_temp.u(101))), 'ERR DKN01',
  'a coworker reads no quote');
select is(pg_temp.as_user(4, format($s$select jsonb_array_length(public.customer_quotes_v1(%L))::text$s$, pg_temp.u(101))), 'ERR DKN01',
  'nor a stranger');
select is(pg_temp.as_user(3, $s$select count(*)::text from public.customer_quotes$s$), '0', 'the raw tables show a coworker nothing');
select is(pg_temp.as_user(2, $s$select count(*)::text from public.customer_quotes$s$), '1', 'and a finance reader the quote');
select is(pg_temp.as_user(1, $s$select count(*)::text from public.customer_quotes$s$, '{"client_id": "assistant"}'::jsonb), '0',
  'a delegated token reads no row');
select is(pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'), jsonb_build_array(pg_temp.line('1', '1'))::text),
  '{"client_id": "assistant"}'::jsonb), 'ERR DKQ07', 'an assistant does not draft a quote');
select is(pg_temp.as_user(1, format($s$insert into public.customer_quotes (workspace_id, subject_member_id) values (%L, %L) returning id::text$s$,
  pg_temp.u(101), current_setting('t.customer'))), 'ERR 42501', 'no client writes a quote directly: the tables are written by the commands');

-- ── sending freezes ──
select set_config('s.a', pg_temp.as_user(1, format($s$select public.send_customer_quote_v1(%L, %L, 1, 2)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), false);
select ok(current_setting('s.a')::jsonb ->> 'reference' like 'QUO-%', 'the first send takes a reference from the quote series: '
  || (current_setting('s.a')::jsonb ->> 'reference'));
select is(pg_temp.books(), current_setting('t.books'),
  'a sent quote is no receivable: no invoice, no ledger entry, no invoice number');
select is((select (frozen #>> '{totals,total_cents}') || '|' || status from public.customer_quote_revisions
            where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid), '14400|sent',
  '1.5 h at 80.00 net, 20 %: the real issuer froze 144.00');
select is(pg_temp.err(format($s$update public.customer_quote_revisions set notes = 'x' where quote_id = %L$s$,
  (current_setting('q.a')::jsonb ->> 'quote_id'))), 'DKQ05', 'a sent revision cannot be edited in place');
select is(pg_temp.err(format($s$delete from public.customer_quote_revisions where quote_id = %L$s$,
  (current_setting('q.a')::jsonb ->> 'quote_id'))), 'DKQ05', 'nor deleted');
select is(pg_temp.err(format($s$delete from public.customer_quotes where id = %L$s$, (current_setting('q.a')::jsonb ->> 'quote_id'))),
  'DKQ05', 'a quote that was sent is never deleted');
select is(pg_temp.as_user(1, format($s$select (public.send_customer_quote_v1(%L, %L, 1, 2))->>'replayed'$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'true', 'sending again answers the same frozen revision');
select is((select count(*) from public.customer_quotes where reference is not null and workspace_id = pg_temp.u(101)), 1::bigint,
  'and takes no second reference');
select is(pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, %L, 2, %L, null, null, '', '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), current_setting('t.customer'),
  jsonb_build_array(pg_temp.line('9', '9'))::text)), 'ERR DKQ03', 'a sent quote has no draft to edit until it is amended');

-- ── amending ──
select set_config('line.id', (select lines -> 0 ->> 'line_id' from public.customer_quote_revisions
                              where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid and revision = 1), false);
select set_config('r.b', pg_temp.as_user(1, format($s$select public.amend_customer_quote_v1(%L, %L)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), false);
select is(current_setting('r.b')::jsonb ->> 'revision', '2', 'an amendment is revision 2');
select is((select lines -> 0 ->> 'line_id' from public.customer_quote_revisions
            where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid and revision = 2), current_setting('line.id'),
  'and keeps the line identities of revision 1');
select set_config('r.b', pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, %L, 1, %L, null, null, 'PO-7', '', 'Revised', %L::jsonb)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), current_setting('t.customer'),
  jsonb_build_array(pg_temp.line('2', '80', current_setting('line.id')::uuid))::text)), false);
select is(pg_temp.as_user(1, format($s$select public.amend_customer_quote_v1(%L, %L)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ03', 'only one amendment is open at a time');
select ok(pg_temp.as_user(1, format($s$select public.send_customer_quote_v1(%L, %L, 2, 2)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))) <> 'ERR DKQ02', 'revision 2 is sent at its version');
select is((select count(*) from public.customer_quote_revisions
            where quote_id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid and superseded_at is not null), 1::bigint,
  'revision 1 is superseded, its content untouched');
select is((select reference from public.customer_quotes where id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid),
  current_setting('s.a')::jsonb ->> 'reference', 'the quote keeps its one reference across revisions');

-- ── a decision: what the issuer recorded ──
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', current_date, 'email', 'mail')::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ03', 'a superseded revision is not accepted');
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 2, 'accepted', current_date + 1, 'email', 'mail')::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ06', 'a decision cannot be dated in the future');
select is(pg_temp.as_user(2, format($s$select public.record_customer_quote_decision_v1(%L, %L, 2, 'accepted', current_date, 'email', 'mail')::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR P0001', 'a finance reader records no decision');
select is(pg_temp.as_user(1, format($s$select (public.record_customer_quote_decision_v1(%L, %L, 2, 'accepted', current_date, 'received_outside_app', 'signed mail of the day')::jsonb)->>'recorded_by_issuer'$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'true', 'revision 2 is accepted, and the record says the issuer recorded it');
select is((select status from public.customer_quotes where id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid), 'accepted', 'the quote is accepted');
select is(pg_temp.err(format($s$update public.customer_quote_decisions set decision = 'declined' where quote_id = %L$s$,
  (current_setting('q.a')::jsonb ->> 'quote_id'))), 'DKQ05', 'a decision is never changed');
select is(pg_temp.as_user(1, format($s$select public.amend_customer_quote_v1(%L, %L)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ03', 'an accepted quote is not amended');
select is(pg_temp.as_user(1, format($s$select public.cancel_customer_quote_v1(%L, %L)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ03', 'nor cancelled');
select is(pg_temp.books(), current_setting('t.books'), 'drafting, sending, amending and accepting touched no invoice, ledger entry or number');

-- ── expiry stops a late acceptance, never an accepted quote ──
create temp table late as select gen_random_uuid() as quote_id, gen_random_uuid() as rev_id;
insert into public.customer_quotes (id, workspace_id, subject_member_id, reference, status)
select quote_id, pg_temp.u(101), current_setting('t.customer')::uuid, 'QUO-LATE', 'sent' from late;
insert into public.customer_quote_revisions (id, quote_id, workspace_id, revision, status, issued_on, valid_until, lines,
                                              frozen, content_digest, sent_at, sent_by_member_id)
select rev_id, quote_id, pg_temp.u(101), 1, 'sent', current_date - 20, current_date - 3,
       jsonb_build_array(pg_temp.line('1', '10', gen_random_uuid())), '{"totals": {"total_cents": 1200}}'::jsonb, 'x', now(), pg_temp.u(201)
  from late;
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', current_date, 'verbal', '')::text$s$,
  pg_temp.u(101), (select quote_id from late))), 'ERR DKQ04', 'an offer past its validity is not accepted late');
select ok((pg_temp.as_user(1, format($s$select (public.customer_quote_v1(%L, %L)->>'expired')$s$, pg_temp.u(101), (select quote_id from late)))) = 'true',
  'its expiry is derived from the validity and the business clock');
-- ── the conversion ──
select set_config('c.a', pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), false);
select is(current_setting('c.a')::jsonb #> '{preview,missing}', '[]'::jsonb, 'the real preview finds nothing missing');
select is(current_setting('c.a')::jsonb #>> '{preview,preview,total_cents}', '19200', '2 h at 80.00 net, 20 %: the invoice would be 192.00');
select is(current_setting('c.a')::jsonb ->> 'context_changed', 'false', 'and it equals what was accepted');
select is(pg_temp.books(), current_setting('t.books'), 'preparing the conversion issues nothing');
-- a draft that came from a quote changes only through the quote (fix 1, 2)
select is(pg_temp.as_user(1, format($s$select public.save_standalone_invoice_draft_v1(%L, %L, %s, %L, current_date, current_date + 30, '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('c.a')::jsonb ->> 'draft_id', current_setting('c.a')::jsonb ->> 'draft_revision',
  current_setting('t.customer'), jsonb_build_array(pg_temp.line('99', '99'))::text)), 'ERR DKQ09',
  'the invoice draft of a quote cannot be edited in the invoice editor');
select is(pg_temp.as_user(1, format($s$select public.issue_standalone_invoice_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041669'::uuid)::text$s$,
  pg_temp.u(101), current_setting('c.a')::jsonb ->> 'draft_id', current_setting('c.a')::jsonb ->> 'draft_revision')), 'ERR DKQ09',
  'nor issued directly: only the quote converts it');
select is(pg_temp.err(format($s$update public.standalone_invoice_drafts set lines = '[]'::jsonb where id = %L$s$,
  current_setting('c.a')::jsonb ->> 'draft_id')), 'DKQ09', 'nor changed by any other write');
select is(pg_temp.books(), current_setting('t.books'), 'and nothing was issued by those attempts');
select is(pg_temp.as_user(2, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))) <> 'ok', true, 'a finance reader does not convert');
select set_config('c.i', pg_temp.as_user(1, format(
  $s$select public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041661'::uuid)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), (current_setting('c.a')::jsonb ->> 'draft_revision'))), false);
select is(current_setting('c.i')::jsonb ->> 'replayed', 'false', 'the accepted revision is converted into one invoice');
select is(pg_temp.books(), '1|0|2', 'one invoice, no ledger entry of its own yet, one number taken: the invoice''s');
select is((select status from public.customer_quotes where id = (current_setting('q.a')::jsonb ->> 'quote_id')::uuid), 'converted', 'the quote is converted');
select is((select (lines -> 0 -> 'commercial' ->> 'line_id') from public.invoices
            where id = (current_setting('c.i')::jsonb ->> 'invoice_id')::uuid), current_setting('line.id'),
  'the invoice line carries the quote line''s identity');
select is(pg_temp.as_user(5, format(
  $s$select (public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041662'::uuid))->>'invoice_id'$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'), (current_setting('c.a')::jsonb ->> 'draft_revision'))),
  current_setting('c.i')::jsonb ->> 'invoice_id', 'another actor with another request id gets the same invoice');
select is(pg_temp.books(), '1|0|2', 'and no second invoice or number');
select is(pg_temp.err(format($s$insert into public.customer_quote_conversions (quote_id, workspace_id, revision_id, draft_id, invoice_id, converted_by_member_id)
   select quote_id, workspace_id, revision_id, gen_random_uuid(), (select id from public.invoices limit 1), converted_by_member_id
     from public.customer_quote_conversions where quote_id = %L$s$, (current_setting('q.a')::jsonb ->> 'quote_id'))), '23505',
  'a second conversion of the quote is impossible in the database, whatever the request');
select is(pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ03', 'a converted quote is not prepared again');


-- accepted in time, invoiced after the offer's date: expiry does not undo an agreement; and
-- an invoice whose context differs from the frozen one needs its reviewed digest
insert into public.customer_quote_decisions (quote_id, workspace_id, revision_id, decision, decided_on, source, recorded_by_member_id)
select quote_id, pg_temp.u(101), rev_id, 'accepted', current_date - 8, 'verbal', pg_temp.u(201) from late;
update public.customer_quotes set status = 'accepted' where id = (select quote_id from late);
select set_config('c.l', pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (select quote_id from late))), false);
select is(current_setting('c.l')::jsonb ->> 'context_changed', 'true',
  'an invoice that differs from the frozen offer says so: the difference is the preview''s');
select is(pg_temp.as_user(1, format($s$select public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041663'::uuid)::text$s$,
  pg_temp.u(101), (select quote_id from late), current_setting('c.l')::jsonb ->> 'draft_revision')), 'ERR DKQ08',
  'it is not issued without the reviewed digest of exactly what would be issued');
select ok(pg_temp.as_user(1, format($s$select (public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041663'::uuid, %L))->>'invoice_id'$s$,
  pg_temp.u(101), (select quote_id from late), current_setting('c.l')::jsonb ->> 'draft_revision',
  current_setting('c.l')::jsonb ->> 'review_digest')) ~ '^[0-9a-f-]{36}$',
  'with it, an offer accepted before its date is invoiced after it');
select is((select count(*) from public.invoices where workspace_id = pg_temp.u(101)), 2::bigint, 'two quotes, two invoices');

-- a declined or cancelled quote is not converted
create temp table gone as select gen_random_uuid() as quote_id;
insert into public.customer_quotes (id, workspace_id, subject_member_id, reference, status)
select quote_id, pg_temp.u(101), current_setting('t.customer')::uuid, 'QUO-GONE', 'cancelled' from gone;
select is(pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (select quote_id from gone))), 'ERR DKQ03', 'a cancelled quote is not converted');

-- ── what the review found ──
-- a second sent offer whose validity ended three days ago
create temp table late2 as select gen_random_uuid() as quote_id, gen_random_uuid() as rev_id;
insert into public.customer_quotes (id, workspace_id, subject_member_id, reference, status)
select quote_id, pg_temp.u(101), current_setting('t.customer')::uuid, 'QUO-LATE2', 'sent' from late2;
insert into public.customer_quote_revisions (id, quote_id, workspace_id, revision, status, issued_on, valid_until, lines,
                                              frozen, content_digest, sent_at, sent_by_member_id)
select rev_id, quote_id, pg_temp.u(101), 1, 'sent', current_date - 20, current_date - 3,
       jsonb_build_array(pg_temp.line('1', '10', gen_random_uuid())), '{"totals": {"total_cents": 1200}}'::jsonb, 'x', now(), pg_temp.u(201)
  from late2;
-- an acceptance dated inside the validity but recorded after it ended is refused: expiry is
-- read on the business's clock when the issuer records it, not only on the typed date
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', current_date - 5, 'verbal', '')::text$s$,
  pg_temp.u(101), (select quote_id from late2))), 'ERR DKQ04', 'a late recording of an acceptance dated in time is refused');
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'declined', current_date - 5, 'carrier pigeon', '')::text$s$,
  pg_temp.u(101), (select quote_id from late2))), 'ERR DKQ06', 'the source of a decision is checked first, with a code of its own');

-- a quote whose invoice draft was issued before the guard existed is not left stuck: prepare refuses the
-- issued draft and convert records the conversion from the invoice that was issued
select set_config('q.s', pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', 'Stuck', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'), jsonb_build_array(pg_temp.line('1', '50'))::text)), false);
select pg_temp.as_user(1, format($s$select public.send_customer_quote_v1(%L, %L, 1, 1)::text$s$, pg_temp.u(101), current_setting('q.s')::jsonb ->> 'quote_id'));
select pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', current_date, 'email', '')::text$s$,
  pg_temp.u(101), current_setting('q.s')::jsonb ->> 'quote_id'));
select set_config('c.s', pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), current_setting('q.s')::jsonb ->> 'quote_id')), false);
-- (the old way: the draft issued by the invoice issuer itself, as the guard now forbids)
select set_config('deskilo.quote_conversion', current_setting('c.s')::jsonb ->> 'draft_id', true);
select set_config('i.s', pg_temp.as_user(1, format($s$select (public.issue_standalone_invoice_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041664'::uuid))->>'invoice_id'$s$,
  pg_temp.u(101), current_setting('c.s')::jsonb ->> 'draft_id', current_setting('c.s')::jsonb ->> 'draft_revision')), false);
select set_config('deskilo.quote_conversion', '', true);
select is(pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), current_setting('q.s')::jsonb ->> 'quote_id')), 'ERR DKQ03', 'a quote whose draft was already issued is not prepared again');
select is(pg_temp.as_user(1, format($s$select (public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041665'::uuid))->>'invoice_id'$s$,
  pg_temp.u(101), current_setting('q.s')::jsonb ->> 'quote_id', current_setting('c.s')::jsonb ->> 'draft_revision')),
  current_setting('i.s'), 'the conversion is recorded from the invoice that was issued');
select is((select status from public.customer_quotes where id = (current_setting('q.s')::jsonb ->> 'quote_id')::uuid), 'converted', 'and the quote is no longer stuck');
select is((select count(*) from public.invoices where workspace_id = pg_temp.u(101)), 3::bigint, 'with no second invoice');

-- quotes are a feature: switched off, no one reads or writes them
update public.workspaces set feature_flags = feature_flags || '{"customerQuotes": false}'::jsonb where id = pg_temp.u(101);
select is(pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_date, current_date + 30)::text$s$,
  pg_temp.u(101), (current_setting('q.a')::jsonb ->> 'quote_id'))), 'ERR DKQ10', 'with the feature off the issuer cannot act on a quote');
select is(pg_temp.as_user(1, $s$select count(*)::text from public.customer_quotes$s$), '0', 'and the raw tables show nothing');
update public.workspaces set feature_flags = feature_flags || '{"customerQuotes": true}'::jsonb where id = pg_temp.u(101);
select is(pg_temp.as_user(1, $s$select count(*)::text from public.customer_quotes$s$) <> '0', true, 'switched on again, the quotes are back');

-- ── a business takes its quotes with it (0843) ──
-- Another business with a sent quote, its recorded decision and the invoice draft its
-- conversion prepared: every direct delete or change is refused as before, and deleting the
-- business takes all of them. (A converted quote keeps its invoice, which is retained, and
-- the invoice refuses the deletion; that is the invoices' rule, not the quotes'.)
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(103), 'Gone 4166', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(206), pg_temp.u(103), pg_temp.u(6), false, false, 'active', '2026-01-01');
insert into public.customer_quotes (id, workspace_id, subject_member_id, reference, status)
values (pg_temp.u(401), pg_temp.u(103), pg_temp.u(206), 'QUO-GONE', 'accepted');
insert into public.customer_quote_revisions (id, quote_id, workspace_id, revision, status, issued_on, valid_until, lines,
                                              frozen, content_digest, sent_at, sent_by_member_id)
values (pg_temp.u(402), pg_temp.u(401), pg_temp.u(103), 1, 'sent', current_date - 5, current_date + 20, '[]'::jsonb,
        '{"totals": {"total_cents": 100}}'::jsonb, 'x', now(), pg_temp.u(206));
insert into public.customer_quote_decisions (quote_id, workspace_id, revision_id, decision, decided_on, source, recorded_by_member_id)
values (pg_temp.u(401), pg_temp.u(103), pg_temp.u(402), 'accepted', current_date, 'verbal', pg_temp.u(206));
insert into public.standalone_invoice_drafts
select * from jsonb_populate_record(null::public.standalone_invoice_drafts, jsonb_build_object(
  'id', pg_temp.u(403), 'workspace_id', pg_temp.u(103), 'subject_member_id', pg_temp.u(206), 'revision', 1, 'status', 'draft',
  'service_date', current_date, 'due_on', current_date + 30, 'buyer_reference', '', 'purchase_order', '',
  'lines', '[]'::jsonb, 'origin_quote_id', pg_temp.u(401)));
select throws_ok(format($s$delete from public.customer_quotes where id = %L$s$, pg_temp.u(401)), 'DKQ05', null,
  'a sent quote is still never deleted on its own');
select throws_ok(format($s$delete from public.customer_quote_revisions where id = %L$s$, pg_temp.u(402)), 'DKQ05', null,
  'nor its sent revision');
select throws_ok(format($s$delete from public.customer_quote_decisions where quote_id = %L$s$, pg_temp.u(401)), 'DKQ05', null,
  'nor the decision the issuer recorded');
select throws_ok(format($s$delete from public.standalone_invoice_drafts where id = %L$s$, pg_temp.u(403)), 'DKQ09', null,
  'nor the invoice draft that came from the quote');
select lives_ok(format($s$delete from public.workspaces where id = %L$s$, pg_temp.u(103)),
  'a business with a sent quote, its decision and a prepared conversion can be deleted');
select is((select (select count(*) from public.customer_quotes where workspace_id = pg_temp.u(103))
            + (select count(*) from public.customer_quote_revisions where workspace_id = pg_temp.u(103))
            + (select count(*) from public.customer_quote_decisions where workspace_id = pg_temp.u(103))
            + (select count(*) from public.standalone_invoice_drafts where workspace_id = pg_temp.u(103)))::int, 0,
  'its quotes, revisions, decision and draft went with it');
select ok(exists (select 1 from public.customer_quotes where workspace_id = pg_temp.u(101)),
  'another business keeps its quotes');

select * from finish();
rollback;
