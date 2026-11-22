-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (record_payment gains an optional request id, so its signature changes; three bodies are restated
--  and one is patched at an asserted anchor)
--
-- Declared payments.
--
--   * A declared payment takes its date and its month from the business's own day
--     (`workspace_today`), in `record_payment` and in the credit note of `match_invoice_part`; the
--     day of slack that stood in for the time zone is gone: a date after the business's today is
--     refused, its today is accepted.
--   * `record_payment` takes an optional request id. It is kept with the declaration (its event) under
--     a unique partial index per business and declaring member. A repeat with the same id and the
--     same content returns the first declaration, whether or not the invoices it names are held by
--     that declaration; the same id with other content is refused with DKC15. Concurrent calls with
--     one id are serialised and make one declaration.
--   * `withdraw_payment_claim` reads the caller's right and active membership before it locks the
--     intent row, as `withdraw_payment_declaration` does: nobody waits on a row they have no right to.

-- ── one declaration per request id ─────────────────────────────────────
create unique index if not exists events_payment_request_once
  on public.events (workspace_id, actor_member_id, ((payload ->> 'request_id')))
  where type = 'payment' and payload ? 'request_id';

-- ── record_payment (restates 0797) ─────────────────────────────────────
drop function if exists public.record_payment(uuid, uuid, integer, text, text, date, text, uuid[]);

-- restates 0797
CREATE OR REPLACE FUNCTION public.record_payment(p_workspace_id uuid, p_member_id uuid, p_amount_cents integer, p_note text DEFAULT ''::text, p_method text DEFAULT ''::text, p_paid_on date DEFAULT NULL::date, p_period text DEFAULT NULL::text, p_invoice_ids uuid[] DEFAULT NULL::uuid[], p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_event_id uuid;
  v_today date := public.workspace_today(p_workspace_id);
  v_paid_on date := coalesce(p_paid_on, v_today);
  v_period text := coalesce(p_period, to_char(v_today, 'YYYY-MM'));
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
  if p_amount_cents <= 0 then raise exception 'amount must be positive' using errcode = 'P0001'; end if;
  -- #2137 -- or whoever holds issueInvoices, through a role.
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner
       or public.has_permission(p_workspace_id, 'issueInvoices')) then
    raise exception 'only admins record payments for others' using errcode = 'P0001';
  end if;
  -- Free-form-but-bounded method tag; the app sends one of the
  -- PaymentMethod enum wire names ('' = not specified, old clients).
  if p_method is not null and length(p_method) > 32 then raise exception 'method too long' using errcode = 'P0001'; end if;
  -- A request id names one confirmation: a repeat after a lost answer is the first declaration,
  -- answered before any other rule reads the invoices it names.
  if p_invoice_ids is not null then
    v_claim := array(select distinct x from unnest(p_invoice_ids) x where x is not null order by 1);
  end if;
  if p_request_id is not null then
    -- one JSON array: a NULL stays JSON null and a '|' is escaped, so no two different requests share a digest
    v_digest := md5(jsonb_build_array(p_member_id, p_amount_cents, p_note, p_method, p_paid_on, p_period, v_claim)::text);
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
  end if;
  -- #3556 — a claim is of one month: the payment's period is theirs.
  if p_invoice_ids is not null then
    -- One open claim per invoice: locked by id before the check (DKC06),
    -- only this member's invoices of this business: nobody waits on, or
    -- holds, another's rows.
    perform 1 from public.invoices i
     where i.id = any (v_claim) and i.workspace_id = p_workspace_id and i.member_id = p_member_id
     order by i.id for update;
    -- #3556 — the payment's currency, as it stands at declaration: the
    -- approval applies by this one.
    select upper(w.currency_code) into v_currency from public.workspaces w where w.id = p_workspace_id;
    perform public.check_payment_claim(p_workspace_id, p_member_id, v_claim, p_period, v_currency);
    select min(i.period) into v_period from public.invoices i where i.id = any (v_claim);
    select sum(public.invoice_still_due_cents(x)) into v_due from unnest(v_claim) x;
    if p_amount_cents <> v_due then
      raise exception 'a payment of these invoices is what they still owe (% in minor units), not %', v_due, p_amount_cents
        using errcode = 'DKC07';
    end if;
  end if;
  if v_period !~ '^[0-9]{4}-[0-9]{2}$' then raise exception 'invalid period' using errcode = 'P0001'; end if;
  -- Money cannot have moved after the business's own today.
  if v_paid_on > v_today then
    raise exception 'payment date is in the future' using errcode = 'P0001';
  end if;
  v_payload := jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', p_note,
      'method', p_method,
      'paid_on', v_paid_on,
      'period', v_period);
  if p_request_id is not null then
    v_payload := v_payload || jsonb_build_object('request_id', p_request_id, 'request_digest', v_digest);
  end if;
  if v_claim is not null then
    -- What the owner reads when deciding: each claimed invoice by number.
    v_payload := v_payload || jsonb_build_object('currency', v_currency, 'claim', (
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

revoke execute on function public.record_payment(uuid, uuid, integer, text, text, date, text, uuid[], uuid) from public, anon;
grant execute on function public.record_payment(uuid, uuid, integer, text, text, date, text, uuid[], uuid) to authenticated;

-- ── the credit note's month is the business's (match_invoice_part, patched) ──
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
  v_def text := pg_get_functiondef('public.match_invoice_part(public.members, uuid, uuid, text, text, integer, uuid)'::regprocedure);
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, 'to_char(now(), ''YYYY-MM'')', ''))) / length('to_char(now(), ''YYYY-MM'')') <> 1 then
    raise exception '0861: the month of match_invoice_part is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := pg_temp.anchor_replace(v_def,
    $o$to_char(now(), 'YYYY-MM')$o$,
    $n$to_char(public.workspace_today(v_invoice.workspace_id), 'YYYY-MM')$n$);
  if v_next is null then raise exception '0861: the anchor of match_invoice_part is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- ── withdraw_payment_claim: the right first, then the lock (restates 0797) ──
-- restates 0797
create or replace function public.withdraw_payment_claim(p_intent uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_intent public.payment_intents;
  v_actor public.members;
begin
  -- The right first, without a lock: nobody waits on, or holds, a row they have no right to. The
  -- intent's business and member never change.
  select * into v_intent from public.payment_intents where id = p_intent;
  select * into v_actor from public.members
   where workspace_id = v_intent.workspace_id and user_id = auth.uid() and status = 'active';
  if v_intent.id is null or v_actor.id is null
     or not (v_actor.id = v_intent.member_id
             or public.has_permission(v_intent.workspace_id, 'issueInvoices')) then
    raise exception 'not one of your payments' using errcode = 'DKC08';
  end if;
  -- Then the lock, and the intent read again under it.
  select * into v_intent from public.payment_intents where id = p_intent for update;
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

select public.set_deskilo_schema_version(861);
