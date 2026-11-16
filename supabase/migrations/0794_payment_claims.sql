-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (match_invoice, open_payment_intent, record_payment and
--  settle_online_payment are restated whole; two columns, three helpers, a
--  trigger and one member action are new; no stored value moves)
--
-- #3556 (1a) -- a payment can name the invoices it pays (its claim), and is
-- then applied to them.
--
--   * open_payment_intent and record_payment take an optional list of the
--     member's own invoices. With it, the payment is exactly what those
--     invoices still owe (another amount is refused), they are of one
--     business, one currency and one month (a selection that spans months
--     is refused naming the months), none is settled, void or already in a
--     payment being processed. Another member's invoice, an unknown one and
--     another business's one get one and the same answer, before anything
--     about them is read back. Without the list both act exactly as before.
--   * The claim is stored with the payment: `claimed_invoice_ids` on the
--     online intent, `claim` (each invoice's id and number) in the declared
--     payment's event, which is what the owner reads when deciding.
--   * A claim is open while its payment is: an online intent not yet
--     captured, failed or withdrawn by the member; a declared payment not
--     yet approved, refused or expired. Each of these ends frees the claimed
--     invoices for another payment.
--   * When the money arrives (the provider's capture, the owner's approval
--     of the declared payment), the claim is applied oldest invoice first,
--     each part at what the invoice still owes then, through the same rule a
--     person's match follows (match_invoice_part): where the business has a
--     validation policy for invoice payments each part waits for its
--     validators, otherwise it stands at once. A part's event is the
--     payer's and names the claim. What an invoice no longer needs (paid
--     otherwise meanwhile) stays the payer's credit on the payment, never
--     dropped and never put on an invoice the claim did not name.
--   * match_invoice keeps its rules: its body after the permission check is
--     match_invoice_part, its only other callers the two settlements.

alter table public.payment_intents add column if not exists claimed_invoice_ids uuid[];
alter table public.payment_intents add column if not exists claim_withdrawn_at timestamptz;

-- ── 1. a match, whoever made it ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.match_invoice_part(p_actor public.members, p_invoice_id uuid, p_payment_ledger_id uuid, p_resolution text, p_note text DEFAULT ''::text, p_amount_cents integer DEFAULT NULL::integer, p_claim_source uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.invoices;
  v_existing public.invoice_matches;
  v_payment public.ledger_entries;
  v_paid int;
  v_due int;
  v_actor public.members := p_actor;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
  v_additional boolean := false;
  v_left bigint;
begin
  -- #3671: one lock order everywhere: the invoice, its aggregate, then the
  -- payment; two parts against one remainder wait for each other.
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'unknown invoice' using errcode = 'P0001'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided' using errcode = 'DKI03';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled' using errcode = 'P0001';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id for update;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched' using errcode = 'DKI06';
    end if;
    v_additional := true;
    -- #3671: what is still due also leaves out the parts awaiting approval.
    v_due := public.invoice_still_due_cents(p_invoice_id);
  else
    v_due := v_invoice.total_cents;
  end if;
  -- #3671: an invoice a waiting part already covers takes nothing more,
  -- not even an intended overpayment.
  if v_due <= 0 then
    raise exception 'nothing is due on this invoice' using errcode = 'P0001';
  end if;
  -- #3556 — who matches was decided by the caller: match_invoice checks
  -- the permission of the person; a claim's settlement names the payer.

  -- #512 — settlement sources: registered payments AND account credits
  -- (category 'adjustment': credit-note excess) — the imputation of an
  -- avoir on any outstanding invoice, past months included.
  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category in ('payment', 'adjustment')
    for update;
  if v_payment.id is null then raise exception 'unknown payment' using errcode = 'P0001'; end if;
  -- A credit already BAKED into an issued invoice (negative line at
  -- derivation) was spent there — it cannot settle a second document.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_invoice.member_id
      and i.period = v_payment.period
      and i.voided_at is null
      and i.issued_at > v_payment.created_at) then
    raise exception 'credit already deducted on an issued invoice' using errcode = 'P0001';
  end if;
  -- #3671: a payment may settle several invoices, each its own part; what
  -- is left of it is its amount less the parts already taken. Without an
  -- amount the whole remainder settles this invoice, as before.
  v_left := v_payment.amount_cents - public.payment_used_cents(p_payment_ledger_id);
  if v_left <= 0 or exists (select 1 from public.invoice_match_payments
                             where payment_ledger_id = p_payment_ledger_id
                               and invoice_id = p_invoice_id) then
    raise exception 'payment already matched' using errcode = 'P0001';
  end if;
  if p_amount_cents is not null and (p_amount_cents <= 0 or p_amount_cents > v_left) then
    raise exception 'the amount is more than what is left of the payment' using errcode = 'P0001';
  end if;
  v_paid := coalesce(p_amount_cents, v_left);

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution' using errcode = 'P0001';
  end if;
  -- All amount rules compare against what is STILL DUE (#506).
  if p_resolution = 'exact' and v_paid <> v_due then
    raise exception 'amount does not match the invoice' using errcode = 'P0001';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_due then
    raise exception 'amount does not exceed the invoice' using errcode = 'P0001';
  end if;
  if p_resolution = 'under_accepted' and v_paid >= v_due then
    raise exception 'amount is not below the invoice' using errcode = 'P0001';
  end if;
  if p_resolution in ('over_forced','under_accepted') and v_note = '' then
    raise exception 'a note is required' using errcode = 'P0001';
  end if;

  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  if p_resolution = 'over_credit_note' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents,
       description, period)
    values
      (v_invoice.workspace_id, v_invoice.member_id, 'credit',
       'adjustment', v_paid - v_due,
       'Credit note ' || v_invoice.number
         || case when v_note = '' then '' else ' — ' || v_note end,
       to_char(now(), 'YYYY-MM'))
    returning id into v_credit_id;
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and (vp.event_type = 'invoice_payment' or vp.event_type is null));

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_due,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note,
       'additional', v_additional)
     -- #3556 — a part a claim applied names its claim (the intent or the
     -- declared payment), so the history tells it from a person's match.
     || case when p_claim_source is null then '{}'::jsonb
             else jsonb_build_object('claim_source', p_claim_source) end,
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  -- The junction row reserves the payment even while pending.
  insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents,
     resolution, note, event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, p_payment_ledger_id, v_paid,
     p_resolution, v_note, v_event_id, v_credit_id, v_actor_name);

  if v_additional then
    -- The aggregate moves only when the payment stands.
    if not v_has_policy then
      update public.invoice_matches
        set paid_cents = paid_cents + v_paid,
            resolution = p_resolution,
            note = case when v_note = '' then note else v_note end,
            payment_ledger_id = p_payment_ledger_id,
            credit_ledger_id = coalesce(v_credit_id, credit_ledger_id),
            matched_at = now(),
            by_name = v_actor_name
        where invoice_id = p_invoice_id;
    end if;
  else
    insert into public.invoice_matches
      (workspace_id, invoice_id, paid_cents, resolution, note, status,
       event_id, credit_ledger_id, payment_ledger_id, by_name)
    values
      (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
       v_note, case when v_has_policy then 'pending' else 'confirmed' end,
       v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
  end if;
end;
$function$;

revoke execute on function public.match_invoice_part(public.members, uuid, uuid, text, text, integer, uuid) from public, anon, authenticated;

-- match_invoice: the person's permission, then the part.
create or replace function public.match_invoice(p_invoice_id uuid, p_payment_ledger_id uuid, p_resolution text, p_note text DEFAULT ''::text, p_amount_cents integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_workspace uuid;
  v_actor public.members;
begin
  select workspace_id into v_workspace from public.invoices where id = p_invoice_id;
  if v_workspace is null then raise exception 'unknown invoice' using errcode = 'P0001'; end if;
  -- #816 — the matrix alone decides who matches.
  v_actor := public.issuing_member(v_workspace);
  -- #513 — the CENTRAL permission decides: owner always passes,
  -- co-owner/admin/member per the workspace's role matrix; the
  -- legacy adminInvoicing flag keeps granting inside
  -- has_permission for compatibility.
  if not public.has_permission(v_workspace, 'issueInvoices') then
    raise exception 'admins may not issue invoices here' using errcode = 'P0001';
  end if;
  perform public.match_invoice_part(v_actor, p_invoice_id, p_payment_ledger_id,
    p_resolution, p_note, p_amount_cents);
end;
$function$;
revoke execute on function public.match_invoice(uuid, uuid, text, text, integer) from public, anon;

-- ── 2. claims ───────────────────────────────────────────────────────────
-- The invoices in an open claim of [p_workspace], and why.
create or replace function public.open_claim_invoices(p_workspace uuid)
returns table (invoice_id uuid, reason text)
language sql stable security definer set search_path = public as $fn$
  select unnest(pi.claimed_invoice_ids), 'a payment being processed'
    from public.payment_intents pi
   where pi.workspace_id = p_workspace and pi.status = 'created'
     and pi.claimed_invoice_ids is not null and pi.claim_withdrawn_at is null
  union all
  select (c ->> 'invoice_id')::uuid, 'a declared payment awaiting approval'
    from public.events e
   cross join lateral jsonb_array_elements(e.payload -> 'claim') c
   where e.workspace_id = p_workspace and e.type = 'payment' and e.status = 'pending'
     and jsonb_typeof(e.payload -> 'claim') = 'array';
$fn$;
revoke execute on function public.open_claim_invoices(uuid) from public, anon, authenticated;

-- Refuses [p_member]'s claim of [p_ids] in [p_workspace] for [p_period],
-- each reason with its code (DKC01-DKC06); returns when the claim stands.
create or replace function public.check_payment_claim(
  p_workspace uuid, p_member uuid, p_ids uuid[], p_period text)
returns void language plpgsql stable security definer set search_path = public as $fn$
declare
  v_months text;
  v_bad text;
begin
  if coalesce(cardinality(p_ids), 0) = 0 then
    raise exception 'a payment of invoices names at least one invoice' using errcode = 'DKC01';
  end if;
  -- One answer for another member's invoice, an unknown id and another
  -- business's invoice, before anything about them is read back.
  if exists (select 1 from unnest(p_ids) x
              where not exists (select 1 from public.invoices i
                                 where i.id = x and i.workspace_id = p_workspace
                                   and i.member_id = p_member)) then
    raise exception 'an invoice of this payment is not one of yours to pay' using errcode = 'DKC02';
  end if;
  select string_agg(distinct i.period, ', ' order by i.period) into v_months
    from public.invoices i where i.id = any (p_ids);
  if (select count(distinct i.period) from public.invoices i where i.id = any (p_ids)) > 1 then
    raise exception 'a payment settles invoices of one month: this selection spans %', v_months using errcode = 'DKC03';
  end if;
  if p_period is not null and p_period <> v_months then
    raise exception 'these invoices are of %, not of %', v_months, p_period using errcode = 'DKC04';
  end if;
  select string_agg(i.number, ', ' order by i.number) into v_bad
    from public.invoices i
   where i.id = any (p_ids)
     and (i.voided_at is not null or i.settled_by_invoice_id is not null
          or public.invoice_still_due_cents(i.id) <= 0);
  if v_bad is not null then
    raise exception 'nothing is due on %', v_bad using errcode = 'DKC05';
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
revoke execute on function public.check_payment_claim(uuid, uuid, uuid[], text) from public, anon, authenticated;

-- Applies the payment [p_ledger] of [p_payer] to the claimed invoices
-- [p_ids], oldest first, each at what it still owes (whole: never more than
-- is left of the payment). A part an invoice refuses (settled meanwhile)
-- leaves that money the payer's credit on the payment.
create or replace function public.apply_payment_claim(
  p_ledger uuid, p_ids uuid[], p_payer uuid, p_source uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_payer public.members;
  v_invoice uuid;
  v_due bigint;
  v_left bigint;
  v_amount int;
begin
  select * into v_payer from public.members where id = p_payer;
  for v_invoice in
    select i.id from public.invoices i
     where i.id = any (p_ids)
     order by i.issued_at nulls last, i.number
  loop
    select l.amount_cents - public.payment_used_cents(l.id) into v_left
      from public.ledger_entries l where l.id = p_ledger;
    exit when coalesce(v_left, 0) <= 0;
    v_due := public.invoice_still_due_cents(v_invoice);
    continue when coalesce(v_due, 0) <= 0;
    v_amount := least(v_due, v_left)::int;
    begin
      perform public.match_invoice_part(v_payer, v_invoice, p_ledger,
        case when v_amount = v_due then 'exact' else 'under_accepted' end,
        case when v_amount = v_due then '' else 'part of a claimed payment' end,
        v_amount, p_source);
    exception when others then
      -- The invoice takes no part now (settled or matched meanwhile): the
      -- money stays the payer's credit on the payment.
      null;
    end;
  end loop;
end;
$fn$;
revoke execute on function public.apply_payment_claim(uuid, uuid[], uuid, uuid) from public, anon, authenticated;

-- ── 3. an online payment that names its invoices (0330, restated whole) ──
drop function if exists public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid);

create function public.open_payment_intent(
  p_workspace_id uuid,
  p_member_id uuid,
  p_provider text,
  p_period text,
  p_amount_cents integer,
  p_currency text,
  p_request_id uuid default null,
  p_invoice_ids uuid[] default null
)
returns table(id uuid, reference text, status text, order_id text, created_at timestamptz, reused boolean)
language plpgsql security definer set search_path to 'public' as $$
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
  -- 0393 (#1917, #1974): automatic collection is a feature. With
  -- onlinePayments off no new payment is opened; a payment already open
  -- is still settled by its provider (servicing it).
  if not public.feature_operation_allowed(p_workspace_id, 'onlinePayments', 'accept_new') then
    raise exception 'online payments are off in this workspace' using errcode = 'P0001';
  end if;
  if p_member_id <> v_me.id and not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'a payment is opened for yourself, or by whoever issues the invoices' using errcode = 'P0001';
  end if;
  select upper(currency_code) into v_ws_currency from public.workspaces where public.workspaces.id = p_workspace_id;
  if v_ws_currency is null then raise exception 'unknown workspace' using errcode = 'P0001'; end if;
  if upper(coalesce(p_currency, '')) <> v_ws_currency then
    raise exception 'a payment is taken in the workspace currency (%), not %', v_ws_currency, p_currency using errcode = 'P0001';
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'a payment intent needs a positive amount' using errcode = 'P0001';
  end if;
  -- #3556 — the claim, in one canonical order: a retry names the same set.
  if p_invoice_ids is not null then
    v_claim := array(select distinct x from unnest(p_invoice_ids) x where x is not null order by 1);
  end if;

  if p_request_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('payment_request:' || p_workspace_id::text || ':' || p_request_id::text, 0));
    select * into v_old from public.payment_intents i
      where i.workspace_id = p_workspace_id and i.request_id = p_request_id;
    if found then
      if v_old.member_id <> p_member_id or v_old.provider <> p_provider
         or v_old.period <> p_period or v_old.amount_cents <> p_amount_cents
         or upper(v_old.currency) <> v_ws_currency
         or v_old.claimed_invoice_ids is distinct from v_claim then
        raise exception 'payment request conflict: this request id was opened with another payment' using errcode = 'P0001';
      end if;
      return query select v_old.id, v_old.reference, v_old.status, v_old.order_id, v_old.created_at, true;
      return;
    end if;
  end if;

  if v_claim is not null then
    perform public.check_payment_claim(p_workspace_id, p_member_id, v_claim, p_period);
    select sum(public.invoice_still_due_cents(x)) into v_due from unnest(v_claim) x;
    if p_amount_cents <> v_due then
      raise exception 'a payment of these invoices is what they still owe (% in minor units), not %', v_due, p_amount_cents
        using errcode = 'DKC07';
    end if;
  end if;

  v_ref := public.next_document_number(p_workspace_id, 'payment');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, request_id, claimed_invoice_ids)
  values (v_id, p_workspace_id, p_member_id, p_provider, 'pending:' || v_id::text, p_period, p_amount_cents, v_ws_currency, v_ref, p_request_id, v_claim);
  return query select i.id, i.reference, i.status, i.order_id, i.created_at, false
    from public.payment_intents i where i.id = v_id;
end;
$$;

revoke execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid, uuid[]) from public, anon;
grant execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid, uuid[]) to authenticated;

-- ── 4. a declared payment that names its invoices (0362, restated whole) ─
drop function if exists public.record_payment(uuid, uuid, integer, text, text, date, text);

CREATE OR REPLACE FUNCTION public.record_payment(p_workspace_id uuid, p_member_id uuid, p_amount_cents integer, p_note text DEFAULT ''::text, p_method text DEFAULT ''::text, p_paid_on date DEFAULT NULL::date, p_period text DEFAULT NULL::text, p_invoice_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_event_id uuid;
  v_paid_on date := coalesce(p_paid_on, current_date);
  v_period text := coalesce(p_period, to_char(now(), 'YYYY-MM'));
  v_claim uuid[];
  v_due bigint;
  v_payload jsonb;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member' using errcode = 'P0001'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive' using errcode = 'P0001'; end if;
  -- #2137 -- or whoever holds issueInvoices, through a role.
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner
       or public.has_permission(p_workspace_id, 'issueInvoices')) then
    raise exception 'only admins record payments for others' using errcode = 'P0001';
  end if;
  -- Free-form-but-bounded method tag; the app sends one of the
  -- PaymentMethod enum wire names ('' = not specified, old clients).
  if length(p_method) > 32 then raise exception 'method too long' using errcode = 'P0001'; end if;
  -- #3556 — a claim is of one month: the payment's period is theirs.
  if p_invoice_ids is not null then
    v_claim := array(select distinct x from unnest(p_invoice_ids) x where x is not null order by 1);
    perform public.check_payment_claim(p_workspace_id, p_member_id, v_claim, p_period);
    select min(i.period) into v_period from public.invoices i where i.id = any (v_claim);
    select sum(public.invoice_still_due_cents(x)) into v_due from unnest(v_claim) x;
    if p_amount_cents <> v_due then
      raise exception 'a payment of these invoices is what they still owe (% in minor units), not %', v_due, p_amount_cents
        using errcode = 'DKC07';
    end if;
  end if;
  if v_period !~ '^[0-9]{4}-[0-9]{2}$' then raise exception 'invalid period' using errcode = 'P0001'; end if;
  -- Money cannot have moved tomorrow. One day of slack absorbs the gap
  -- between the server's UTC date and a workspace east of it.
  if v_paid_on > current_date + 1 then
    raise exception 'payment date is in the future' using errcode = 'P0001';
  end if;
  v_payload := jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', p_note,
      'method', p_method,
      'paid_on', v_paid_on,
      'period', v_period);
  if v_claim is not null then
    -- What the owner reads when deciding: each claimed invoice by number.
    v_payload := v_payload || jsonb_build_object('claim', (
      select jsonb_agg(jsonb_build_object('invoice_id', i.id, 'number', i.number)
                       order by i.issued_at nulls last, i.number)
        from public.invoices i where i.id = any (v_claim)));
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'payment', 'submitted', v_actor.id, p_member_id,
    v_payload,
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$function$;

revoke execute on function public.record_payment(uuid, uuid, integer, text, text, date, text, uuid[]) from public, anon;
grant execute on function public.record_payment(uuid, uuid, integer, text, text, date, text, uuid[]) to authenticated;

-- ── 5. the settlements apply the claim ───────────────────────────────────
-- The online one (0240 and 0757, restated whole).
CREATE OR REPLACE FUNCTION public.settle_online_payment(p_provider text, p_order_id text, p_capture_id text, p_amount_cents integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_intent public.payment_intents;
  v_ledger uuid;
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
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (v_intent.workspace_id, v_intent.member_id, 'credit', 'payment', v_intent.amount_cents,
          p_provider || ' online payment', v_intent.period)
  returning id into v_ledger;
  -- #1452 — the capture names its posting, in the same transaction.
  update public.payment_intents
     set status = 'captured', capture_id = p_capture_id, ledger_entry_id = v_ledger
   where public.payment_intents.id = v_intent.id;
  -- #3556 — a payment that claimed invoices settles them, by the rules a
  -- match follows (match_invoice_part): unless the member withdrew the claim.
  if v_intent.claimed_invoice_ids is not null and v_intent.claim_withdrawn_at is null then
    perform public.apply_payment_claim(v_ledger, v_intent.claimed_invoice_ids, v_intent.member_id, v_intent.id);
  end if;
end;
$function$;
revoke execute on function public.settle_online_payment(text, text, text, integer) from public, anon, authenticated;

-- The declared one: the owner's approval posts the credit with its event
-- (respond_to_event); the claim is applied when that credit is written.
create or replace function public.apply_declared_payment_claim()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_event public.events;
begin
  if new.kind <> 'credit' or new.category <> 'payment' then return new; end if;
  select * into v_event from public.events where id = new.event_id;
  -- Only the credit of an APPROVED declared payment that names invoices,
  -- and only the first credit naming it: a second row for the same event
  -- (a replay) applies nothing. No client writes ledger rows (the table
  -- has a select policy only): its writers are the server's own functions.
  if v_event.id is null or v_event.type <> 'payment' or v_event.status <> 'confirmed'
     or jsonb_typeof(v_event.payload -> 'claim') <> 'array'
     or exists (select 1 from public.ledger_entries l
                 where l.event_id = new.event_id and l.id <> new.id) then
    return new;
  end if;
  perform public.apply_payment_claim(new.id,
    array(select (c ->> 'invoice_id')::uuid from jsonb_array_elements(v_event.payload -> 'claim') c),
    new.member_id, v_event.id);
  return new;
end;
$fn$;
revoke execute on function public.apply_declared_payment_claim() from public, anon, authenticated;

drop trigger if exists ledger_apply_declared_claim on public.ledger_entries;
create trigger ledger_apply_declared_claim after insert on public.ledger_entries
  for each row when (new.event_id is not null)
  execute function public.apply_declared_payment_claim();

-- ── 6. the member withdraws a claim ──────────────────────────────────────
-- An online payment not yet captured: its invoices are free for another
-- payment; if the provider still captures it, the money is the member's
-- credit, applied to nothing.
create or replace function public.withdraw_payment_claim(p_intent uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_intent public.payment_intents;
begin
  select * into v_intent from public.payment_intents where id = p_intent for update;
  if v_intent.id is null
     or not exists (select 1 from public.members m
                     where m.id = v_intent.member_id and m.user_id = auth.uid()) then
    raise exception 'not one of your payments' using errcode = 'DKC08';
  end if;
  if v_intent.claimed_invoice_ids is null or v_intent.claim_withdrawn_at is not null then
    raise exception 'this payment names no invoices to free' using errcode = 'DKC09';
  end if;
  if v_intent.status <> 'created' then
    raise exception 'this payment is no longer being processed' using errcode = 'DKC10';
  end if;
  update public.payment_intents set claim_withdrawn_at = now() where id = p_intent;
end;
$fn$;
revoke execute on function public.withdraw_payment_claim(uuid) from public, anon;
grant execute on function public.withdraw_payment_claim(uuid) to authenticated;

-- ── 7. Me knows which of its invoices is in a payment being processed ────
-- my_finance_overview (0755, restated whole): each invoice also answers
-- `in_payment`. Only the person's own invoices, as before.
create or replace function public.my_finance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_invoices jsonb;
  v_cut boolean;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  with mine as (
    select i.id, i.workspace_id, w.name as workspace_name, w.timezone as workspace_timezone,
           i.number, i.issued_at,
           (select max(mat.due_on) from public.invoice_maturities mat where mat.invoice_id = i.id) as due_on,
           i.total_cents, i.currency, coalesce(m.paid_cents, 0) as paid_cents,
           case when m.id is null then 'open'
                when m.status = 'pending' then 'awaiting_validation'
                when m.resolution = 'refunded' then 'refunded'
                when m.resolution = 'under_accepted'
                     then case when m.writeoff_at is null then 'partially_paid' else 'closed' end
                else 'paid' end as state,
           public.invoice_still_due_cents(i.id) as still_due_cents,
           -- #3556 — the invoice is in a payment being processed (an online
           -- payment or a declared one that names it): not for another.
           exists (select 1 from public.open_claim_invoices(i.workspace_id) o
                    where o.invoice_id = i.id) as in_payment,
           coalesce((select sum(p.amount_cents) from public.invoice_match_payments p
                       join public.events e on e.id = p.event_id
                      where p.invoice_id = i.id and e.status = 'pending'), 0)
             + case when m.status = 'pending'
                     and not exists (select 1 from public.invoice_match_payments p
                                      where p.invoice_id = i.id and p.event_id = m.event_id)
                    then coalesce(m.paid_cents, 0) else 0 end as awaiting_cents,
           (select count(*) from public.invoice_reminders r where r.invoice_id = i.id) as reminder_count,
           (select max(r.sent_at) from public.invoice_reminders r where r.invoice_id = i.id) as last_reminder_at
      from public.invoices i
      join public.members mem on mem.id = i.member_id
      join public.workspaces w on w.id = i.workspace_id
      left join lateral (
        select x.* from public.invoice_matches x
         where x.invoice_id = i.id order by x.matched_at desc limit 1
      ) m on true
     where mem.user_id = auth.uid()
       and i.voided_at is null and i.settled_by_invoice_id is null
  ),
  owed as (
    select * from mine where state in ('open', 'awaiting_validation', 'partially_paid')
  ),
  settled as (
    select * from mine where state not in ('open', 'awaiting_validation', 'partially_paid')
     order by issued_at desc, id desc
     limit 301
  ),
  answered as (
    select * from owed
    union all
    select * from (select * from settled order by issued_at desc, id desc limit 300) s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'workspace_id', a.workspace_id, 'workspace_name', a.workspace_name,
           'workspace_timezone', a.workspace_timezone, 'number', a.number,
           'issued_at', a.issued_at, 'due_on', a.due_on, 'total_cents', a.total_cents,
           'currency', a.currency, 'paid_cents', a.paid_cents, 'state', a.state,
           'still_due_cents', a.still_due_cents, 'awaiting_cents', a.awaiting_cents,
           'in_payment', a.in_payment,
           'reminder_count', a.reminder_count, 'last_reminder_at', a.last_reminder_at)
         order by a.issued_at desc, a.id desc), '[]'::jsonb),
         (select count(*) from settled) > 300
    into v_invoices, v_cut
    from answered a;
  return jsonb_build_object(
    'invoices', v_invoices,
    'settled_cut', v_cut,
    'reminders', coalesce((
      select jsonb_agg(q2 order by q2.sent_at desc, q2.id desc) from (
        select r.id, r.invoice_id, i.number as invoice_number, w.name as workspace_name,
               r.sent_at, r.level, r.automatic
          from public.invoice_reminders r
          join public.invoices i on i.id = r.invoice_id
          join public.members mem on mem.id = i.member_id
          join public.workspaces w on w.id = i.workspace_id
         where mem.user_id = auth.uid() and i.voided_at is null
         order by r.sent_at desc, r.id desc
         limit 100
      ) q2), '[]'::jsonb));
end;
$fn$;

revoke execute on function public.my_finance_overview() from public, anon;
grant execute on function public.my_finance_overview() to authenticated;


notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(794);
