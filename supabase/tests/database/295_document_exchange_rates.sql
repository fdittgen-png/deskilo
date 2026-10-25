-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3031 (migrations 0589, 0590): a recorded exchange rate per foreign-currency
-- purchase, read by the books. Real roles (definer RPCs and the RLS reads run
-- as `authenticated`), a readback after every refusal:
--   F the registries: the flag under purchases, off; the rate sources; the
--     minor digits of a currency.
--   S the store: a bill in francs is saved only with the flag on, never as a
--     member's receipt; its rate is entered, corrected (revision 2) and read
--     by whoever may read the bill, never by a plain member; a rate sent with
--     the draft is recorded with it and goes when the draft is back in the
--     space's currency; an unknown source, a rate that is not positive, a
--     plain member and another space's owner are refused.
--   A approval: a bill in francs with its rate is approved and its rate is
--     then fixed; one without a rate is refused, named, and stays pending.
--   K the books (compute_postings): the bill and its payment in euros at
--     1.0657, each line with its original amount, the entry with its
--     original currency and rate, balanced; an approved bill in francs with
--     no rate blocks as missingRate, named, until its first rate arrives; a
--     bill in euros is booked as before; the converter balances the cents
--     the rounding leaves.
--   G grants: the RPC for signed-in callers only, the converter and the
--     writer for nobody, the table never written by a client.
-- Seeds are direct inserts as postgres (users, workspaces, members, a
-- supplier, A's default site and its book accounts and mappings); the
-- workspaces switch on the flags the RPCs gate on and their parents:
-- foreignCurrencyPurchases under purchases under moneyTab (B: off).
begin;
select plan(40);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003031' || lpad((9000 + n)::text, 4, '0'))::uuid;
$$;

create function pg_temp.req(n int) returns uuid language sql as $$
  select ('a3031000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;

-- The jsonb [p_sql] returns as [p_user]; {"error": ...} when it is refused.
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

-- The first column of [p_sql] as [p_user], as text; the error when refused.
create function pg_temp.as_text(p_user uuid, p_sql text) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return coalesce(v, '');
exception when others then
  reset role;
  return 'error: ' || sqlerrm;
end;
$$;

-- Saves a bill [p_ref] in [p_currency] as [p_user] in [p_ws]; [p_extra] joins
-- the payload (an exchange_rate, a purchase_id).
create function pg_temp.save(p_user int, p_ws text, p_req int, p_ref text, p_currency text,
                             p_extra jsonb default '{}', p_kind text default 'bill',
                             p_revision int default 0)
returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(p_user), format(
    'select public.save_purchase_draft_v1(%L, %L, %s, %L::jsonb)', p_ws, pg_temp.req(p_req), p_revision,
    (jsonb_build_object('kind', p_kind, 'category', 'software', 'supplier_id', current_setting('t.sup_a'),
       'original_reference', p_ref, 'original_date', current_date - 2, 'currency', p_currency,
       'lines', jsonb_build_array(
         jsonb_build_object('description', 'Licence', 'gross_cents', 24000, 'recognition_kind', 'operating'),
         jsonb_build_object('description', 'Set-up', 'gross_cents', 1250, 'recognition_kind', 'operating')))
     || p_extra)::text));
$$;

create function pg_temp.rate(p_user int, p_doc text, p_rate text, p_source text,
                             p_ws text default current_setting('t.a'))
returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(p_user), format(
    'select public.record_purchase_exchange_rate_v1(%L, %L, %L::numeric, %L::date, %L)',
    p_ws, p_doc, p_rate, current_date - 2, p_source));
$$;

create function pg_temp.doc(p_ref text) returns text language sql as $$
  select id::text from public.purchase_documents
   where workspace_id = current_setting('t.a')::uuid and original_reference = p_ref;
$$;

create function pg_temp.revision(p_ref text) returns int language sql as $$
  select revision from public.purchase_documents
   where workspace_id = current_setting('t.a')::uuid and original_reference = p_ref;
$$;

create function pg_temp.submit_and_decide(p_ref text, p_req int) returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, %s, %L)',
           current_setting('t.a'), pg_temp.doc(p_ref), pg_temp.revision(p_ref), pg_temp.req(p_req)));
  select pg_temp.as_json(pg_temp.u(4), format('select public.decide_purchase_v1(%L, %L, %s, true, '''', %L)',
           current_setting('t.a'), pg_temp.doc(p_ref), pg_temp.revision(p_ref), pg_temp.req(p_req + 1)));
$$;

create function pg_temp.books() returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(1), format('select public.compute_postings(%L, %L, %L, %L)',
    current_setting('t.a'), current_setting('t.site_a'), current_date - 10, current_date));
$$;

-- The [p_kind] entry of document [p_ref]: code:Dn / code:Cn, in order.
create function pg_temp.posted(p_ref text, p_kind text) returns text language sql as $$
  select coalesce(string_agg((l ->> 'account_code') || ':' ||
           case when (l ->> 'debit_cents')::bigint > 0 then 'D' || (l ->> 'debit_cents') else 'C' || (l ->> 'credit_cents') end,
           ',' order by n), '')
    from jsonb_array_elements(pg_temp.books() -> 'postings') p,
         jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
   where p ->> 'document_number' = p_ref and p ->> 'kind' = p_kind;
$$;

create function pg_temp.entry(p_ref text, p_kind text) returns jsonb language sql as $$
  select p from jsonb_array_elements(pg_temp.books() -> 'postings') p
   where p ->> 'document_number' = p_ref and p ->> 'kind' = p_kind;
$$;

create function pg_temp.blockers() returns text language sql as $$
  select coalesce(string_agg((b ->> 'block') || ':' || (b ->> 'subject'), ',' order by b ->> 'block', b ->> 'subject'), '')
    from jsonb_array_elements(pg_temp.books() -> 'blockers') b;
$$;

create function pg_temp.book(p_role text, p_code text, p_type text) returns void language sql as $$
  insert into public.book_accounts (workspace_id, issuer_site_id, code, name, account_type)
  values (current_setting('t.a')::uuid, current_setting('t.site_a')::uuid, p_code, p_code, p_type);
  insert into public.book_mappings (workspace_id, issuer_site_id, role, account_id, effective_from)
  select current_setting('t.a')::uuid, current_setting('t.site_a')::uuid, p_role, a.id, date '2020-01-01'
    from public.book_accounts a
   where a.issuer_site_id = current_setting('t.site_a')::uuid and a.code = p_code;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@fx-rates.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner of A (captures), 2 a plain member of A, 3 owner of B, 4 a second
-- owner of A (decides).

select set_config('t.a', '00000000-0000-4000-8000-0000303190a1', true);
select set_config('t.b', '00000000-0000-4000-8000-0000303190b1', true);
select set_config('t.site_a', '00000000-0000-4000-8000-0000303191a1', true);
select set_config('t.site_b', '00000000-0000-4000-8000-0000303191b1', true);
select set_config('t.sup_a', '00000000-0000-4000-8000-0000303192a1', true);
select set_config('t.sup_b', '00000000-0000-4000-8000-0000303192b1', true);

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, feature_flags)
values (current_setting('t.a')::uuid, 'FX rates A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev',
        '{"moneyTab": true, "purchases": true, "foreignCurrencyPurchases": true}'::jsonb),
       (current_setting('t.b')::uuid, 'FX rates B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev',
        '{"moneyTab": true, "purchases": true, "foreignCurrencyPurchases": false}'::jsonb);

insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 (current_setting('t.a')::uuid, pg_temp.u(1), true, true, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active'),
 (current_setting('t.b')::uuid, pg_temp.u(3), true, true, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(4), true, true, 'active');

insert into public.sites (id, workspace_id, name) values
 (current_setting('t.site_a')::uuid, current_setting('t.a')::uuid, 'Rue Haute'),
 (current_setting('t.site_b')::uuid, current_setting('t.b')::uuid, 'Elsewhere');
update public.sites set is_default = false where workspace_id = current_setting('t.a')::uuid;
update public.sites set is_default = true where id = current_setting('t.site_a')::uuid;
select pg_temp.book('expenses', '606', 'expense');
select pg_temp.book('suppliers', '401', 'liability');
select pg_temp.book('bank', '512', 'asset');

insert into public.suppliers (id, workspace_id, supplier_number, name) values
 (current_setting('t.sup_a')::uuid, current_setting('t.a')::uuid, '23', 'Logiciels Léman SA'),
 (current_setting('t.sup_b')::uuid, current_setting('t.b')::uuid, '1', 'Other Ltd');

-- ── F: the registries ──────────────────────────────────────────────────
select is(public.feature_registry() -> 'foreignCurrencyPurchases',
  '{"parent": "purchases", "default": false, "core": false}'::jsonb,
  'F1 the flag is registered under purchases, off by default');
select is((select string_agg(code, ',' order by sort_order) from public.exchange_rate_sources where active),
  'tax_authority,bank,manual', 'F2 the rate sources are reference rows');
select is(public.currency_minor_digits('JPY') || '/' || public.currency_minor_digits('kwd') || '/'
          || public.currency_minor_digits('CHF'), '0/3/2', 'F3 the minor digits of a currency follow ISO 4217');

-- ── S: the store ───────────────────────────────────────────────────────
select is(pg_temp.save(3, current_setting('t.b'), 1, 'B-CHF', 'CHF',
            jsonb_build_object('supplier_id', current_setting('t.sup_b'))) ->> 'error',
  'a purchase is in the currency of the space', 'S1 with the flag off, a bill in francs is refused');
select is((select count(*)::int from public.purchase_documents where workspace_id = current_setting('t.b')::uuid),
  0, 'S1b nothing was saved in B');
select is(pg_temp.save(2, current_setting('t.a'), 2, '', 'CHF', '{"supplier_id": null}', 'member_receipt') ->> 'error',
  'a purchase is in the currency of the space', 'S2 a member''s receipt stays in the space''s currency');
select is(pg_temp.save(1, current_setting('t.a'), 3, 'CH-1', 'CHF') ->> 'state', 'draft',
  'S3 golden: with the flag on, the owner saves a bill in francs');
select is((select currency from public.purchase_documents where id = pg_temp.doc('CH-1')::uuid), 'CHF',
  'S3b the bill keeps its currency');
select is(pg_temp.rate(1, pg_temp.doc('CH-1'), '1.06', 'rumour') ->> 'error', 'unknown rate source',
  'S4 a source outside the reference list is refused');
select is(pg_temp.rate(1, pg_temp.doc('CH-1'), '-1.06', 'bank') ->> 'error',
  'a rate is a positive number with its date', 'S5 a rate that is not positive is refused');
select is(pg_temp.rate(2, pg_temp.doc('CH-1'), '1.06', 'bank') ->> 'error',
  'not allowed to record an exchange rate', 'S6 a plain member records no rate');
select is(pg_temp.rate(3, pg_temp.doc('CH-1'), '1.06', 'bank') ->> 'error',
  'not an active member', 'S7 another space''s owner records no rate here');
select is((select count(*)::int from public.document_exchange_rates), 0, 'S8 every refusal recorded nothing');
select is(pg_temp.rate(1, pg_temp.doc('CH-1'), '1.06', 'bank') ->> 'revision', '1',
  'S9 golden: the owner records the rate');
select is(pg_temp.rate(1, pg_temp.doc('CH-1'), '1.0657', 'tax_authority') - 'document_id' - 'rate_date',
  '{"rate": "1.0657", "source": "tax_authority", "currency": "CHF", "revision": 2, "functional_currency": "EUR"}'::jsonb,
  'S10 a correction before approval raises the revision and keeps the exact rate');
select is(pg_temp.as_text(pg_temp.u(1), 'select count(*)::text from public.document_exchange_rates'), '1',
  'S11 the owner reads the rate');
select is(pg_temp.as_text(pg_temp.u(2), 'select count(*)::text from public.document_exchange_rates'), '0',
  'S11b a plain member does not');
select is(pg_temp.save(1, current_setting('t.a'), 4, 'CH-2', 'CHF',
            '{"exchange_rate": {"rate": "0.9", "rate_date": "2026-05-12", "source": "manual"}}') ->> 'state',
  'draft', 'S12 a draft saved with its rate');
select is((select rate::text || '/' || source from public.document_exchange_rates
            where document_id = pg_temp.doc('CH-2')::uuid), '0.9/manual', 'S12b records the rate with it');
select is(pg_temp.save(1, current_setting('t.a'), 5, 'CH-2', 'EUR',
            jsonb_build_object('purchase_id', pg_temp.doc('CH-2')), 'bill', pg_temp.revision('CH-2')) ->> 'state',
  'draft', 'S13 the draft back in euros');
select is((select count(*)::int from public.document_exchange_rates where document_id = pg_temp.doc('CH-2')::uuid),
  0, 'S13b keeps no rate');

-- ── A: approval ────────────────────────────────────────────────────────
select is(pg_temp.submit_and_decide('CH-1', 10) ->> 'state', 'approved',
  'A1 golden: a bill in francs with its rate is approved by a second person');
select is(pg_temp.rate(4, pg_temp.doc('CH-1'), '1.10', 'bank') ->> 'error',
  'the rate of an approved purchase is fixed', 'A2 the rate of an approved bill is fixed');
select is((select rate::text from public.document_exchange_rates where document_id = pg_temp.doc('CH-1')::uuid),
  '1.0657', 'A2b and stays as recorded');
select is(pg_temp.save(1, current_setting('t.a'), 12, 'CH-3', 'CHF') ->> 'state', 'draft', 'A3 a second bill in francs, no rate');
select is(pg_temp.submit_and_decide('CH-3', 13) ->> 'error',
  'the purchase CH-3 in CHF has no recorded exchange rate', 'A3b is not approved, named');
select is((select state from public.purchase_documents where id = pg_temp.doc('CH-3')::uuid), 'pending',
  'A3c and still awaits its approval');

-- ── K: the books ───────────────────────────────────────────────────────
select is(pg_temp.as_json(pg_temp.u(1), format(
    'select public.record_supplier_payment_v1(%L, %L, 25250, %s, %L, %L)', current_setting('t.a'),
    (select id from public.purchase_obligations where purchase_id = pg_temp.doc('CH-1')::uuid),
    (select revision from public.purchase_obligations where purchase_id = pg_temp.doc('CH-1')::uuid),
    pg_temp.req(20), current_date - 1)) ? 'error', false, 'K0 the bill is paid in francs');
select is(pg_temp.posted('CH-1', 'supplier_bill'), '606:D25577,606:D1332,401:C26909',
  'K1 golden: the bill in euros at 1.0657, line by line, balanced (240.00 → 255.77, 12.50 → 13.32, 252.50 → 269.09)');
select is((select string_agg(l ->> 'original_cents', ',' order by n)
             from jsonb_array_elements(pg_temp.entry('CH-1', 'supplier_bill') -> 'lines') with ordinality z(l, n)),
  '24000,1250,25250', 'K2 each line keeps its original amount');
select is((pg_temp.entry('CH-1', 'supplier_bill') - 'lines' - 'document_id' - 'date' - 'document_number'
           - 'journal' - 'kind') #- '{exchange_rate,rate_date}',
  '{"currency": "EUR", "exchange_rate": {"rate": "1.0657", "source": "tax_authority"}, "original_currency": "CHF"}'::jsonb,
  'K3 the entry names its original currency and its rate');
select is(pg_temp.posted('CH-1', 'supplier_payment'), '401:D26909,512:C26909',
  'K4 its payment, in euros at the same rate');

-- An approved bill in francs without a rate (a space whose currency moved):
-- set up as postgres, the guard held aside for the seed only.
select is(pg_temp.as_text(pg_temp.u(3), 'select count(*)::text from public.document_exchange_rates'), '0',
  'S11c the owner of another space reads none');
select throws_like(format($$update public.purchase_documents set state = 'approved', decided_at = now(),
    decided_by_member_id = (select m.id from public.members m where m.workspace_id = %L and m.user_id = %L)
  where id = %L$$, current_setting('t.a'), pg_temp.u(4), pg_temp.doc('CH-3')),
  '%has no recorded exchange rate%', 'T1 the guard refuses a direct approval without the rate, named');
alter table public.purchase_documents disable trigger purchase_rate_required;
-- purchase_documents_approval_check (0468): an approved bill names who decided it.
update public.purchase_documents
   set state = 'approved', decided_at = now(),
       decided_by_member_id = (select m.id from public.members m
                                where m.workspace_id = current_setting('t.a')::uuid and m.user_id = pg_temp.u(4))
 where id = pg_temp.doc('CH-3')::uuid;
alter table public.purchase_documents enable trigger purchase_rate_required;
insert into public.purchase_obligations (workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency)
values (current_setting('t.a')::uuid, pg_temp.doc('CH-3')::uuid, 'supplier', current_setting('t.sup_a')::uuid, 25250, 'CHF');
select is(pg_temp.blockers() || '|' || pg_temp.posted('CH-3', 'supplier_bill'), 'missingRate:CH-3 (CHF)|',
  'K5 an approved bill in francs without a rate blocks the books, named, and is not booked in francs');
select is(pg_temp.rate(1, pg_temp.doc('CH-3'), '1.0657', 'bank') ->> 'revision', '1',
  'K6 its first rate is still accepted once approved');
select is(pg_temp.blockers() || '|' || pg_temp.posted('CH-3', 'supplier_bill'), '|606:D25577,606:D1332,401:C26909',
  'K6b and the books take it');
select is(public.posting_at_rate('{"currency": "CHF", "lines": [
    {"debit_cents": 1, "credit_cents": 0}, {"debit_cents": 1, "credit_cents": 0},
    {"debit_cents": 1, "credit_cents": 0}, {"debit_cents": 0, "credit_cents": 3}]}'::jsonb,
    'EUR', 0.5, current_date, 'manual') -> 'lines' -> 3 ->> 'credit_cents', '3',
  'K7 the rounding cents go to the largest line of the short side (three 0.005 debits round to 0.03, their 0.015 credit to 0.02, plus the cent)');

-- ── G: grants ──────────────────────────────────────────────────────────
select ok(not has_function_privilege('anon', 'public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)', 'execute')
          and has_function_privilege('authenticated', 'public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.posting_at_rate(jsonb, text, numeric, date, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.purchase_exchange_rate_write(uuid, uuid, uuid, jsonb)', 'execute'),
  'G1 the RPC for signed-in callers only; the converter and the writer for nobody');
select alike(pg_temp.as_text(pg_temp.u(1), format(
    'insert into public.document_exchange_rates (workspace_id, document_kind, document_id, currency, functional_currency, rate, rate_date, source) values (%L, ''purchase'', %L, ''CHF'', ''EUR'', 2, current_date, ''bank'') returning id::text',
    current_setting('t.a'), pg_temp.doc('CH-1'))), 'error: permission denied%'::text,
  'G2 a client never writes a rate by hand'::text);

select * from finish();
rollback;
