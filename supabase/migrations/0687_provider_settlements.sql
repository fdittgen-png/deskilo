-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2380 item 4 — the provider settlement facts: what a payment provider
-- kept, what it paid on, and which payout carried it to the bank.
--
-- A payment taken online is not the money that reaches the bank: the
-- provider keeps its fee and pays the net out later, several payments in
-- one payout. This issue owns those FACTS (#2365 owns their postings, #2573
-- the provider's fee invoice as a purchase):
--
--   * `payment_intents` gains the fee and net of the payment as the
--     provider reported them, their currency, the provider's own
--     transaction id (Stripe balance transaction, PayPal capture, Mollie
--     payment) and the payout that carried it;
--   * `provider_payouts` keeps each payout the provider reported: its id,
--     amount, currency, arrival date and status;
--   * `record_provider_fee_v1` (service role, from the webhooks) records a
--     payment's fee once: gross = net + fee to the cent in the payment's
--     currency, and a second report must say the same;
--   * `record_provider_payout_v1` (service role) records a payout and links
--     the payments its transactions name; it answers whether their nets add
--     up to the payout, never adjusting either side.
--
-- Nothing is posted, no money moves, no provider is called by the database.

alter table public.payment_intents
  add column if not exists provider_fee_cents bigint check (provider_fee_cents is null or provider_fee_cents >= 0),
  add column if not exists provider_net_cents bigint,
  add column if not exists provider_fee_currency text not null default '',
  add column if not exists provider_transaction_id text not null default '',
  add column if not exists payout_id text not null default '';

comment on column public.payment_intents.provider_fee_cents is
  '#2380 — what the provider kept of this payment, in provider_fee_currency; null until reported.';

create table if not exists public.provider_payouts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  provider text not null check (provider in ('stripe', 'paypal', 'mollie')),
  payout_id text not null check (payout_id <> ''),
  amount_cents bigint not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  arrival_date date,
  status text not null default 'pending' check (status in ('pending', 'in_transit', 'paid', 'failed', 'canceled')),
  unique (workspace_id, provider, payout_id)
);
select public.ensure_system_columns('provider_payouts');

comment on table public.provider_payouts is
  '#2380 — the payouts a payment provider reported, which carry the net of its payments to the bank.';

create or replace function public.record_provider_fee_v1(
  p_provider text,
  p_order_id text,
  p_fee_cents bigint,
  p_net_cents bigint,
  p_currency text,
  p_transaction_id text
) returns public.payment_intents
language plpgsql security definer set search_path = public as $fn$
declare
  v_intent public.payment_intents;
  v_currency text := upper(coalesce(p_currency, ''));
begin
  if p_fee_cents is null or p_net_cents is null or p_fee_cents < 0 or coalesce(p_transaction_id, '') = '' then
    raise exception 'a provider fee needs its amount, its net and the provider''s transaction';
  end if;
  select * into v_intent from public.payment_intents
   where provider = p_provider and order_id = p_order_id
   for update;
  if v_intent.id is null then raise exception 'unknown payment'; end if;
  -- In the payment's own currency the provider's split adds up to it.
  if v_currency = v_intent.currency and p_net_cents + p_fee_cents <> v_intent.amount_cents then
    raise exception 'the provider''s net and fee do not add up to the payment';
  end if;
  if v_intent.provider_fee_cents is not null then
    if (v_intent.provider_fee_cents, v_intent.provider_net_cents, v_intent.provider_fee_currency,
        v_intent.provider_transaction_id)
       is distinct from (p_fee_cents, p_net_cents, v_currency, p_transaction_id) then
      raise exception 'the provider reported another fee for this payment';
    end if;
    return v_intent;
  end if;
  update public.payment_intents
     set provider_fee_cents = p_fee_cents,
         provider_net_cents = p_net_cents,
         provider_fee_currency = v_currency,
         provider_transaction_id = p_transaction_id
   where id = v_intent.id
  returning * into v_intent;
  return v_intent;
end;
$fn$;

revoke execute on function public.record_provider_fee_v1(text, text, bigint, bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.record_provider_fee_v1(text, text, bigint, bigint, text, text) to service_role;

create or replace function public.record_provider_payout_v1(
  p_workspace_id uuid,
  p_provider text,
  p_payout_id text,
  p_amount_cents bigint,
  p_currency text,
  p_arrival_date date,
  p_status text,
  p_transaction_ids text[]
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_payout public.provider_payouts;
  v_linked int;
  v_net bigint;
  v_taken int;
begin
  insert into public.provider_payouts (workspace_id, provider, payout_id, amount_cents, currency, arrival_date, status)
  values (p_workspace_id, p_provider, p_payout_id, p_amount_cents, upper(p_currency), p_arrival_date, p_status)
  on conflict (workspace_id, provider, payout_id) do update
     set status = excluded.status,
         arrival_date = coalesce(excluded.arrival_date, provider_payouts.arrival_date)
   where provider_payouts.amount_cents = excluded.amount_cents
     and provider_payouts.currency = excluded.currency
  returning * into v_payout;
  if v_payout.id is null then
    raise exception 'the provider reported this payout with another amount';
  end if;
  -- A payment belongs to one payout: one already carried elsewhere stays there.
  select count(*) into v_taken from public.payment_intents
   where workspace_id = p_workspace_id and provider = p_provider
     and provider_transaction_id = any(coalesce(p_transaction_ids, '{}'))
     and payout_id <> '' and payout_id <> p_payout_id;
  if v_taken > 0 then
    raise exception 'a payment of this payout is carried by another one';
  end if;
  update public.payment_intents
     set payout_id = p_payout_id
   where workspace_id = p_workspace_id and provider = p_provider
     and provider_transaction_id = any(coalesce(p_transaction_ids, '{}'))
     and payout_id = '';
  select count(*), coalesce(sum(provider_net_cents), 0) into v_linked, v_net
    from public.payment_intents
   where workspace_id = p_workspace_id and provider = p_provider and payout_id = p_payout_id;
  return jsonb_build_object(
    'payout', v_payout.id,
    'payments', v_linked,
    'net_cents', v_net,
    'reconciled', v_net = p_amount_cents and upper(p_currency) = all(
      select provider_fee_currency from public.payment_intents
       where workspace_id = p_workspace_id and provider = p_provider and payout_id = p_payout_id));
end;
$fn$;

revoke execute on function public.record_provider_payout_v1(uuid, text, text, bigint, text, date, text, text[])
  from public, anon, authenticated;
grant execute on function public.record_provider_payout_v1(uuid, text, text, bigint, text, date, text, text[]) to service_role;

alter table public.provider_payouts enable row level security;
revoke all on public.provider_payouts from anon;
revoke insert, update, delete on public.provider_payouts from authenticated;
grant select on public.provider_payouts to authenticated;

drop policy if exists provider_payouts_select on public.provider_payouts;
create policy provider_payouts_select on public.provider_payouts
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
drop policy if exists mcp_delegated_deny on public.provider_payouts;
create policy mcp_delegated_deny on public.provider_payouts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(687);
