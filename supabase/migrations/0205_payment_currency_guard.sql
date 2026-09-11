-- SPDX-License-Identifier: 0BSD
-- 0205 — #1138: the ledger never learns a currency from a webhook.
--
-- `open_payment_intent` stored whatever currency the edge function was
-- handed and `settle_online_payment` credited whatever amount the
-- webhook reported. Both were currency-blind, so a client naming a
-- cheaper currency was charged in it and credited in the workspace's.
--
-- Two guards, both server-side where a client cannot skip them:
--   * an intent may only be opened in the workspace's own currency;
--   * settlement credits the INTENT's amount, and a webhook whose figure
--     disagrees is refused — a wrong credit is worse than a retry, and
--     the refusal is what makes a conversion bug visible.
create or replace function public.open_payment_intent(
  p_workspace_id uuid, p_member_id uuid, p_provider text, p_period text,
  p_amount_cents integer, p_currency text
) returns table(id uuid, reference text)
language plpgsql security definer set search_path = public as $fn$
declare v_id uuid := gen_random_uuid(); v_ref text; v_ws_currency text;
begin
  select upper(currency_code) into v_ws_currency from public.workspaces where public.workspaces.id = p_workspace_id;
  if v_ws_currency is null then raise exception 'unknown workspace'; end if;
  if upper(coalesce(p_currency, '')) <> v_ws_currency then
    raise exception 'a payment is taken in the workspace currency (%), not %', v_ws_currency, p_currency;
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'a payment intent needs a positive amount';
  end if;
  v_ref := public.next_document_number(p_workspace_id, 'payment');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference)
  values (v_id, p_workspace_id, p_member_id, p_provider, 'pending:' || v_id::text, p_period, p_amount_cents, v_ws_currency, v_ref);
  return query select v_id, v_ref;
end;
$fn$;
revoke execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text) from public, anon;

create or replace function public.settle_online_payment(
  p_provider text, p_order_id text, p_capture_id text, p_amount_cents integer
) returns void language plpgsql security definer set search_path = public as $fn$
declare v_intent public.payment_intents;
begin
  select * into v_intent from public.payment_intents
    where provider = p_provider and order_id = p_order_id
    for update;
  if v_intent.id is null then
    raise exception 'unknown payment intent %/%', p_provider, p_order_id;
  end if;
  if v_intent.status = 'captured' then return; end if;
  -- The intent is what the member agreed to pay. A webhook that reports
  -- something else is a conversion bug or a tampered call, and neither
  -- is a reason to move money.
  if p_amount_cents is not null and p_amount_cents <> v_intent.amount_cents then
    raise exception 'captured amount % does not match the intent (%)', p_amount_cents, v_intent.amount_cents;
  end if;
  update public.payment_intents set status = 'captured', capture_id = p_capture_id where public.payment_intents.id = v_intent.id;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (v_intent.workspace_id, v_intent.member_id, 'credit', 'payment', v_intent.amount_cents,
          p_provider || ' online payment', v_intent.period);
end;
$fn$;
revoke execute on function public.settle_online_payment(text, text, text, integer) from public, anon;
