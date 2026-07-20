-- SPDX-License-Identifier: MIT
-- Online-payment intents + settlement (docs/design/payments-integration.md
-- §6, now live). NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- One row per provider order the create-payment-order Edge Function
-- starts. The provider webhook confirms the capture and calls
-- settle_online_payment with the SERVICE ROLE — idempotent on the order,
-- it marks the intent captured and posts a confirmed 'payment' ledger
-- credit. The capture is the proof of payment: no second-person
-- confirmation (that flow vouches for MANUAL claims).

create table public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  provider text not null check (provider in ('paypal','stripe','mollie')),
  order_id text not null,
  capture_id text,
  period text not null check (period ~ '^\d{4}-\d{2}$'),
  amount_cents int not null check (amount_cents > 0),
  currency text not null default 'EUR',
  status text not null default 'created'
    check (status in ('created','captured','failed')),
  created_at timestamptz not null default now(),
  unique (provider, order_id)
);
create index payment_intents_member_idx on public.payment_intents (member_id);

alter table public.payment_intents enable row level security;
-- members see their own payment attempts (diagnostics); admins see all.
-- No client writes: rows are created by the Edge Function (service role)
-- and settled by the webhook (service role).
create policy payment_intents_select on public.payment_intents
  for select using (
    public.is_admin_of(workspace_id)
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- Settlement: SERVICE ROLE ONLY (webhooks). Idempotent per order — a
-- webhook retry finds status='captured' and does nothing.
create or replace function public.settle_online_payment(
  p_provider text, p_order_id text, p_capture_id text, p_amount_cents int
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_intent public.payment_intents;
begin
  select * into v_intent from public.payment_intents
    where provider = p_provider and order_id = p_order_id
    for update;
  if v_intent.id is null then
    raise exception 'unknown payment intent %/%', p_provider, p_order_id;
  end if;
  if v_intent.status = 'captured' then return; end if;

  update public.payment_intents
    set status = 'captured', capture_id = p_capture_id
    where id = v_intent.id;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (
    v_intent.workspace_id, v_intent.member_id, 'credit', 'payment',
    coalesce(p_amount_cents, v_intent.amount_cents),
    p_provider || ' online payment', v_intent.period
  );
end;
$$;
revoke execute on function public.settle_online_payment(text, text, text, int)
  from public, anon, authenticated;

-- Failure marker (webhook denial/expiry paths) — service role only.
create or replace function public.mark_payment_failed(
  p_provider text, p_order_id text
) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.payment_intents set status = 'failed'
    where provider = p_provider and order_id = p_order_id
      and status = 'created';
end;
$$;
revoke execute on function public.mark_payment_failed(text, text)
  from public, anon, authenticated;
