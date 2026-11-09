-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0700 (#3504) -- a Mollie settlement is a payout and the costs Mollie kept.
-- Mollie reports fees and payouts on SETTLEMENTS, not on the payment: a
-- settlement carries its period costs aggregated per method (an amount net and
-- a count), never a fee per payment. So:
--
--   * `provider_settlement_costs` keeps those costs as ONE settlement-level
--     fact per settlement, period and method -- no per-payment fee is invented;
--   * `record_provider_settlement_v1` (service role, from the Edge function)
--     records the settlement as a payout (0687's `record_provider_payout_v1`,
--     whose answer says it carries no payment of ours) and its costs, once: a
--     second report must say the same.
--
-- Nothing is posted: the clearing design accepts per-payment fees only
-- (0698); a settlement-level fee posting is a follow-up.

create table public.provider_settlement_costs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  provider text not null check (provider in ('stripe', 'paypal', 'mollie')),
  settlement_id text not null check (settlement_id <> ''),
  period text not null check (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  method text not null default '',
  description text not null default '',
  cost_count int not null check (cost_count >= 0),
  amount_net_cents bigint not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  unique (workspace_id, provider, settlement_id, period, method, description)
);
select public.ensure_system_columns('provider_settlement_costs');

comment on table public.provider_settlement_costs is
  '#3504 -- the costs a payment provider kept in a settlement, aggregated per period and method as the provider reports them (Mollie).';

create or replace function public.record_provider_settlement_v1(
  p_workspace_id uuid,
  p_provider text,
  p_settlement_id text,
  p_amount_cents bigint,
  p_currency text,
  p_arrival_date date,
  p_status text,
  p_costs jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_payout jsonb;
  c record;
  v_n int := 0;
  v_old public.provider_settlement_costs;
begin
  v_payout := public.record_provider_payout_v1(
    p_workspace_id, p_provider, p_settlement_id, p_amount_cents, p_currency, p_arrival_date, p_status, '{}'::text[]);
  for c in
    select x.period, coalesce(x.method, '') as method, coalesce(x.description, '') as description,
           x.cost_count, x.amount_net_cents, upper(p_currency) as currency
      from jsonb_to_recordset(coalesce(p_costs, '[]'::jsonb))
           as x(period text, method text, description text, cost_count int, amount_net_cents bigint)
  loop
    select * into v_old from public.provider_settlement_costs
     where workspace_id = p_workspace_id and provider = p_provider and settlement_id = p_settlement_id
       and period = c.period and method = c.method and description = c.description;
    if v_old.id is null then
      insert into public.provider_settlement_costs
        (workspace_id, provider, settlement_id, period, method, description, cost_count, amount_net_cents, currency)
      values (p_workspace_id, p_provider, p_settlement_id, c.period, c.method, c.description,
              c.cost_count, c.amount_net_cents, c.currency);
      v_n := v_n + 1;
    elsif (v_old.cost_count, v_old.amount_net_cents, v_old.currency)
          is distinct from (c.cost_count, c.amount_net_cents, c.currency) then
      raise exception 'the provider reported other costs for this settlement';
    end if;
  end loop;
  return v_payout || jsonb_build_object('costs_added', v_n);
end;
$fn$;
revoke execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb) to service_role;

alter table public.provider_settlement_costs enable row level security;
revoke all on public.provider_settlement_costs from anon;
revoke insert, update, delete on public.provider_settlement_costs from authenticated;
grant select on public.provider_settlement_costs to authenticated;
create policy provider_settlement_costs_select on public.provider_settlement_costs
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
create policy mcp_delegated_deny on public.provider_settlement_costs as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(700);
