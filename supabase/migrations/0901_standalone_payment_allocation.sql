-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (two columns with a constant default, one trigger, three new functions, five functions patched; no row changes)
--
-- #4165 B1 -- paying standalone invoices. A standalone invoice has no month, so it cannot be paid through the monthly
-- claim (check_payment_claim keys a payment to one month). Two versioned adapters take a standalone selection under an
-- EXPLICIT allocation mode: `open_standalone_payment_intent_v1` (online) and `record_standalone_payment_v1` (declared,
-- or recorded by whoever issues the invoices). They run the same claim, lock order, amount and settlement machinery
-- (apply_payment_claim -> match_invoice_part); only the month rules are replaced by a check that every invoice is
-- standalone, of this financial subject, in the business's currency and still payable. A selection mixing monthly and
-- standalone invoices is refused on both paths.
--
-- The mode travels with the money: the intent, its captured credit, the credit of an approved declaration and the
-- credit-note excess derived from an explicit payment carry `explicit`. The posting month of an explicit credit is the
-- month it was received in the business's calendar (the capture day, or the declared paid_on), never an invoice's.
-- Explicit credits are spent only by their allocations: the monthly derivation (invoice_lines_for) does not deduct them
-- from a month's bill, and the "credit already deducted on an issued invoice" heuristic of match_invoice_part and the
-- customer statement applies to legacy credits only. Every existing row and caller stays `legacy` and behaves as before.

-- ── 1. the mode ──────────────────────────────────────────────────────────
-- audience: all row readers
alter table public.payment_intents
  add column if not exists allocation_mode text not null default 'legacy'
    constraint payment_intents_allocation_mode_check check (allocation_mode in ('legacy', 'explicit'));
alter table public.ledger_entries
  add column if not exists allocation_mode text not null default 'legacy'
    constraint ledger_entries_allocation_mode_check check (allocation_mode in ('legacy', 'explicit'));
comment on column public.payment_intents.allocation_mode is
  '#4165 -- legacy: a payment keyed to a month (every payment before standalone invoices); explicit: a standalone payment whose allocations alone decide what it pays';
comment on column public.ledger_entries.allocation_mode is
  '#4165 -- legacy: a credit the monthly derivation may deduct from its period''s bill; explicit: a credit spent only by its allocations (invoice_match_payments)';

-- The credit an owner's approval posts for a declared payment (respond_to_event) takes the mode its declaration named.
create or replace function public.ledger_payment_allocation_mode()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.kind = 'credit' and new.category = 'payment'
     and exists (select 1 from public.events e
                  where e.id = new.event_id and e.type = 'payment'
                    and e.payload ->> 'allocation_mode' = 'explicit') then
    new.allocation_mode := 'explicit';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.ledger_payment_allocation_mode() from public, anon, authenticated;
drop trigger if exists ledger_payment_allocation_mode on public.ledger_entries;
create trigger ledger_payment_allocation_mode before insert on public.ledger_entries
  for each row when (new.event_id is not null)
  execute function public.ledger_payment_allocation_mode();

-- ── 2. the standalone claim ──────────────────────────────────────────────
-- What check_payment_claim checks, without its month: one answer for an invoice that is not the subject's, the
-- standalone source, the currency, payable now, in no other open claim.
create or replace function public.check_standalone_payment_claim(p_workspace uuid, p_subject uuid, p_ids uuid[], p_currency text)
returns void language plpgsql stable security definer set search_path = public as $fn$
declare
  v_bad text;
begin
  if coalesce(cardinality(p_ids), 0) = 0 then
    raise exception 'a payment of invoices names at least one invoice' using errcode = 'DKC01';
  end if;
  if exists (select 1 from unnest(p_ids) x
              where not exists (select 1 from public.invoices i
                                 where i.id = x and i.workspace_id = p_workspace
                                   and i.member_id = p_subject)) then
    raise exception 'an invoice of this payment is not one of yours to pay' using errcode = 'DKC02';
  end if;
  select string_agg(i.number, ', ' order by i.number) into v_bad
    from public.invoices i where i.id = any (p_ids) and i.source <> 'standalone';
  if v_bad is not null then
    raise exception 'monthly and standalone invoices are paid separately: pay % with its month', v_bad
      using errcode = 'DKC16';
  end if;
  select string_agg(i.number || ' (' || i.currency || ')', ', ' order by i.number) into v_bad
    from public.invoices i
   where i.id = any (p_ids) and upper(i.currency) <> upper(p_currency);
  if v_bad is not null then
    raise exception 'a payment in % settles invoices in %: not %', p_currency, p_currency, v_bad
      using errcode = 'DKC11';
  end if;
  select string_agg(i.number, ', ' order by i.number) into v_bad
    from public.invoices i
   where i.id = any (p_ids) and public.invoice_match_blocker(i.id) is not null;
  if v_bad is not null then
    raise exception '% cannot take a payment now', v_bad using errcode = 'DKC05';
  end if;
  select string_agg(format('%s is already in %s', i.number, o.reason), '; ' order by i.number) into v_bad
    from public.open_claim_invoices(p_workspace) o
    join public.invoices i on i.id = o.invoice_id
   where o.invoice_id = any (p_ids);
  if v_bad is not null then
    raise exception '%', v_bad using errcode = 'DKC06';
  end if;
end;
$fn$;
revoke execute on function public.check_standalone_payment_claim(uuid, uuid, uuid[], text) from public, anon, authenticated;

-- ── 3. the online payment of a standalone selection ──────────────────────
-- open_payment_intent's rules (feature, payer, currency, amount, request id, one open claim per invoice) with the
-- standalone claim. The intent's period is request bookkeeping only (the month it was opened); the capture posts the
-- credit in the month it is captured. A request id is required: a retry names the same payment.
create or replace function public.open_standalone_payment_intent_v1(
  p_workspace_id uuid, p_financial_subject_id uuid, p_provider text, p_amount_cents integer, p_currency text,
  p_request_id uuid, p_invoice_ids uuid[])
returns table(id uuid, reference text, status text, order_id text, created_at timestamptz, reused boolean)
language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid := gen_random_uuid();
  v_ref text;
  v_ws_currency text;
  v_me public.members;
  v_old public.payment_intents;
  v_claim uuid[];
  v_due bigint;
begin
  v_me := public.my_active_member(p_workspace_id);
  if not public.feature_operation_allowed(p_workspace_id, 'onlinePayments', 'accept_new') then
    raise exception 'online payments are off in this workspace' using errcode = 'P0001';
  end if;
  if p_financial_subject_id is distinct from v_me.id and not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'a payment is opened for yourself, or by whoever issues the invoices' using errcode = 'P0001';
  end if;
  select upper(currency_code) into v_ws_currency from public.workspaces w where w.id = p_workspace_id;
  if v_ws_currency is null then raise exception 'unknown workspace' using errcode = 'P0001'; end if;
  if upper(coalesce(p_currency, '')) <> v_ws_currency then
    raise exception 'a payment is taken in the workspace currency (%), not %', v_ws_currency, p_currency using errcode = 'P0001';
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'a payment intent needs a positive amount' using errcode = 'P0001';
  end if;
  if p_request_id is null then
    raise exception 'a standalone payment names its request id' using errcode = 'P0001';
  end if;
  v_claim := array(select distinct x from unnest(coalesce(p_invoice_ids, array[]::uuid[])) x where x is not null order by 1);

  -- The same lock and lookup as open_payment_intent: one request id names one payment, whichever adapter opened it.
  perform pg_advisory_xact_lock(hashtextextended('payment_request:' || p_workspace_id::text || ':' || p_request_id::text, 0));
  select * into v_old from public.payment_intents i
    where i.workspace_id = p_workspace_id and i.request_id = p_request_id;
  if found then
    if v_old.allocation_mode <> 'explicit' or v_old.member_id <> p_financial_subject_id
       or v_old.provider <> p_provider or v_old.amount_cents <> p_amount_cents
       or upper(v_old.currency) <> v_ws_currency
       or v_old.claimed_invoice_ids is distinct from v_claim then
      raise exception 'payment request conflict: this request id was opened with another payment' using errcode = 'P0001';
    end if;
    if v_old.claim_withdrawn_at is not null then
      raise exception 'the invoices of this payment were withdrawn: a new payment names them again'
        using errcode = 'DKC12';
    end if;
    return query select v_old.id, v_old.reference, v_old.status, v_old.order_id, v_old.created_at, true;
    return;
  end if;

  -- The #3671 lock order: the subject's invoices by id, before the check.
  perform 1 from public.invoices i
   where i.id = any (v_claim) and i.workspace_id = p_workspace_id and i.member_id = p_financial_subject_id
   order by i.id for update;
  perform public.check_standalone_payment_claim(p_workspace_id, p_financial_subject_id, v_claim, v_ws_currency);
  select sum(public.invoice_still_due_cents(x)) into v_due from unnest(v_claim) x;
  if p_amount_cents <> v_due then
    raise exception 'a payment of these invoices is what they still owe (% in minor units), not %', v_due, p_amount_cents
      using errcode = 'DKC07';
  end if;

  v_ref := public.next_document_number(p_workspace_id, 'payment');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency,
                                      reference, request_id, claimed_invoice_ids, allocation_mode)
  values (v_id, p_workspace_id, p_financial_subject_id, p_provider, 'pending:' || v_id::text,
          to_char(public.workspace_today(p_workspace_id), 'YYYY-MM'), p_amount_cents, v_ws_currency,
          v_ref, p_request_id, v_claim, 'explicit');
  return query select i.id, i.reference, i.status, i.order_id, i.created_at, false
    from public.payment_intents i where i.id = v_id;
end;
$fn$;
revoke execute on function public.open_standalone_payment_intent_v1(uuid, uuid, text, integer, text, uuid, uuid[]) from public, anon;
grant execute on function public.open_standalone_payment_intent_v1(uuid, uuid, text, integer, text, uuid, uuid[]) to authenticated;

-- ── 4. the declared (or recorded) payment of a standalone selection ──────
-- record_payment's rules with the standalone claim. Its posting month is the month of paid_on; without invoices it is
-- an explicit unapplied credit once approved, spent only by a later allocation.
create or replace function public.record_standalone_payment_v1(
  p_workspace_id uuid, p_financial_subject_id uuid, p_amount_cents integer, p_note text, p_method text,
  p_paid_on date, p_invoice_ids uuid[], p_request_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_event_id uuid;
  v_today date := public.workspace_today(p_workspace_id);
  v_paid_on date := coalesce(p_paid_on, v_today);
  v_claim uuid[];
  v_due bigint;
  v_payload jsonb;
  v_currency text;
  v_digest text;
  v_first public.events;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member' using errcode = 'P0001'; end if;
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'amount must be positive' using errcode = 'P0001'; end if;
  if p_financial_subject_id is distinct from v_actor.id and not (v_actor.is_admin or v_actor.is_owner
       or public.has_permission(p_workspace_id, 'issueInvoices')) then
    raise exception 'only admins record payments for others' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.members m
                  where m.id = p_financial_subject_id and m.workspace_id = p_workspace_id) then
    raise exception 'an invoice of this payment is not one of yours to pay' using errcode = 'DKC02';
  end if;
  if p_method is not null and length(p_method) > 32 then raise exception 'method too long' using errcode = 'P0001'; end if;
  if p_request_id is null then
    raise exception 'a standalone payment names its request id' using errcode = 'P0001';
  end if;
  if coalesce(cardinality(p_invoice_ids), 0) > 0 then
    v_claim := array(select distinct x from unnest(p_invoice_ids) x where x is not null order by 1);
  end if;
  -- One request id, one declaration, as record_payment: the 'standalone' tag keeps its digest apart from a monthly one.
  v_digest := md5(jsonb_build_array('standalone', p_financial_subject_id, p_amount_cents, p_note, p_method, p_paid_on, v_claim)::text);
  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text || ':' || v_actor.id::text || ':' || p_request_id::text, 0));
  select * into v_first from public.events e
   where e.workspace_id = p_workspace_id and e.type = 'payment' and e.actor_member_id = v_actor.id
     and e.payload ->> 'request_id' = p_request_id::text;
  if v_first.id is not null then
    if v_first.payload ->> 'request_digest' is distinct from v_digest then
      raise exception 'this request id was used for another payment' using errcode = 'DKC15';
    end if;
    return v_first.id;
  end if;
  if v_paid_on > v_today then
    raise exception 'payment date is in the future' using errcode = 'P0001';
  end if;
  select upper(w.currency_code) into v_currency from public.workspaces w where w.id = p_workspace_id;
  if v_claim is not null then
    perform 1 from public.invoices i
     where i.id = any (v_claim) and i.workspace_id = p_workspace_id and i.member_id = p_financial_subject_id
     order by i.id for update;
    perform public.check_standalone_payment_claim(p_workspace_id, p_financial_subject_id, v_claim, v_currency);
    select sum(public.invoice_still_due_cents(x)) into v_due from unnest(v_claim) x;
    if p_amount_cents <> v_due then
      raise exception 'a payment of these invoices is what they still owe (% in minor units), not %', v_due, p_amount_cents
        using errcode = 'DKC07';
    end if;
  end if;
  v_payload := jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', coalesce(p_note, ''),
      'method', coalesce(p_method, ''),
      'paid_on', v_paid_on,
      'period', to_char(v_paid_on, 'YYYY-MM'),
      'allocation_mode', 'explicit',
      'currency', v_currency,
      'request_id', p_request_id,
      'request_digest', v_digest);
  if v_claim is not null then
    v_payload := v_payload || jsonb_build_object('claim', (
      select jsonb_agg(jsonb_build_object('invoice_id', i.id, 'number', i.number)
                       order by i.issued_at nulls last, i.number)
        from public.invoices i where i.id = any (v_claim)));
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (p_workspace_id, 'payment', 'submitted', v_actor.id, p_financial_subject_id, v_payload, 'pending')
  returning id into v_event_id;
  return v_event_id;
end;
$fn$;
revoke execute on function public.record_standalone_payment_v1(uuid, uuid, integer, text, text, date, uuid[], uuid) from public, anon;
grant execute on function public.record_standalone_payment_v1(uuid, uuid, integer, text, text, date, uuid[], uuid) to authenticated;

-- ── 5. the capture posts an explicit payment in the month it arrived ─────
-- Restated from 0797 with one branch: an explicit intent's credit carries its mode and is dated by the capture, in the
-- business's calendar; a legacy one is posted as before, in the intent's month.
create or replace function public.settle_online_payment(p_provider text, p_order_id text, p_capture_id text, p_amount_cents integer)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_intent public.payment_intents;
  v_ledger uuid;
  v_claim_open boolean;
  v_on date;
  v_period text;
begin
  select * into v_intent from public.payment_intents
    where provider = p_provider and order_id = p_order_id
    for update;
  if v_intent.id is null then
    raise exception 'unknown payment intent %/%', p_provider, p_order_id using errcode = 'P0001';
  end if;
  if v_intent.status in ('captured', 'reversed') then return; end if;
  if p_amount_cents is not null and p_amount_cents <> v_intent.amount_cents then
    raise exception 'captured amount % does not match the intent (%)', p_amount_cents, v_intent.amount_cents using errcode = 'P0001';
  end if;
  v_claim_open := public.payment_intent_claim_open(v_intent);
  if v_intent.allocation_mode = 'explicit' then
    v_on := public.workspace_today(v_intent.workspace_id);
    v_period := to_char(v_on, 'YYYY-MM');
  else
    v_period := v_intent.period;
  end if;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period,
                                     occurred_on, allocation_mode)
  values (v_intent.workspace_id, v_intent.member_id, 'credit', 'payment', v_intent.amount_cents,
          p_provider || ' online payment', v_period, v_on, v_intent.allocation_mode)
  returning id into v_ledger;
  update public.payment_intents
     set status = 'captured', capture_id = p_capture_id, ledger_entry_id = v_ledger
   where public.payment_intents.id = v_intent.id;
  if v_claim_open then
    update public.payment_intents
       set claim_outcome = public.apply_payment_claim(v_ledger, v_intent.claimed_invoice_ids,
             v_intent.member_id, v_intent.id, v_intent.currency)
     where public.payment_intents.id = v_intent.id;
  end if;
end;
$fn$;
revoke execute on function public.settle_online_payment(text, text, text, integer) from public, anon, authenticated;

-- ── 6. the month heuristics apply to legacy credits only ─────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $patch$
declare
  v_def text;
  v_new text;
begin
  -- match_invoice_part: the "already deducted on an issued invoice" rule reads a credit's month, so it binds legacy
  -- credits only; the credit-note excess of an explicit payment stays explicit.
  select pg_get_functiondef('public.match_invoice_part(public.members, uuid, uuid, text, text, integer, uuid)'::regprocedure)
    into v_def;
  v_new := pg_temp.anchor_replace(v_def,
    E'where i.member_id = v_invoice.member_id\n      and i.period = v_payment.period',
    E'where v_payment.allocation_mode = ''legacy'' and i.member_id = v_invoice.member_id\n      and i.period = v_payment.period');
  if v_new is null then raise exception '0901: match_invoice_part heuristic anchor missing'; end if;
  v_def := v_new;
  v_new := pg_temp.anchor_replace(v_def,
    E'description, period)',
    E'description, period, allocation_mode)');
  if v_new is null then raise exception '0901: match_invoice_part credit columns anchor missing'; end if;
  v_def := v_new;
  v_new := pg_temp.anchor_replace(v_def,
    E'''YYYY-MM''))\n    returning id into v_credit_id;',
    E'''YYYY-MM''), v_payment.allocation_mode)\n    returning id into v_credit_id;');
  if v_new is null then raise exception '0901: match_invoice_part credit values anchor missing'; end if;
  execute v_new;

  -- customer_statement_items: a credit hidden as "deducted on a later issued invoice of its month" is a legacy one.
  select pg_get_functiondef('public.customer_statement_items(uuid, uuid, timestamptz)'::regprocedure) into v_def;
  v_new := pg_temp.anchor_replace(v_def,
    E'where i.workspace_id = p_workspace_id and i.member_id = p_member_id\n                            and i.period = le.period',
    E'where le.allocation_mode = ''legacy'' and i.workspace_id = p_workspace_id and i.member_id = p_member_id\n                            and i.period = le.period');
  if v_new is null then raise exception '0901: customer_statement_items anchor missing'; end if;
  execute v_new;

  -- invoice_lines_for: a month's bill deducts the legacy credits of its month; an explicit credit is spent only by
  -- its allocations, never swept into a monthly invoice.
  select pg_get_functiondef('public.invoice_lines_for(uuid, text)'::regprocedure) into v_def;
  v_new := pg_temp.anchor_replace(v_def,
    E'and le.period = p_period\n',
    E'and le.period = p_period\n       and (le.kind <> ''credit'' or le.allocation_mode = ''legacy'')\n');
  if v_new is null then raise exception '0901: invoice_lines_for anchor missing'; end if;
  execute v_new;

  -- check_payment_claim: the monthly path names the standalone invoices it leaves to their own payment.
  select pg_get_functiondef('public.check_payment_claim(uuid, uuid, uuid[], text, text)'::regprocedure) into v_def;
  v_new := pg_temp.anchor_replace(v_def,
    E'''a standalone invoice is not paid through a month-keyed claim yet''',
    E'''monthly and standalone invoices are paid separately: pay the standalone ones on their own''');
  if v_new is null then raise exception '0901: check_payment_claim anchor missing'; end if;
  execute v_new;
end;
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(901);
