-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4178 (0852, F4): service fulfilment, as the real roles. An accepted quote line, an
-- issued invoice line or a direct commitment becomes ONE engagement, followed
-- ordered -> started -> done or cancelled with a reason, every step kept; the quote, the
-- invoice and the payments beside it are read and never changed. One engagement per
-- canonical source line (an invoice that billed a quote resolves to the quote's); a step
-- is one request (replayed, or refused when its payload changed) at an expected revision
-- (a stale one is refused with the current revision); the issuer writes, a finance reader
-- reads, a coworker, a stranger, a customer and a delegated token get nothing.
begin;
select plan(88);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004178' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000417' || lpad(n::text, 5, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'ful' || n || '@example.test', '', now(), now(), now() from generate_series(1, 8) n;
-- 1 owner and issuer, 2 finance reader (admin holding only viewFinances), 3 coworker,
-- 4 stranger (owner of another business), 5 a second issuer, 6 a customer with an account,
-- 7 owner of a business that is erased at the end
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address, role_permissions)
values (pg_temp.u(101), 'Fulfilment 4178', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "billingCustomers": true, "customerQuotes": true, "serviceFulfilment": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas', '{"admin": ["viewFinances"], "member": ["makeReservations"]}'),
       (pg_temp.u(102), 'Other 4178', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
        '{"invoicing": true, "standaloneInvoicing": true, "billingCustomers": true, "customerQuotes": true, "serviceFulfilment": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas', '{}'),
       (pg_temp.u(103), 'Erased 4178', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(7),
        '{"invoicing": true, "billingCustomers": true, "serviceFulfilment": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas', '{"admin": ["issueInvoices", "viewFinances", "manageBillingCustomers"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active', '2026-01-01'),
       (pg_temp.u(205), pg_temp.u(101), pg_temp.u(5), true, true, 'active', '2026-01-01'),
       (pg_temp.u(206), pg_temp.u(101), pg_temp.u(6), false, false, 'active', '2026-01-01'),
       (pg_temp.u(207), pg_temp.u(103), pg_temp.u(7), false, true, 'active', '2026-01-01');
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
-- the answer of a command, or its error state, read as jsonb text
create function pg_temp.open_line(n int, p_ws uuid, p_req int, p_kind text, p_id uuid, p_line uuid,
                                  p_claims jsonb default '{}'::jsonb) returns text language sql as $f$
  select pg_temp.as_user(n, format($s$select public.open_service_fulfilment_v1(%L, %L, %L::jsonb)::text$s$,
    p_ws, pg_temp.rq(p_req), jsonb_build_object('kind', p_kind, 'id', p_id, 'line_id', p_line)::text), p_claims)
$f$;
create function pg_temp.open_direct(n int, p_ws uuid, p_req int, p_scope jsonb) returns text language sql as $f$
  select pg_temp.as_user(n, format($s$select public.open_service_fulfilment_v1(%L, %L, '{"kind": "direct"}'::jsonb, %L::jsonb)::text$s$,
    p_ws, pg_temp.rq(p_req), p_scope::text))
$f$;
create function pg_temp.step(n int, p_ws uuid, p_f text, p_rev int, p_to text, p_reason text, p_req int,
                             p_claims jsonb default '{}'::jsonb) returns text language sql as $f$
  select pg_temp.as_user(n, format($s$select public.transition_service_fulfilment_v1(%L, %L, %s, %L, %L, %L)::text$s$,
    p_ws, p_f, p_rev, p_to, p_reason, pg_temp.rq(p_req)), p_claims)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.line(p_qty text, p_price text, p_desc text, p_id uuid default null) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('line_id', p_id, 'description', p_desc, 'quantity', p_qty,
    'unit_price', p_price, 'basis', 'net', 'supply', 'general', 'base_quantity', '1',
    'unit', jsonb_build_object('code', 'hour', 'label', 'h', 'un_ece_code', 'HUR')))
$$;
-- the money the engagements must leave alone
create function pg_temp.books() returns text language sql as $$
  select (select count(*) from public.invoices where workspace_id = pg_temp.u(101))::text || '|' ||
         (select count(*) from public.ledger_entries where workspace_id = pg_temp.u(101))::text || '|' ||
         (select count(*) from public.invoice_matches where workspace_id = pg_temp.u(101))::text || '|' ||
         coalesce((select next_value::text from public.number_sequences
                    where workspace_id = pg_temp.u(101) and journal = 'invoice'), '-')
$$;

select set_config('t.customer', pg_temp.as_user(1, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Atelier Lumi", "street": "1 rue du Port", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR12345678901"}'::jsonb, 'business')::text$s$,
  pg_temp.u(101))), false);
select set_config('t.customer2', pg_temp.as_user(1, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Domaine des Aires", "street": "3 chemin des Vignes", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR98765432109"}'::jsonb, 'business')::text$s$,
  pg_temp.u(101))), false);
select ok(current_setting('t.customer') ~ '^[0-9a-f-]{36}$' and current_setting('t.customer2') ~ '^[0-9a-f-]{36}$',
  'two billing customers with no account are the engagements'' customers');

-- an accepted quote of two lines: training and a day of coaching
select set_config('q.a', pg_temp.as_user(1, format(
  $s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', 'Offer', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer'),
  jsonb_build_array(pg_temp.line('1.5', '90', 'Consulting'), pg_temp.line('1', '400', 'Training'))::text)), false);
select set_config('q.id', current_setting('q.a')::jsonb ->> 'quote_id', false);
select set_config('s.a', pg_temp.as_user(1, format($s$select public.send_customer_quote_v1(%L, %L, 1, 1)::text$s$,
  pg_temp.u(101), current_setting('q.id'))), false);
select set_config('l.one', (select frozen -> 'lines' -> 0 #>> '{commercial,line_id}' from public.customer_quote_revisions
                           where quote_id = current_setting('q.id')::uuid), false);
select set_config('l.two', (select frozen -> 'lines' -> 1 #>> '{commercial,line_id}' from public.customer_quote_revisions
                           where quote_id = current_setting('q.id')::uuid), false);
select set_config('t.books', pg_temp.books(), false);

-- the business's own date, not the database session's: they differ for a few hours a day
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);

-- ── before there is anything to follow ──
select is(pg_temp.open_line(1, pg_temp.u(101), 1, 'quote', current_setting('q.id')::uuid, current_setting('l.two')::uuid),
  'ERR DKF03', 'a quote that was only sent is no commercial evidence yet');
select is(pg_temp.as_user(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', current_setting('t.today')::date, 'email', 'mail')::text$s$,
  pg_temp.u(101), current_setting('q.id'))) like '%recorded_by_issuer%', true, 'the issuer records the acceptance of revision 1');
update public.workspaces set feature_flags = feature_flags - 'serviceFulfilment' where id = pg_temp.u(101);
select is(pg_temp.open_line(1, pg_temp.u(101), 1, 'quote', current_setting('q.id')::uuid, current_setting('l.two')::uuid),
  'ERR DKF10', 'with the feature off, the server refuses: the screen is not the gate');
select is(pg_temp.as_user(1, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101))), 'ERR 42501',
  'and nothing is read either');
update public.workspaces set feature_flags = feature_flags || '{"serviceFulfilment": true}' where id = pg_temp.u(101);

-- ── 1. an engagement from the accepted quote line, followed before any invoice ──
select set_config('f.a', pg_temp.open_line(1, pg_temp.u(101), 2, 'quote', current_setting('q.id')::uuid, current_setting('l.two')::uuid), false);
select set_config('f.id', current_setting('f.a')::jsonb #>> '{fulfilment,fulfilment_id}', false);
select is(current_setting('f.a')::jsonb ->> 'created', 'true', 'the issuer opens the engagement of the training line');
select is(current_setting('f.a')::jsonb #>> '{fulfilment,state}' || '|' || (current_setting('f.a')::jsonb #>> '{fulfilment,revision}'),
  'ordered|1', 'it is ordered, at revision 1');
select is(current_setting('f.a')::jsonb #>> '{fulfilment,scope,description}', 'Training', 'its scope is the line, frozen');
select is(current_setting('f.a')::jsonb #>> '{fulfilment,subject_id}', current_setting('t.customer'), 'and it is owed to the quote''s customer');
select is(current_setting('f.a')::jsonb #>> '{fulfilment,source,kind}' || '|' || (current_setting('f.a')::jsonb #>> '{fulfilment,source,revision}'),
  'quote|1', 'its source is the accepted revision of the quote');
select is(pg_temp.books(), current_setting('t.books'), 'opening it touches no invoice, no ledger entry, no match, no number');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('f.id'), 1, 'started', '', 3)::jsonb #>> '{fulfilment,state}', 'started', 'work starts');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('f.id'), 2, 'done', '', 4)::jsonb #>> '{fulfilment,state}', 'done', 'and is done, before any invoice');
select is((select string_agg(coalesce(from_state, '-') || '>' || to_state, ' ' order by revision)
             from public.service_fulfilment_transitions where fulfilment_id = current_setting('f.id')::uuid),
  '->ordered ordered>started started>done', 'ordered > started > done');

-- ── 2. then the invoice, a partial payment: the history does not move ──
select set_config('c.a', pg_temp.as_user(1, format($s$select public.prepare_quote_conversion_v1(%L, %L, current_setting('t.today')::date, current_setting('t.today')::date + 30)::text$s$,
  pg_temp.u(101), current_setting('q.id'))), false);
select set_config('c.i', pg_temp.as_user(1, format(
  $s$select public.convert_customer_quote_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041781'::uuid)::text$s$,
  pg_temp.u(101), current_setting('q.id'), (current_setting('c.a')::jsonb ->> 'draft_revision'))), false);
select set_config('i.id', current_setting('c.i')::jsonb ->> 'invoice_id', false);
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, note, by_name)
values (pg_temp.u(101), current_setting('i.id')::uuid, 30000, 'under_accepted', 'confirmed', 'fixture', 'Owner');
select set_config('h.before', (select count(*)::text from public.service_fulfilment_transitions), false);
select is(pg_temp.open_line(1, pg_temp.u(101), 5, 'invoice', current_setting('i.id')::uuid, current_setting('l.two')::uuid)::jsonb #>> '{fulfilment,fulfilment_id}',
  current_setting('f.id'), 'opening it from the invoice that billed the quote returns the SAME engagement');
select is(pg_temp.open_line(1, pg_temp.u(101), 5, 'invoice', current_setting('i.id')::uuid, current_setting('l.two')::uuid)::jsonb ->> 'created',
  'false', 'whatever the request: nothing is created twice');
select is((select count(*)::text from public.service_fulfilment_transitions), current_setting('h.before'),
  'and no step was added by the invoice, the payment or the second opening');
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_v1(%L, %L)::jsonb #>> '{invoices,0,paid_cents}')$s$,
  pg_temp.u(101), current_setting('f.id'))), '30000', 'the engagement shows what was paid on its invoice, beside it');
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_v1(%L, %L)::jsonb #>> '{quote,status}')$s$,
  pg_temp.u(101), current_setting('f.id'))), 'converted', 'and its quote, converted');
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_v1(%L, %L)::jsonb #>> '{state}')$s$,
  pg_temp.u(101), current_setting('f.id'))), 'done', 'the engagement is still done');
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_of_line_v1(%L, 'invoice', %L, %L)::jsonb ->> 'fulfilment_id')$s$,
  pg_temp.u(101), current_setting('i.id'), current_setting('l.two'))), current_setting('f.id'),
  'the line''s engagement is found from the invoice, without opening anything');
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_of_line_v1(%L, 'quote', %L, %L)::jsonb ->> 'fulfilment_id')$s$,
  pg_temp.u(101), current_setting('q.id'), current_setting('l.two'))), current_setting('f.id'), 'and from the quote');
select is(pg_temp.as_user(1, format($s$select coalesce((public.service_fulfilment_of_line_v1(%L, 'quote', %L, %L)::jsonb ->> 'fulfilment_id'), 'none')$s$,
  pg_temp.u(101), current_setting('q.id'), current_setting('l.one'))), 'none', 'a line nobody opened has none');

-- ── 3. a second opening of the same canonical line ──
select is(pg_temp.open_line(1, pg_temp.u(101), 2, 'quote', current_setting('q.id')::uuid, current_setting('l.two')::uuid)::jsonb ->> 'replayed',
  'true', 'the same request again replays the same answer');
select is(pg_temp.open_line(1, pg_temp.u(101), 2, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid),
  'ERR DKF05', 'a changed payload under the same request is refused');
select is(pg_temp.open_line(1, pg_temp.u(101), 6, 'quote', current_setting('q.id')::uuid, current_setting('l.two')::uuid)::jsonb #>> '{fulfilment,fulfilment_id}',
  current_setting('f.id'), 'a new request for the same line is that engagement');
select is((select count(*)::text from public.service_fulfilments where workspace_id = pg_temp.u(101)), '1',
  'there is one engagement for the line, however it was reached');
select is(pg_temp.err(format($s$insert into public.service_fulfilments (workspace_id, subject_member_id, source_kind, source_id, source_line_id, scope)
  values (%L, %L, 'quote', %L, %L, '{}')$s$, pg_temp.u(101), current_setting('t.customer'), current_setting('q.id'), current_setting('l.two'))),
  '23505', 'and the constraint says it too: one aggregate per canonical source line');

-- ── 4. a direct engagement, committed before any invoice ──
select set_config('t.books', pg_temp.books(), false);
select set_config('d.a', pg_temp.open_direct(1, pg_temp.u(101), 7, jsonb_build_object('subject_id', current_setting('t.customer2'),
  'description', 'Coaching', 'quantity', '3', 'unit', 'session')), false);
select set_config('d.id', current_setting('d.a')::jsonb #>> '{fulfilment,fulfilment_id}', false);
select is(current_setting('d.a')::jsonb #>> '{fulfilment,source,kind}' || '|' || (current_setting('d.a')::jsonb #>> '{fulfilment,scope,quantity}'),
  'direct|3', 'a direct engagement keeps its own commitment');
select is(current_setting('d.a')::jsonb #>> '{fulfilment,source,id}', current_setting('d.id'), 'which is its own identity');
select is(pg_temp.books(), current_setting('t.books'), 'it makes no invoice, no receivable, no ledger entry');
select is(pg_temp.open_direct(1, pg_temp.u(101), 8, jsonb_build_object('subject_id', current_setting('t.customer2'),
  'description', 'Coaching', 'quantity', '3', 'unit', 'session'))::jsonb #>> '{fulfilment,fulfilment_id}' <> current_setting('d.id'), true,
  'an identical-looking one is another engagement');
select is(pg_temp.open_direct(1, pg_temp.u(101), 9, jsonb_build_object('subject_id', pg_temp.u(299), 'description', 'x', 'quantity', '1')),
  'ERR DKF01', 'a customer the business does not have is refused');
select is(pg_temp.open_direct(1, pg_temp.u(101), 9, jsonb_build_object('subject_id', current_setting('t.customer'), 'description', 'x', 'quantity', '0')),
  'ERR DKF06', 'a zero quantity is refused');
select is(pg_temp.open_direct(1, pg_temp.u(101), 9, jsonb_build_object('subject_id', current_setting('t.customer'), 'description', ' ', 'quantity', '1')),
  'ERR DKF06', 'and no description');
select is(pg_temp.open_direct(1, pg_temp.u(101), 9, jsonb_build_object('subject_id', current_setting('t.customer'), 'description', 'x',
  'quantity', '1', 'item_id', pg_temp.u(298))), 'ERR DKF01', 'an item of nobody''s catalogue is refused');

-- the catalogue cannot rewrite it
insert into public.services (id, workspace_id, name, price_cents) values (pg_temp.u(401), pg_temp.u(101), 'Coaching hour', 9000);
select set_config('d.b', pg_temp.open_direct(1, pg_temp.u(101), 10, jsonb_build_object('subject_id', current_setting('t.customer'),
  'description', 'Coaching hour', 'quantity', '2', 'unit', 'h', 'item_id', pg_temp.u(401))), false);
select set_config('d.bid', current_setting('d.b')::jsonb #>> '{fulfilment,fulfilment_id}', false);
update public.services set name = 'Renamed', price_cents = 1, active = false where id = pg_temp.u(401);
delete from public.services where id = pg_temp.u(401);
select is(pg_temp.as_user(1, format($s$select (public.service_fulfilment_v1(%L, %L)::jsonb #>> '{scope,item}')$s$,
  pg_temp.u(101), current_setting('d.bid'))), 'Coaching hour',
  'renaming, repricing, deactivating and deleting the catalogue item rewrites nothing frozen');

-- ── 5. steps: stale revisions, replays, cancellation, illegal jumps ──
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 1, 'started', '', 11)::jsonb #>> '{fulfilment,revision}', '2',
  'the first of two sessions at revision 1 starts the work');
select is(pg_temp.step(5, pg_temp.u(101), current_setting('d.id'), 1, 'started', '', 12), 'ERR DKF02',
  'the second, at the same expected revision, is told it is stale');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 1, 'started', '', 11)::jsonb ->> 'replayed', 'true',
  'a retry after a lost success returns the same step, not a second');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 1, 'cancelled', 'changed my mind', 11), 'ERR DKF05',
  'a changed payload under that request is refused');
select is((select count(*)::text from public.service_fulfilment_transitions where fulfilment_id = current_setting('d.id')::uuid), '2',
  'and the history is two steps');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 2, 'cancelled', '', 13), 'ERR DKF06', 'a cancellation without a reason is refused');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 2, 'ordered', '', 13), 'ERR DKF06', 'there is no step back to ordered');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.bid'), 1, 'done', '', 14), 'ERR DKF04', 'ordered cannot jump to done');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.bid'), 1, 'cancelled', 'never started', 15)::jsonb #>> '{fulfilment,state}',
  'cancelled', 'ordered work is cancelled with a reason');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.bid'), 2, 'started', '', 16), 'ERR DKF04', 'a cancelled engagement stays cancelled');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('f.id'), 3, 'cancelled', 'too late', 17), 'ERR DKF04', 'done work is never cancelled');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 2, 'cancelled', 'the customer withdrew', 18)::jsonb #>> '{fulfilment,history,2,reason}',
  'the customer withdrew', 'started work is cancelled with its reason kept');
select is(pg_temp.step(1, pg_temp.u(101), pg_temp.u(299)::text, 1, 'started', '', 19), 'ERR DKF01', 'an unknown engagement is refused');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.id'), 3, 'started', '', 19) , 'ERR DKF04', 'and so is any step after the end');

-- ── 6. a direct commitment later billed: the explicit link ──
select set_config('n.a', pg_temp.as_user(1, format(
  $s$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, current_setting('t.today')::date, current_setting('t.today')::date + 30, '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer2'), jsonb_build_array(pg_temp.line('3', '70', 'Coaching'))::text)), false);
select set_config('n.i', pg_temp.as_user(1, format(
  $s$select public.issue_standalone_invoice_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041782'::uuid)::text$s$,
  pg_temp.u(101), current_setting('n.a')::jsonb ->> 'draft_id', current_setting('n.a')::jsonb ->> 'revision')), false);
select set_config('n.id', current_setting('n.i')::jsonb ->> 'invoice_id', false);
select set_config('n.line', (select lines -> 0 -> 'commercial' ->> 'line_id' from public.invoices where id = current_setting('n.id')::uuid), false);
select is(pg_temp.open_line(1, pg_temp.u(101), 20, 'invoice', current_setting('n.id')::uuid, current_setting('n.line')::uuid)::jsonb #>> '{fulfilment,source,kind}',
  'invoice', 'an invoice line with no earlier source is its own source');
select set_config('n.f', pg_temp.open_line(1, pg_temp.u(101), 20, 'invoice', current_setting('n.id')::uuid, current_setting('n.line')::uuid)::jsonb #>> '{fulfilment,fulfilment_id}', false);
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::text$s$,
  pg_temp.u(101), current_setting('n.f'), current_setting('n.id'), current_setting('n.line'))), 'ERR DKF03',
  'only a direct engagement is linked to an invoice line');
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::text$s$,
  pg_temp.u(101), current_setting('d.bid'), current_setting('n.id'), current_setting('n.line'))), 'ERR DKF03',
  'and its customer must be the invoice''s (the other customer, here)');
select set_config('d.c', pg_temp.open_direct(1, pg_temp.u(101), 21, jsonb_build_object('subject_id', current_setting('t.customer2'),
  'description', 'Coaching', 'quantity', '3', 'unit', 'session')), false);
select set_config('d.cid', current_setting('d.c')::jsonb #>> '{fulfilment,fulfilment_id}', false);
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::text$s$,
  pg_temp.u(101), current_setting('d.cid'), current_setting('n.id'), current_setting('n.line'))), 'ERR DKF03',
  'a line that already has its own engagement is not linked to another');
select set_config('n.b', pg_temp.as_user(1, format(
  $s$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, current_setting('t.today')::date, current_setting('t.today')::date + 30, '', '', %L::jsonb)::text$s$,
  pg_temp.u(101), current_setting('t.customer2'), jsonb_build_array(pg_temp.line('3', '70', 'Coaching'))::text)), false);
select set_config('n.bi', pg_temp.as_user(1, format(
  $s$select public.issue_standalone_invoice_v1(%L, %L, %s, '00000000-0000-4000-8000-000000041783'::uuid)::text$s$,
  pg_temp.u(101), current_setting('n.b')::jsonb ->> 'draft_id', current_setting('n.b')::jsonb ->> 'revision')), false);
select set_config('n.bid', current_setting('n.bi')::jsonb ->> 'invoice_id', false);
select set_config('n.bline', (select lines -> 0 -> 'commercial' ->> 'line_id' from public.invoices where id = current_setting('n.bid')::uuid), false);
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::jsonb #>> '{fulfilment,invoices,0,number}'$s$,
  pg_temp.u(101), current_setting('d.cid'), current_setting('n.bid'), current_setting('n.bline'))) like 'INV-%', true,
  'the invoice line that billed the commitment is linked to it, and the engagement shows that invoice');
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::jsonb #>> '{fulfilment,fulfilment_id}'$s$,
  pg_temp.u(101), current_setting('d.cid'), current_setting('n.bid'), current_setting('n.bline'))), current_setting('d.cid'), 'linking again is the same answer');
select is(pg_temp.as_user(1, format($s$select public.link_service_fulfilment_invoice_v1(%L, %L, %L, %L)::text$s$,
  pg_temp.u(101), current_setting('d.id'), current_setting('n.bid'), current_setting('n.bline'))), 'ERR DKF03', 'a line answers for one engagement only');
select is(pg_temp.open_line(1, pg_temp.u(101), 22, 'invoice', current_setting('n.bid')::uuid, current_setting('n.bline')::uuid)::jsonb #>> '{fulfilment,fulfilment_id}',
  current_setting('d.cid'), 'opened from that invoice, the line returns the commitment it was linked to');

-- ── 7. who may do what ──
select is(pg_temp.open_line(2, pg_temp.u(101), 30, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid) like 'ERR %', true,
  'a finance reader does not open an engagement');
select is(pg_temp.step(2, pg_temp.u(101), current_setting('d.cid'), 1, 'started', '', 31) like 'ERR %', true, 'nor take a step');
select is(jsonb_array_length(pg_temp.as_user(2, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101)))::jsonb) >= 3, true,
  'but reads every engagement of the business');
select is(pg_temp.as_user(2, format($s$select count(*)::text from public.service_fulfilments where workspace_id = %L$s$, pg_temp.u(101))) <> '0', true,
  'and the rows through the policy');
select is(pg_temp.as_user(3, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101))), 'ERR 42501', 'a coworker reads nothing');
select is(pg_temp.as_user(3, format($s$select count(*)::text from public.service_fulfilments where workspace_id = %L$s$, pg_temp.u(101))), '0',
  'not even the rows');
select is(pg_temp.open_line(3, pg_temp.u(101), 32, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid) like 'ERR %', true, 'and opens nothing');
select is(pg_temp.as_user(6, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101))), 'ERR 42501',
  'a customer with an account reads nothing of it either');
select is(pg_temp.open_line(6, pg_temp.u(101), 33, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid) like 'ERR %', true,
  'and writes nothing');
select is(pg_temp.as_user(4, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101))), 'ERR 42501',
  'an unrelated account reads nothing of another business');
select is(pg_temp.open_line(4, pg_temp.u(101), 34, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid) like 'ERR %', true, 'and opens nothing in it');
select is(pg_temp.open_line(4, pg_temp.u(102), 35, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid), 'ERR DKF01',
  'a quote of another business is no source for one''s own');
select is(pg_temp.as_user(1, format($s$select public.service_fulfilments_v1(%L)::text$s$, pg_temp.u(101)), '{"client_id": "assistant"}'::jsonb), 'ERR 42501',
  'a delegated token reads nothing');
select is(pg_temp.open_line(1, pg_temp.u(101), 36, 'quote', current_setting('q.id')::uuid, current_setting('l.one')::uuid, '{"client_id": "assistant"}'::jsonb),
  'ERR DKF07', 'and keeps nothing: this is done in the app');
select is(pg_temp.step(1, pg_temp.u(101), current_setting('d.cid'), 1, 'started', '', 37, '{"client_id": "assistant"}'::jsonb), 'ERR DKF07',
  'not a step either');
select is(pg_temp.as_user(1, format($s$insert into public.service_fulfilments (workspace_id, subject_member_id, source_kind, source_id, source_line_id, scope)
  values (%L, %L, 'quote', %L, %L, '{}') returning id::text$s$, pg_temp.u(101), current_setting('t.customer'), pg_temp.u(299), pg_temp.u(298))),
  'ERR 42501', 'no client writes an engagement directly');
-- the authority behind a step is checked when it is taken
select is(pg_temp.step(5, pg_temp.u(101), current_setting('d.cid'), 1, 'started', '', 38)::jsonb #>> '{fulfilment,state}', 'started',
  'a second issuer takes a step');
update public.members set is_owner = false, is_admin = false where id = pg_temp.u(205);
select is(pg_temp.step(5, pg_temp.u(101), current_setting('d.cid'), 2, 'done', '', 39) like 'ERR %', true,
  'who lost the right to issue takes no more steps');

-- ── 8. what never changes ──
select is(pg_temp.err(format($s$update public.service_fulfilment_transitions set reason = 'x' where fulfilment_id = %L$s$, current_setting('f.id'))), 'DKF05',
  'a step is never edited');
select is(pg_temp.err(format($s$delete from public.service_fulfilment_transitions where fulfilment_id = %L$s$, current_setting('f.id'))), 'DKF05',
  'nor deleted');
select is(pg_temp.err(format($s$delete from public.service_fulfilments where id = %L$s$, current_setting('f.id'))), 'DKF05', 'an engagement is never deleted');
select is(pg_temp.err(format($s$update public.service_fulfilments set scope = '{"description": "other"}' where id = %L$s$, current_setting('f.id'))), 'DKF05',
  'nor is its scope or its source rewritten');
select is(pg_temp.err(format($s$update public.service_fulfilments set subject_member_id = %L where id = %L$s$, current_setting('t.customer2'), current_setting('f.id'))), 'DKF05',
  'nor its customer');
select is(pg_temp.err(format($s$delete from public.service_fulfilment_invoice_links where fulfilment_id = %L$s$, current_setting('d.cid'))), 'DKF05', 'a link is never deleted');
select is(pg_temp.err(format($s$insert into public.service_fulfilment_transitions (workspace_id, fulfilment_id, revision, from_state, to_state, actor_member_id, request_id, request_digest)
  values (%L, %L, 2, 'ordered', 'started', %L, %L, 'x')$s$, pg_temp.u(101), current_setting('f.id'), pg_temp.u(201), pg_temp.rq(900))), '23505',
  'two steps never share a revision');

-- ── 9. the export carries them; the business can still be erased ──
select is(pg_temp.as_user(1, format($s$select count(*)::text from jsonb_array_elements(public.export_workspace_records(%L)) e
            where e ->> 'table' in ('service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links')$s$, pg_temp.u(101))), '3',
  'the workspace records export carries the three tables');
select set_config('e.c', pg_temp.as_user(7, format(
  $s$select public.billing_customer_create_v1(%L, '{"company": "Erased Customer", "street": "1 rue", "postal_code": "34120", "city": "Pezenas", "country_code": "FR", "vat_id": "FR12345678901"}'::jsonb, 'business')::text$s$,
  pg_temp.u(103))), false);
select is(pg_temp.open_direct(7, pg_temp.u(103), 40, jsonb_build_object('subject_id', current_setting('e.c'), 'description', 'x', 'quantity', '1')) like '%"created": true%',
  true, 'a business with an engagement and no invoice');
select is(pg_temp.err(format($s$delete from public.workspaces where id = %L$s$, pg_temp.u(103))), 'no error', 'is erased with its engagements and their steps');
select is((select count(*)::int from public.service_fulfilments where workspace_id = pg_temp.u(103))
        + (select count(*)::int from public.service_fulfilment_transitions where workspace_id = pg_temp.u(103)), 0, 'nothing of them is left');

select * from finish();
rollback;
