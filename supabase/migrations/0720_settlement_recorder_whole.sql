-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table for the settlement reports refused for review; the recorder
--  compares a settlement as a whole and refuses a cost in another currency)
--
-- #3510 (first pull request) -- the Mollie settlement recorder (0700) is
-- hardened before any schedule reads settlements by itself:
--
--  * a cost in another currency than its settlement is refused, never
--    relabelled into the settlement's currency;
--  * a settlement already recorded is compared as a WHOLE: its amount, its
--    currency and the canonical set of its costs (period, method,
--    description, count, net, currency). An added, omitted or changed cost
--    is a changed settlement. Before, an added cost row was simply inserted
--    and an omitted one went unnoticed;
--  * a changed or inconsistent report is refused AND kept for review in
--    `provider_settlement_reviews` (one row per settlement and reason, its
--    latest report and when it was first and last seen), instead of raising:
--    a raise rolled back the very record a person needed to see. Nothing of
--    a refused report reaches the payout or its costs;
--  * the answer says what the recorder decided: `outcome` new, unchanged or
--    refused (with its reason), so a caller counts outcomes, not calls.

create table public.provider_settlement_reviews (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  provider text not null check (provider in ('stripe', 'paypal', 'mollie')),
  settlement_id text not null check (settlement_id <> ''),
  reason text not null check (reason in ('costs_changed', 'amount_changed', 'currency_mismatch')),
  reported jsonb not null,
  first_reported_at timestamptz not null default now(),
  last_reported_at timestamptz not null default now(),
  unique (workspace_id, provider, settlement_id, reason)
);
select public.ensure_system_columns('provider_settlement_reviews');

comment on table public.provider_settlement_reviews is
  '#3510 -- settlement reports of a payment provider that the recorder refused (changed after it was recorded, or a cost in another currency), kept for a person to review.';

alter table public.provider_settlement_reviews enable row level security;
revoke all on public.provider_settlement_reviews from public, anon;
revoke insert, update, delete on public.provider_settlement_reviews from authenticated;
grant select on public.provider_settlement_reviews to authenticated;
create policy provider_settlement_reviews_select on public.provider_settlement_reviews
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
create policy mcp_delegated_deny on public.provider_settlement_reviews as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The canonical set of a settlement's costs: one object per cost, in one
-- order, each with its own currency.
create or replace function public.provider_settlement_cost_set(
  p_workspace_id uuid, p_provider text, p_settlement_id text)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
           'period', c.period, 'method', c.method, 'description', c.description,
           'cost_count', c.cost_count, 'amount_net_cents', c.amount_net_cents, 'currency', c.currency)
         order by c.period, c.method, c.description), '[]'::jsonb)
    from public.provider_settlement_costs c
   where c.workspace_id = p_workspace_id and c.provider = p_provider and c.settlement_id = p_settlement_id
$fn$;
revoke execute on function public.provider_settlement_cost_set(uuid, text, text) from public, anon, authenticated;

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
  v_currency text := upper(coalesce(p_currency, ''));
  v_costs jsonb;
  v_payout public.provider_payouts;
  v_reason text;
  v_answer jsonb;
  v_n int := 0;
begin
  -- The report's costs in the canonical order; a cost names its own
  -- currency, or is in the settlement's.
  select coalesce(jsonb_agg(jsonb_build_object(
           'period', x.period, 'method', coalesce(x.method, ''), 'description', coalesce(x.description, ''),
           'cost_count', x.cost_count, 'amount_net_cents', x.amount_net_cents,
           'currency', upper(coalesce(nullif(x.currency, ''), v_currency)))
         order by x.period, coalesce(x.method, ''), coalesce(x.description, '')), '[]'::jsonb)
    into v_costs
    from jsonb_to_recordset(coalesce(p_costs, '[]'::jsonb))
         as x(period text, method text, description text, cost_count int, amount_net_cents bigint, currency text);

  select * into v_payout from public.provider_payouts
   where workspace_id = p_workspace_id and provider = p_provider and payout_id = p_settlement_id;
  if exists (select 1 from jsonb_array_elements(v_costs) c where c ->> 'currency' <> v_currency) then
    v_reason := 'currency_mismatch';
  elsif v_payout.id is not null
        and (v_payout.amount_cents, v_payout.currency) is distinct from (p_amount_cents, v_currency) then
    v_reason := 'amount_changed';
  elsif v_payout.id is not null
        and public.provider_settlement_cost_set(p_workspace_id, p_provider, p_settlement_id) <> v_costs then
    v_reason := 'costs_changed';
  end if;

  if v_reason is not null then
    insert into public.provider_settlement_reviews
      (workspace_id, provider, settlement_id, reason, reported)
    values (p_workspace_id, p_provider, p_settlement_id, v_reason,
            jsonb_build_object('amount_cents', p_amount_cents, 'currency', v_currency,
                               'arrival_date', p_arrival_date, 'status', p_status, 'costs', v_costs))
    on conflict (workspace_id, provider, settlement_id, reason) do update
      set reported = excluded.reported, last_reported_at = now();
    return jsonb_build_object('outcome', 'refused', 'reason', v_reason, 'costs_added', 0);
  end if;

  v_answer := public.record_provider_payout_v1(
    p_workspace_id, p_provider, p_settlement_id, p_amount_cents, v_currency, p_arrival_date, p_status, '{}'::text[]);
  if v_payout.id is null then
    insert into public.provider_settlement_costs
      (workspace_id, provider, settlement_id, period, method, description, cost_count, amount_net_cents, currency)
    select p_workspace_id, p_provider, p_settlement_id, c ->> 'period', c ->> 'method', c ->> 'description',
           (c ->> 'cost_count')::int, (c ->> 'amount_net_cents')::bigint, c ->> 'currency'
      from jsonb_array_elements(v_costs) c;
    get diagnostics v_n = row_count;
    return v_answer || jsonb_build_object('outcome', 'new', 'costs_added', v_n);
  end if;
  return v_answer || jsonb_build_object('outcome', 'unchanged', 'costs_added', 0);
end;
$fn$;
revoke execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb) to service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(720);
