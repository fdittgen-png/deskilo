-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #3031 part 2: the rate store, its writers, the approval guard and the
-- books at the document's rate. Part 1 (0589) registers the feature; the
-- two are one change split to stay under the installer's per-file size.

-- ── the sources a rate may name: reference data, not code ─────────────
-- A rate says where its figure came from. The list is the platform's
-- reference data: a source is added by a row, retired by `active = false`,
-- never renamed (a recorded rate keeps naming it).
create table if not exists public.exchange_rate_sources (
  code text primary key check (code ~ '^[a-z][a-z_]{1,39}$'),
  sort_order integer not null default 0,
  active boolean not null default true
);
select public.ensure_system_columns('exchange_rate_sources');
alter table public.exchange_rate_sources enable row level security;
revoke all on public.exchange_rate_sources from public, anon, authenticated;
grant select on public.exchange_rate_sources to authenticated;
drop policy if exists exchange_rate_sources_read on public.exchange_rate_sources;
create policy exchange_rate_sources_read on public.exchange_rate_sources
  for select to authenticated using (true);
drop policy if exists mcp_delegated_deny on public.exchange_rate_sources;
create policy mcp_delegated_deny on public.exchange_rate_sources as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists personal_native_session on public.exchange_rate_sources;
create policy personal_native_session on public.exchange_rate_sources
  as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));
insert into public.exchange_rate_sources (code, sort_order) values
  ('tax_authority', 1),   -- the rate the tax authority publishes for the tax point
  ('bank', 2),            -- the rate the bank applied to the payment
  ('manual', 3)           -- a figure a person entered from elsewhere
on conflict (code) do nothing;

-- ── the rate recorded with a document ─────────────────────────────────
-- One row per document in another currency than the space's: how many
-- units of the space's currency one unit of the document's is worth, on
-- which day, from which source. Written only by the definer functions
-- below; read by whoever may read the document.
create table if not exists public.document_exchange_rates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  document_kind text not null check (document_kind in ('purchase')),
  document_id uuid not null references public.purchase_documents (id) on delete cascade,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  functional_currency text not null check (functional_currency ~ '^[A-Z]{3}$'),
  rate numeric not null check (rate > 0 and scale(rate) <= 10),
  rate_date date not null,
  source text not null references public.exchange_rate_sources (code),
  recorded_by_member_id uuid references public.members (id) on delete set null,
  revision integer not null default 1 check (revision >= 1),
  constraint document_exchange_rates_currencies check (currency <> functional_currency),
  constraint document_exchange_rates_document unique (workspace_id, document_kind, document_id)
);
select public.ensure_system_columns('document_exchange_rates');
create index if not exists document_exchange_rates_document_idx
  on public.document_exchange_rates (document_id);
alter table public.document_exchange_rates enable row level security;
revoke all on public.document_exchange_rates from public, anon, authenticated;
grant select on public.document_exchange_rates to authenticated;
drop policy if exists document_exchange_rates_select on public.document_exchange_rates;
create policy document_exchange_rates_select on public.document_exchange_rates
  for select to authenticated
  using (exists (
    select 1 from public.purchase_documents d
     where d.workspace_id = document_exchange_rates.workspace_id
       and d.id = document_exchange_rates.document_id));
drop policy if exists mcp_delegated_deny on public.document_exchange_rates;
create policy mcp_delegated_deny on public.document_exchange_rates as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the minor digits of a currency (ISO 4217) ─────────────────────────
-- A standard's fixed table, the same as `Currencies` in the app (pinned by
-- currency_minor_digits_test): no minor unit, three, else two.
create or replace function public.currency_minor_digits(p_currency text)
returns integer language sql immutable set search_path = public as $fn$
  select case
    when upper(p_currency) = any (array['BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG',
                                        'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF']) then 0
    when upper(p_currency) = any (array['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND']) then 3
    else 2 end;
$fn$;
revoke execute on function public.currency_minor_digits(text) from public, anon;
grant execute on function public.currency_minor_digits(text) to authenticated;

-- ── an entry at its document's rate ───────────────────────────────────
-- Each line converted once, rounded half away from zero, with the amount it
-- was converted from (`original_cents`); the cents the rounding leaves go to
-- the largest line of the side that is short (the first of equal ones), so
-- the entry stays balanced. The app's twin is `postingAtRate`.
create or replace function public.posting_at_rate(
  p_entry jsonb, p_currency text, p_rate numeric, p_rate_date date, p_source text
) returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_from text := p_entry ->> 'currency';
  v_scale numeric := power(10::numeric,
    public.currency_minor_digits(p_currency) - public.currency_minor_digits(v_from));
  v_lines jsonb := '[]'::jsonb;
  l jsonb;
  v_debit bigint;
  v_credit bigint;
  v_gap bigint := 0;
  v_side text;
  v_best int := -1;
  v_best_amount bigint := 0;
  v_i int;
begin
  for l in select e from jsonb_array_elements(coalesce(p_entry -> 'lines', '[]'::jsonb)) e loop
    if l ? 'blocked' then
      v_lines := v_lines || jsonb_build_array(l);
      continue;
    end if;
    v_debit := round((l ->> 'debit_cents')::bigint * p_rate * v_scale)::bigint;
    v_credit := round((l ->> 'credit_cents')::bigint * p_rate * v_scale)::bigint;
    v_gap := v_gap + v_debit - v_credit;
    v_lines := v_lines || jsonb_build_array(l || jsonb_build_object(
      'debit_cents', v_debit, 'credit_cents', v_credit,
      'original_cents', case when (l ->> 'debit_cents')::bigint <> 0
                             then (l ->> 'debit_cents')::bigint else (l ->> 'credit_cents')::bigint end));
  end loop;
  if v_gap <> 0 then
    -- Debits ahead: the largest credit takes the cents; credits ahead: the
    -- largest debit does.
    v_side := case when v_gap > 0 then 'credit_cents' else 'debit_cents' end;
    for v_i in 0 .. jsonb_array_length(v_lines) - 1 loop
      l := v_lines -> v_i;
      if l ? 'blocked' or (l ->> v_side)::bigint = 0 then continue; end if;
      if v_best < 0 or (l ->> v_side)::bigint > v_best_amount then
        v_best := v_i;
        v_best_amount := (l ->> v_side)::bigint;
      end if;
    end loop;
    if v_best >= 0 then
      v_lines := jsonb_set(v_lines, array[v_best::text, v_side], to_jsonb(v_best_amount + abs(v_gap)));
    end if;
  end if;
  return p_entry || jsonb_build_object(
    'currency', p_currency, 'original_currency', v_from,
    'exchange_rate', jsonb_build_object('rate', p_rate::text, 'rate_date', p_rate_date, 'source', p_source),
    'lines', v_lines);
end;
$fn$;
revoke execute on function public.posting_at_rate(jsonb, text, numeric, date, text) from public, anon, authenticated;

-- ── recording a rate ──────────────────────────────────────────────────
-- The one writer of the table, for the two doors below: a purchase in
-- another currency than the space's, a rate from the reference list. A
-- recorded rate is corrected while the purchase is a draft or awaits its
-- approval; once approved it is fixed (an approved purchase with none may
-- still receive its first, so the books it blocks can be completed).
create or replace function public.purchase_exchange_rate_write(
  p_workspace_id uuid, p_purchase_id uuid, p_member_id uuid, p_rate jsonb
) returns public.document_exchange_rates
language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.purchase_documents;
  v_space text;
  v_rate numeric;
  v_day date;
  v_source text := nullif(p_rate ->> 'source', '');
  v_row public.document_exchange_rates;
begin
  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id
   for update;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  select w.currency_code into v_space from public.workspaces w where w.id = p_workspace_id;
  if v_doc.currency = v_space then
    raise exception 'the purchase is in the currency of the space' using errcode = '22023';
  end if;
  begin
    v_rate := (p_rate ->> 'rate')::numeric;
    v_day := (p_rate ->> 'rate_date')::date;
  exception when others then
    raise exception 'a rate is a positive number with its date' using errcode = '22023';
  end;
  if v_rate is null or v_rate <= 0 or v_rate >= 100000000 or scale(v_rate) > 10 or v_day is null then
    raise exception 'a rate is a positive number with its date' using errcode = '22023';
  end if;
  if not exists (select 1 from public.exchange_rate_sources s where s.code = v_source and s.active) then
    raise exception 'unknown rate source' using errcode = '22023';
  end if;
  select * into v_row from public.document_exchange_rates x
   where x.workspace_id = p_workspace_id and x.document_kind = 'purchase' and x.document_id = v_doc.id
   for update;
  if v_row.id is not null and v_doc.state not in ('draft', 'pending') then
    raise exception 'the rate of an approved purchase is fixed' using errcode = '22023';
  end if;
  if v_row.id is null and v_doc.state not in ('draft', 'pending', 'approved') then
    raise exception 'only an open or approved purchase receives a rate' using errcode = '22023';
  end if;
  insert into public.document_exchange_rates
    (workspace_id, document_kind, document_id, currency, functional_currency, rate, rate_date,
     source, recorded_by_member_id)
  values (p_workspace_id, 'purchase', v_doc.id, v_doc.currency, v_space, v_rate, v_day, v_source, p_member_id)
  on conflict (workspace_id, document_kind, document_id) do update
    set currency = excluded.currency, functional_currency = excluded.functional_currency,
        rate = excluded.rate, rate_date = excluded.rate_date, source = excluded.source,
        recorded_by_member_id = excluded.recorded_by_member_id,
        revision = public.document_exchange_rates.revision + 1
  returning * into v_row;
  return v_row;
end;
$fn$;
revoke execute on function public.purchase_exchange_rate_write(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;

-- Enters or corrects the rate of a purchase in another currency: whoever
-- captures supplier bills or approves them, with the feature on.
create or replace function public.record_purchase_exchange_rate_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_rate numeric, p_rate_date date, p_source text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_row public.document_exchange_rates;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'foreignCurrencyPurchases') then
    raise exception 'purchases in another currency are switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'managePurchases')
          or public.has_permission(p_workspace_id, 'approveExpenses')) then
    raise exception 'not allowed to record an exchange rate' using errcode = '42501';
  end if;
  v_row := public.purchase_exchange_rate_write(p_workspace_id, p_purchase_id, v_me,
    jsonb_build_object('rate', p_rate::text, 'rate_date', p_rate_date, 'source', p_source));
  return jsonb_build_object(
    'document_id', v_row.document_id, 'currency', v_row.currency,
    'functional_currency', v_row.functional_currency, 'rate', v_row.rate::text,
    'rate_date', v_row.rate_date, 'source', v_row.source, 'revision', v_row.revision);
end;
$fn$;
revoke execute on function public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)
  from public, anon;
grant execute on function public.record_purchase_exchange_rate_v1(uuid, uuid, numeric, date, text)
  to authenticated;

-- ── no approval without the rate ──────────────────────────────────────
-- A purchase in another currency than the space's is approved only with
-- its rate recorded: the refusal names the document.
create or replace function public.purchase_rate_required()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_space text;
begin
  if new.state = 'approved' and old.state is distinct from 'approved' then
    select w.currency_code into v_space from public.workspaces w where w.id = new.workspace_id;
    if new.currency <> v_space and not exists (
         select 1 from public.document_exchange_rates x
          where x.workspace_id = new.workspace_id and x.document_kind = 'purchase'
            and x.document_id = new.id
            and x.currency = new.currency and x.functional_currency = v_space) then
      raise exception 'the purchase % in % has no recorded exchange rate',
        coalesce(nullif(new.original_reference, ''), new.id::text), new.currency
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_rate_required() from public, anon, authenticated;
drop trigger if exists purchase_rate_required on public.purchase_documents;
create trigger purchase_rate_required
  before update of state on public.purchase_documents
  for each row execute function public.purchase_rate_required();

-- ── saving a draft: 0461's, a supplier's bill in another currency ─────
-- With the feature on, a supplier's bill or credit note may be in another
-- currency than the space's; its rate comes in `exchange_rate` and is
-- recorded with it (the same rules as record_purchase_exchange_rate_v1).
-- A member's receipt stays in the space's currency: the member's account
-- is kept in it. A credit note is in its bill's currency.
create or replace function public.save_purchase_draft_v1(
  p_workspace_id uuid, p_request_id uuid, p_expected_revision int, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_id uuid := nullif(p_payload ->> 'purchase_id', '')::uuid;
  v_kind text;
  v_doc public.purchase_documents;
  v_ws public.workspaces;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_payer text;
  v_payer_member uuid;
  v_manager boolean;
  v_currency text;
  v_original uuid := nullif(p_payload ->> 'original_document_id', '')::uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || coalesce(p_expected_revision, 0)::text || p_payload::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'save', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_manager := public.has_permission(p_workspace_id, 'managePurchases');
  v_kind := coalesce(nullif(p_payload ->> 'kind', ''), 'member_receipt');
  if v_kind not in ('bill', 'credit_note', 'member_receipt') then
    raise exception 'unknown purchase kind';
  end if;
  if v_kind <> 'member_receipt' and not v_manager then
    raise exception 'not allowed to capture supplier bills';
  end if;
  v_currency := upper(coalesce(nullif(p_payload ->> 'currency', ''), v_ws.currency_code));
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'a currency is three capital letters'; end if;
  if v_currency <> v_ws.currency_code
     and (v_kind = 'member_receipt'
          or not public.feature_effective(p_workspace_id, 'foreignCurrencyPurchases')) then
    raise exception 'a purchase is in the currency of the space';
  end if;
  if v_supplier is not null and not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'unknown supplier';
  end if;
  if v_original is not null and (v_kind <> 'credit_note' or not exists (
       select 1 from public.purchase_documents o
        where o.id = v_original and o.workspace_id = p_workspace_id and o.kind = 'bill')) then
    raise exception 'a credit note reverses a bill of this space';
  end if;
  if v_original is not null and not exists (
       select 1 from public.purchase_documents o where o.id = v_original and o.currency = v_currency) then
    raise exception 'a credit note is in the currency of its bill';
  end if;
  if v_kind = 'member_receipt' then
    v_payer := 'member';
    v_payer_member := v_me;
  else
    v_payer := coalesce(nullif(p_payload ->> 'payer_kind', ''), 'unpaid');
    if v_payer not in ('workspace', 'member', 'unpaid') then raise exception 'unknown payer'; end if;
    v_payer_member := case when v_payer = 'member'
      then nullif(p_payload ->> 'payer_member_id', '')::uuid end;
    if v_payer = 'member' and not exists (
         select 1 from public.members m
          where m.id = v_payer_member and m.workspace_id = p_workspace_id) then
      raise exception 'unknown payer member';
    end if;
  end if;

  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then raise exception 'stale revision'; end if;
    insert into public.purchase_documents
      (workspace_id, kind, currency, category, supplier_id, original_reference, original_date,
       received_on, service_from, service_to, due_on, submitter_member_id, payer_kind,
       payer_member_id, original_document_id)
    values
      (p_workspace_id, v_kind, v_currency, left(coalesce(p_payload ->> 'category', ''), 80),
       v_supplier, left(coalesce(p_payload ->> 'original_reference', ''), 200),
       nullif(p_payload ->> 'original_date', '')::date, nullif(p_payload ->> 'received_on', '')::date,
       nullif(p_payload ->> 'service_from', '')::date, nullif(p_payload ->> 'service_to', '')::date,
       nullif(p_payload ->> 'due_on', '')::date, v_me, v_payer, v_payer_member, v_original)
    returning * into v_doc;
  else
    select * into v_doc from public.purchase_documents
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_doc.id is null then raise exception 'unknown purchase'; end if;
    if v_doc.kind = 'member_receipt' and v_doc.submitter_member_id <> v_me then
      raise exception 'not your purchase';
    end if;
    if v_doc.kind <> 'member_receipt' and not v_manager then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.kind <> v_kind then raise exception 'the kind of a purchase does not change'; end if;
    if v_doc.state <> 'draft' then raise exception 'only a draft can be edited'; end if;
    if v_doc.revision <> coalesce(p_expected_revision, 0) then raise exception 'stale revision'; end if;
    update public.purchase_documents set
        revision = revision + 1,
        currency = v_currency,
        category = left(coalesce(p_payload ->> 'category', ''), 80),
        supplier_id = v_supplier,
        original_reference = left(coalesce(p_payload ->> 'original_reference', ''), 200),
        original_date = nullif(p_payload ->> 'original_date', '')::date,
        received_on = nullif(p_payload ->> 'received_on', '')::date,
        service_from = nullif(p_payload ->> 'service_from', '')::date,
        service_to = nullif(p_payload ->> 'service_to', '')::date,
        due_on = nullif(p_payload ->> 'due_on', '')::date,
        payer_kind = v_payer, payer_member_id = v_payer_member,
        original_document_id = v_original
      where id = v_doc.id
      returning * into v_doc;
  end if;
  perform public.purchase_write_lines(p_workspace_id, v_doc.id, p_payload -> 'lines');
  -- The rate goes with the currency: back in the space's currency, a draft
  -- keeps none.
  if v_currency = v_ws.currency_code then
    delete from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase' and x.document_id = v_doc.id;
  elsif jsonb_typeof(p_payload -> 'exchange_rate') = 'object' then
    perform public.purchase_exchange_rate_write(p_workspace_id, v_doc.id, v_me, p_payload -> 'exchange_rate');
  else
    delete from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase'
       and x.document_id = v_doc.id and x.currency <> v_currency;
  end if;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                 'state', v_doc.state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) to authenticated;

-- ── the books: 0587's engine, restated whole ──────────────────────────
-- Only a purchase in another currency than the space's changes: booked at
-- its recorded rate, or blocked, named, without one.
create or replace function public.compute_postings(
  p_workspace_id uuid, p_issuer_site_id uuid, p_from date, p_to date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_postings jsonb := '[]'::jsonb;
  v_blockers jsonb := '{}'::jsonb;
  i record;
  m record;
  t record;
  v_lines jsonb;
  v_gross bigint;
  v_paid bigint;
  v_spent bigint;
  v_day date;
  v_rest bigint;
  v_left bigint;
  v_part bigint;
  v_tax bigint;
  v_n int;
  v_k int;
  d record;
  pl record;
  pay record;
  v_sign int;
  v_net bigint;
  v_rec bigint;
  v_grp text;
  v_default boolean;
  v_unqualified boolean;
  v_tz text;
  v_points jsonb;
  v_deferred uuid[];
  v_vat_role text;
  rel record;
  v_space text;
  v_converted jsonb;
  v_entry record;
  v_fx public.document_exchange_rates;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'you may not read the books' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'a period runs from a day to a later one' using errcode = '22023';
  end if;
  select s.country_code, s.is_default into v_country, v_default from public.sites s
   where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id;
  if not found then raise exception 'unknown issuer' using errcode = '22023'; end if;

  -- ── the tax points (0521) ─────────────────────────────────────────────
  -- The declaration's own engine (`vat_return_amounts`, 0402) dates the
  -- output tax of every invoice. Tax not exactly due on the invoice day
  -- waits on `vat_pending` and is released to `vat_output:<group>` on each
  -- tax point, as the FEC does it (`fec_writer.dart`).
  select coalesce(nullif(w.timezone, ''), 'UTC'), w.currency_code into v_tz, v_space
    from public.workspaces w where w.id = p_workspace_id;
  select coalesce(jsonb_agg(jsonb_build_object('id', a.invoice_id, 'on', a.tax_point, 'percent', a.percent,
                                               'category', a.category, 'vat', a.gross_cents - a.net_cents)), '[]'::jsonb)
    into v_points
    from public.vat_return_amounts(p_workspace_id, '1900-01-01', '9999-12-31') a;
  with pts as (
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, (e ->> 'vat')::bigint as vat
      from jsonb_array_elements(v_points) e
  ), docs as (
    select inv.id, (inv.issued_at at time zone v_tz)::date as issued,
           coalesce((select sum((e ->> 'vat_cents')::bigint)
                       from jsonb_array_elements(coalesce(inv.vat_totals, '[]'::jsonb)) e), 0) as vat
      from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
  )
  select coalesce(array_agg(docs.id), '{}') into v_deferred
    from docs
   where docs.vat <> 0
     and (exists (select 1 from pts where pts.id = docs.id and pts.vat <> 0 and pts.d <> docs.issued)
          or coalesce((select sum(pts.vat) from pts where pts.id = docs.id and pts.d = docs.issued), 0) <> docs.vat);

  -- ── the documents of the period ───────────────────────────────────────
  for i in
    select inv.* from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null
       and coalesce(inv.kind, '') <> 'settlement'
       and inv.issued_at::date between p_from and p_to
     order by inv.issued_at, inv.number
  loop
    v_day := i.issued_at::date;
    v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                           from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) e), i.total_cents);
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then v_gross := i.total_cents; end if;
    select coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'payment'), 0),
           coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'expense'), 0)
      into v_paid, v_spent
      from jsonb_array_elements(coalesce(i.lines, '[]'::jsonb)) l
     where coalesce((l ->> 'vat_percent')::numeric, 0) = 0 and (l ->> 'amount_cents')::bigint < 0;
    if v_gross - v_paid - v_spent <> i.total_cents then
      v_blockers := v_blockers || jsonb_build_object('unbalanced:' || i.number,
        jsonb_build_object('block', 'unbalanced', 'subject', i.number));
      continue;
    end if;
    v_lines := public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_gross, true);
    for t in
      select (e ->> 'net_cents')::bigint as net, (e ->> 'vat_cents')::bigint as vat,
             nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                              coalesce(e ->> 'category', 'S'), v_day), '') as grp
        from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
       order by n
    loop
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', t.grp, v_day, t.net, false);
      if t.vat <> 0 then
        v_vat_role := case when i.id = any(v_deferred) then 'vat_pending' else 'vat_output' end;
        v_lines := v_lines || public.posting_line(p_issuer_site_id, v_vat_role,
          case when v_vat_role = 'vat_pending' then null else t.grp end, v_day, t.vat, false);
      end if;
    end loop;
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', null, v_day, i.total_cents, false);
    end if;
    v_postings := v_postings || public.posting_entry('sales',
      case when i.total_cents < 0 then 'credit_note' else 'invoice' end, v_day, i.id, i.number, i.currency, v_lines);
    if v_paid <> 0 then
      v_postings := v_postings || public.posting_entry('bank', 'receipt', v_day, i.id, i.number, i.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, v_paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_paid, false));
    end if;
    -- A netted expense credit (v_spent) books nothing here (0524): the
    -- member's receipt booked the expense against the member's account
    -- when it was approved, and the netting only settles that account.
  end loop;

  -- ── receipts and write-offs dated in the period ───────────────────────
  -- A settlement's payment is allocated to its sources, oldest first and to
  -- the cent (accounting_view.dart); the settlement itself books nothing.
  for m in
    with own as (
      -- A refunded credit note's match holds the amount paid OUT, positive
      -- (0436): it is money leaving the bank, signed as such.
      select inv.id, inv.number, inv.currency, inv.total_cents, inv.vat_totals,
             (case when x.resolution = 'refunded' and inv.total_cents < 0 and x.paid_cents > 0
                   then -x.paid_cents else x.paid_cents end)::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices inv
        join public.invoice_matches x on x.invoice_id = inv.id and x.status = 'confirmed'
       where inv.workspace_id = p_workspace_id
         and (inv.site_id = p_issuer_site_id or inv.site_id is null)
         and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
    ), alloc as (
      select src.id, src.number, src.currency, src.total_cents, src.vat_totals,
             greatest(least(src.total_cents::bigint,
                            x.paid_cents - coalesce(sum(s.total) over (
                              partition by st.id order by s.n rows between unbounded preceding and 1 preceding), 0)),
                      0)::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices st
        join public.invoice_matches x on x.invoice_id = st.id and x.status = 'confirmed'
        cross join lateral (
          select (e ->> 'invoice_id')::uuid as invoice_id, (e ->> 'total_cents')::bigint as total, n
            from jsonb_array_elements(coalesce(st.settles, '[]'::jsonb)) with ordinality y(e, n)) s
        join public.invoices src on src.id = s.invoice_id
       where st.workspace_id = p_workspace_id and st.kind = 'settlement' and st.voided_at is null
    )
    select * from own union all select * from alloc where paid > 0
  loop
    if m.matched_at::date between p_from and p_to and m.paid <> 0 then
      v_day := m.matched_at::date;
      v_postings := v_postings || public.posting_entry('bank',
        case when m.paid < 0 then 'refund' else 'receipt' end, v_day, m.id, m.number, m.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false));
    end if;
    v_rest := m.total_cents - m.paid;
    if m.writeoff_at is not null and m.writeoff_at::date between p_from and p_to and v_rest > 0 then
      v_day := m.writeoff_at::date;
      v_lines := '[]'::jsonb;
      v_n := greatest(jsonb_array_length(coalesce(m.vat_totals, '[]'::jsonb)), 1);
      v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                             from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) e), 0);
      v_left := v_rest;
      v_k := 0;
      for t in
        select ((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint) as gross,
               (e ->> 'vat_cents')::bigint as vat,
               nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                                coalesce(e ->> 'category', 'S'), v_day), '') as grp
          from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
         order by n
      loop
        v_k := v_k + 1;
        v_part := case when v_k = v_n or v_gross = 0 then v_left else (v_rest * t.gross) / v_gross end;
        v_left := v_left - v_part;
        v_tax := case when t.gross = 0 then 0 else (v_part * t.vat) / t.gross end;
        -- A deferred invoice's unpaid tax never left vat_pending (0526).
        v_lines := v_lines
          || public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_part - v_tax, true)
          || case when m.id = any(v_deferred)
                  then public.posting_line(p_issuer_site_id, 'vat_pending', null, v_day, v_tax, true)
                  else public.posting_line(p_issuer_site_id, 'vat_output', t.grp, v_day, v_tax, true) end;
      end loop;
      if v_k = 0 then
        v_lines := public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_rest, true);
      end if;
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_rest, false);
      v_postings := v_postings || public.posting_entry('other', 'write_off', v_day, m.id, m.number, m.currency, v_lines);
    end if;
  end loop;

  -- ── the output tax released on its tax points (0521) ──────────────────
  for rel in
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, inv.number, inv.currency,
           nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                            coalesce(e ->> 'category', 'S'), (e ->> 'on')::date), '') as grp,
           sum((e ->> 'vat')::bigint)::bigint as vat
      from jsonb_array_elements(v_points) e
      join public.invoices inv on inv.id = (e ->> 'id')::uuid
     where (e ->> 'id')::uuid = any(v_deferred)
       and (e ->> 'on')::date between p_from and p_to
     group by 1, 2, 3, 4, 5
    having sum((e ->> 'vat')::bigint) <> 0
     order by 2, 3, 5
  loop
    v_postings := v_postings || public.posting_entry('other', 'vat_release', rel.d, rel.id, rel.number, rel.currency,
      public.posting_line(p_issuer_site_id, 'vat_pending', null, rel.d, rel.vat, true)
      || public.posting_line(p_issuer_site_id, 'vat_output', rel.grp, rel.d, rel.vat, false));
  end loop;

  -- ── purchases and the money paid on them (0519, 0524) ─────────────────
  -- A purchase document names no issuer: the workspace's default issuer
  -- books it. A supplier's bill is owed to `suppliers`; a member's receipt
  -- is credited to the member's account (`customers`), which an invoice
  -- later nets or a reimbursement pays.
  if v_default then
    for d in
      select pd.* from public.purchase_documents pd
       where pd.workspace_id = p_workspace_id and pd.state = 'approved'
         and (pd.kind = 'member_receipt'
              or (pd.kind in ('bill', 'credit_note')
                  and exists (select 1 from public.purchase_obligations o
                               where o.purchase_id = pd.id and o.creditor_kind = 'supplier')))
         and coalesce(pd.original_date, pd.received_on) between p_from and p_to
       order by coalesce(pd.original_date, pd.received_on), pd.original_reference
    loop
      v_day := coalesce(d.original_date, d.received_on);
      v_sign := case when d.kind = 'credit_note' then -1 else 1 end;
      v_lines := '[]'::jsonb;
      v_gross := 0;
      -- A taxed line whose deductible share is not qualified yet is never
      -- guessed: the bill waits, named.
      v_unqualified := exists (select 1 from public.purchase_lines q
                                where q.purchase_id = d.id and coalesce(q.tax_cents, 0) <> 0
                                  and q.recoverable_tax_cents is null);
      if v_unqualified then
        v_blockers := v_blockers || jsonb_build_object('unclassifiedTax:' || d.original_reference,
          jsonb_build_object('block', 'unclassifiedTax', 'subject', d.original_reference));
        continue;
      end if;
      for pl in select * from public.purchase_lines where purchase_id = d.id order by line_no loop
        v_tax := coalesce(pl.tax_cents, 0);
        v_rec := coalesce(pl.recoverable_tax_cents, 0);
        v_net := coalesce(pl.net_cents, pl.gross_cents - v_tax);
        v_gross := v_gross + pl.gross_cents;
        v_grp := case when pl.tax_rate_percent is null then null
                      else nullif(public.posting_rate_group(v_country, pl.tax_rate_percent, 'S', v_day), '') end;
        -- What the line is for decides its debit (0587): equipment, stock,
        -- a prepayment or a deposit is not an operating cost; an unmapped
        -- role blocks, named, instead of falling back to `expenses`.
        v_lines := v_lines || public.posting_line(p_issuer_site_id,
          case pl.recognition_kind
            when 'asset' then 'fixed_assets'
            when 'stock' then 'stock'
            when 'prepayment' then 'prepayments'
            when 'deposit' then 'deposits'
            else 'expenses' end, null, v_day,
                                                  v_sign * (v_net + v_tax - v_rec), true);
        if v_rec <> 0 then
          v_lines := v_lines || public.posting_line(p_issuer_site_id, 'vat_input', v_grp, v_day, v_sign * v_rec, true);
        end if;
      end loop;
      v_lines := v_lines || public.posting_line(p_issuer_site_id,
        case when d.kind = 'member_receipt' then 'customers' else 'suppliers' end,
        null, v_day, v_sign * v_gross, false);
      v_postings := v_postings || public.posting_entry('purchases',
        case when d.kind = 'member_receipt' then 'member_receipt'
             when v_sign < 0 then 'supplier_credit_note' else 'supplier_bill' end,
        v_day, d.id, d.original_reference, d.currency, v_lines);
    end loop;

    for pay in
      select a.amount_cents::bigint as amount, pd.id, pd.original_reference, pd.currency,
             coalesce(p.reported_paid_on, (a.created_datetime at time zone 'UTC')::date) as paid_on,
             o.creditor_kind
        from public.purchase_settlement_allocations a
        join public.purchase_obligations o on o.id = a.obligation_id
        join public.purchase_documents pd on pd.id = o.purchase_id
        left join public.outgoing_payments p on p.workspace_id = a.workspace_id and p.id = a.payment_id
       where a.workspace_id = p_workspace_id and a.kind = 'payment'
         and pd.state = 'approved' and pd.kind in ('bill', 'credit_note', 'member_receipt')
         and not exists (select 1 from public.purchase_settlement_allocations r where r.original_allocation_id = a.id)
       order by 5, a.created_datetime, a.id
    loop
      if pay.paid_on between p_from and p_to then
        v_postings := v_postings || public.posting_entry('bank',
          case when pay.creditor_kind = 'member' then 'reimbursement' else 'supplier_payment' end,
          pay.paid_on, pay.id, pay.original_reference, pay.currency,
          public.posting_line(p_issuer_site_id,
            case when pay.creditor_kind = 'member' then 'customers' else 'suppliers' end,
            null, pay.paid_on, pay.amount, true)
          || public.posting_line(p_issuer_site_id, 'bank', null, pay.paid_on, pay.amount, false));
      end if;
    end loop;
  end if;

  -- ── a purchase in another currency, at its recorded rate ──────────────
  -- A purchase document in another currency than the space's is booked,
  -- with its payments, in the space's currency at the rate recorded with it
  -- (`posting_at_rate`); each line keeps its original amount and the entry
  -- names its original currency and rate. Without a recorded rate the
  -- entry blocks, named `reference (currency)`. An invoice is issued in the
  -- space's currency and passes as it is.
  v_converted := '[]'::jsonb;
  for v_entry in select p from jsonb_array_elements(v_postings) p loop
    if v_entry.p ->> 'currency' = v_space
       or v_entry.p ->> 'kind' not in ('supplier_bill', 'supplier_credit_note', 'member_receipt',
                                 'supplier_payment', 'reimbursement') then
      v_converted := v_converted || jsonb_build_array(v_entry.p);
      continue;
    end if;
    select * into v_fx from public.document_exchange_rates x
     where x.workspace_id = p_workspace_id and x.document_kind = 'purchase'
       and x.document_id = (v_entry.p ->> 'document_id')::uuid
       and x.currency = v_entry.p ->> 'currency' and x.functional_currency = v_space;
    if v_fx.id is null then
      v_grp := coalesce(nullif(v_entry.p ->> 'document_number', ''), v_entry.p ->> 'document_id')
               || ' (' || (v_entry.p ->> 'currency') || ')';
      v_blockers := v_blockers || jsonb_build_object('missingRate:' || v_grp,
        jsonb_build_object('block', 'missingRate', 'subject', v_grp));
      continue;
    end if;
    v_converted := v_converted || jsonb_build_array(
      public.posting_at_rate(v_entry.p, v_space, v_fx.rate, v_fx.rate_date, v_fx.source));
  end loop;
  v_postings := v_converted;

  -- ── what blocks, each named once ──────────────────────────────────────
  select v_blockers || coalesce(jsonb_object_agg(b ->> 'block' || ':' || (b ->> 'subject'), b), '{}'::jsonb)
    into v_blockers
    from jsonb_array_elements(v_postings) p, jsonb_array_elements(p -> 'lines') l,
         lateral (select l -> 'blocked' as b) q
   where l ? 'blocked';

  return jsonb_build_object(
    'period', jsonb_build_object('from', p_from, 'to', p_to),
    'postings', coalesce((
      select jsonb_agg(jsonb_set(p, '{lines}', coalesce((
               select jsonb_agg(l order by n) from jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
                where not l ? 'blocked'), '[]'::jsonb))
             order by (p ->> 'date'), array_position(array['sales', 'bank', 'purchases', 'other'], p ->> 'journal'),
                      (p ->> 'document_number'))
        from jsonb_array_elements(v_postings) p), '[]'::jsonb),
    'blockers', coalesce((select jsonb_agg(v order by k) from jsonb_each(v_blockers) e(k, v)), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.compute_postings(uuid, uuid, date, date) from public, anon;
grant execute on function public.compute_postings(uuid, uuid, date, date) to authenticated;

-- ── the purchases "full" level carries it (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","calendarFileExport"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","multiSite","publicHolidays","holidayImport","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields","guestParticipation"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["planMemberPhotos","uniqueMonograms","singleRoomLevelNames"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","placeFeedback","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(590);
