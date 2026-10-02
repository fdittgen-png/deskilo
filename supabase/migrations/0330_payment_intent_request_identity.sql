-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0330 (#2014 B) -- a payment request has a durable identity. The client
-- names its attempt with a request id and sends the SAME id on a retry;
-- `open_payment_intent` then answers with the intent that id already
-- opened instead of a new one, so the provider idempotency key (derived
-- from the intent id, #2047) is the same and a lost provider answer can
-- never become a second order. The same id with a different member,
-- provider, period, amount or currency is a conflict, never a reuse.
--
-- Concurrent first calls with one id serialise on a transaction advisory
-- lock, so exactly one intent (and one payment number) is drawn. Calls
-- without a request id keep the old behaviour: one new intent each.

alter table public.payment_intents add column if not exists request_id uuid;

create unique index if not exists payment_intents_request_once
  on public.payment_intents (workspace_id, request_id)
  where request_id is not null;

drop function if exists public.open_payment_intent(uuid, uuid, text, text, integer, text);

create function public.open_payment_intent(
  p_workspace_id uuid,
  p_member_id uuid,
  p_provider text,
  p_period text,
  p_amount_cents integer,
  p_currency text,
  p_request_id uuid default null
)
returns table(id uuid, reference text, status text, order_id text, created_at timestamptz, reused boolean)
language plpgsql security definer set search_path to 'public' as $$
declare
  v_id uuid := gen_random_uuid();
  v_ref text;
  v_ws_currency text;
  v_me public.members;
  v_old public.payment_intents;
begin
  v_me := public.my_active_member(p_workspace_id);
  if p_member_id <> v_me.id and not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'a payment is opened for yourself, or by whoever issues the invoices';
  end if;
  select upper(currency_code) into v_ws_currency from public.workspaces where public.workspaces.id = p_workspace_id;
  if v_ws_currency is null then raise exception 'unknown workspace'; end if;
  if upper(coalesce(p_currency, '')) <> v_ws_currency then
    raise exception 'a payment is taken in the workspace currency (%), not %', v_ws_currency, p_currency;
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'a payment intent needs a positive amount';
  end if;

  if p_request_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('payment_request:' || p_workspace_id::text || ':' || p_request_id::text, 0));
    select * into v_old from public.payment_intents i
      where i.workspace_id = p_workspace_id and i.request_id = p_request_id;
    if found then
      if v_old.member_id <> p_member_id or v_old.provider <> p_provider
         or v_old.period <> p_period or v_old.amount_cents <> p_amount_cents
         or upper(v_old.currency) <> v_ws_currency then
        raise exception 'payment request conflict: this request id was opened with another payment';
      end if;
      return query select v_old.id, v_old.reference, v_old.status, v_old.order_id, v_old.created_at, true;
      return;
    end if;
  end if;

  v_ref := public.next_document_number(p_workspace_id, 'payment');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, request_id)
  values (v_id, p_workspace_id, p_member_id, p_provider, 'pending:' || v_id::text, p_period, p_amount_cents, v_ws_currency, v_ref, p_request_id);
  return query select i.id, i.reference, i.status, i.order_id, i.created_at, false
    from public.payment_intents i where i.id = v_id;
end;
$$;

revoke execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid) from public, anon;
grant execute on function public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(330);
