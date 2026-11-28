-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4511 (audit STK-09) -- the notes and coins a till drawer is counted in come from one reference, each till holds the
-- ones its drawer carries, and a count by denomination is a quantity of each of them.
--   * public.cash_denominations   the notes and coins of a currency (a child of the currency reference, 0993): the value
--                                 in minor units, note or coin, and the day one its country replaced was withdrawn. The
--                                 app holds the same rows (deskilo_money_kernel cashDenominations;
--                                 test/lint/cash_denominations_parity_test.dart). A reference table: every authenticated
--                                 person reads it, only a migration writes it. A currency it does not list is counted by
--                                 its total.
--   * the rows are each issuer's own list of the notes and coins that are current legal tender, read on 2026-11-28:
--     AUD Reserve Bank of Australia + Royal Australian Mint; CAD Bank of Canada + Royal Canadian Mint (50 c added; the
--     cent withdrawn from distribution in 2013); CHF Swiss National Bank (ninth series) + Swissmint; CZK Czech National
--     Bank (20 and 50 Kc notes and haler coins no longer valid); DKK Danmarks Nationalbank (1 000-krone note no longer
--     legal tender: removed); EUR European Central Bank (500 euro note still legal tender) + the common euro coins; GBP
--     Bank of England (polymer notes; paper notes not legal tender since 2022) + Royal Mint; JPY Bank of Japan + Ministry
--     of Finance; NOK Norges Bank (series VIII); PLN Narodowy Bank Polski; SEK Sveriges Riksbank; USD Federal Reserve
--     Board + United States Mint. The same list, with each source, stands beside currencyReference.
--   * counter_tills.denominations the values this till's drawer carries, picked among its business currency's; null is
--                                 every current one. Set by who manages the tills (counter_till_denominations_set_v1).
--   * a session's float and count by denomination name only values of the till's pick (DKL02 denomination); a count
--                                 stored before keeps its values, and a currency the reference does not list keeps any.

create table public.cash_denominations (
  currency text not null references public.currency_reference (code),
  value_minor bigint not null check (value_minor > 0),
  form text not null check (form in ('note', 'coin')),
  withdrawn_on date,
  primary key (currency, value_minor, form)
);
select public.ensure_system_columns('cash_denominations');

comment on table public.cash_denominations is
  '#4511 -- the notes and coins a till drawer is counted in, per currency; the app''s cashDenominations.';

insert into public.cash_denominations (currency, value_minor, form, withdrawn_on) values
  ('AUD', 10000, 'note', null),
  ('AUD', 5000, 'note', null),
  ('AUD', 2000, 'note', null),
  ('AUD', 1000, 'note', null),
  ('AUD', 500, 'note', null),
  ('AUD', 200, 'coin', null),
  ('AUD', 100, 'coin', null),
  ('AUD', 50, 'coin', null),
  ('AUD', 20, 'coin', null),
  ('AUD', 10, 'coin', null),
  ('AUD', 5, 'coin', null),
  ('CAD', 10000, 'note', null),
  ('CAD', 5000, 'note', null),
  ('CAD', 2000, 'note', null),
  ('CAD', 1000, 'note', null),
  ('CAD', 500, 'note', null),
  ('CAD', 200, 'coin', null),
  ('CAD', 100, 'coin', null),
  ('CAD', 50, 'coin', null),
  ('CAD', 25, 'coin', null),
  ('CAD', 10, 'coin', null),
  ('CAD', 5, 'coin', null),
  ('CHF', 100000, 'note', null),
  ('CHF', 20000, 'note', null),
  ('CHF', 10000, 'note', null),
  ('CHF', 5000, 'note', null),
  ('CHF', 2000, 'note', null),
  ('CHF', 1000, 'note', null),
  ('CHF', 500, 'coin', null),
  ('CHF', 200, 'coin', null),
  ('CHF', 100, 'coin', null),
  ('CHF', 50, 'coin', null),
  ('CHF', 20, 'coin', null),
  ('CHF', 10, 'coin', null),
  ('CHF', 5, 'coin', null),
  ('CZK', 500000, 'note', null),
  ('CZK', 200000, 'note', null),
  ('CZK', 100000, 'note', null),
  ('CZK', 50000, 'note', null),
  ('CZK', 20000, 'note', null),
  ('CZK', 10000, 'note', null),
  ('CZK', 5000, 'coin', null),
  ('CZK', 2000, 'coin', null),
  ('CZK', 1000, 'coin', null),
  ('CZK', 500, 'coin', null),
  ('CZK', 200, 'coin', null),
  ('CZK', 100, 'coin', null),
  ('DKK', 50000, 'note', null),
  ('DKK', 20000, 'note', null),
  ('DKK', 10000, 'note', null),
  ('DKK', 5000, 'note', null),
  ('DKK', 2000, 'coin', null),
  ('DKK', 1000, 'coin', null),
  ('DKK', 500, 'coin', null),
  ('DKK', 200, 'coin', null),
  ('DKK', 100, 'coin', null),
  ('DKK', 50, 'coin', null),
  ('EUR', 50000, 'note', null),
  ('EUR', 20000, 'note', null),
  ('EUR', 10000, 'note', null),
  ('EUR', 5000, 'note', null),
  ('EUR', 2000, 'note', null),
  ('EUR', 1000, 'note', null),
  ('EUR', 500, 'note', null),
  ('EUR', 200, 'coin', null),
  ('EUR', 100, 'coin', null),
  ('EUR', 50, 'coin', null),
  ('EUR', 20, 'coin', null),
  ('EUR', 10, 'coin', null),
  ('EUR', 5, 'coin', null),
  ('EUR', 2, 'coin', null),
  ('EUR', 1, 'coin', null),
  ('GBP', 5000, 'note', null),
  ('GBP', 2000, 'note', null),
  ('GBP', 1000, 'note', null),
  ('GBP', 500, 'note', null),
  ('GBP', 200, 'coin', null),
  ('GBP', 100, 'coin', null),
  ('GBP', 50, 'coin', null),
  ('GBP', 20, 'coin', null),
  ('GBP', 10, 'coin', null),
  ('GBP', 5, 'coin', null),
  ('GBP', 2, 'coin', null),
  ('GBP', 1, 'coin', null),
  ('JPY', 10000, 'note', null),
  ('JPY', 5000, 'note', null),
  ('JPY', 2000, 'note', null),
  ('JPY', 1000, 'note', null),
  ('JPY', 500, 'coin', null),
  ('JPY', 100, 'coin', null),
  ('JPY', 50, 'coin', null),
  ('JPY', 10, 'coin', null),
  ('JPY', 5, 'coin', null),
  ('JPY', 1, 'coin', null),
  ('NOK', 100000, 'note', null),
  ('NOK', 50000, 'note', null),
  ('NOK', 20000, 'note', null),
  ('NOK', 10000, 'note', null),
  ('NOK', 5000, 'note', null),
  ('NOK', 2000, 'coin', null),
  ('NOK', 1000, 'coin', null),
  ('NOK', 500, 'coin', null),
  ('NOK', 100, 'coin', null),
  ('PLN', 50000, 'note', null),
  ('PLN', 20000, 'note', null),
  ('PLN', 10000, 'note', null),
  ('PLN', 5000, 'note', null),
  ('PLN', 2000, 'note', null),
  ('PLN', 1000, 'note', null),
  ('PLN', 500, 'coin', null),
  ('PLN', 200, 'coin', null),
  ('PLN', 100, 'coin', null),
  ('PLN', 50, 'coin', null),
  ('PLN', 20, 'coin', null),
  ('PLN', 10, 'coin', null),
  ('PLN', 5, 'coin', null),
  ('PLN', 2, 'coin', null),
  ('PLN', 1, 'coin', null),
  ('SEK', 100000, 'note', null),
  ('SEK', 50000, 'note', null),
  ('SEK', 20000, 'note', null),
  ('SEK', 10000, 'note', null),
  ('SEK', 5000, 'note', null),
  ('SEK', 2000, 'note', null),
  ('SEK', 1000, 'coin', null),
  ('SEK', 500, 'coin', null),
  ('SEK', 200, 'coin', null),
  ('SEK', 100, 'coin', null),
  ('USD', 10000, 'note', null),
  ('USD', 5000, 'note', null),
  ('USD', 2000, 'note', null),
  ('USD', 1000, 'note', null),
  ('USD', 500, 'note', null),
  ('USD', 200, 'note', null),
  ('USD', 100, 'coin', null),
  ('USD', 100, 'note', null),
  ('USD', 50, 'coin', null),
  ('USD', 25, 'coin', null),
  ('USD', 10, 'coin', null),
  ('USD', 5, 'coin', null),
  ('USD', 1, 'coin', null);

alter table public.cash_denominations enable row level security;
revoke all on public.cash_denominations from public, anon, authenticated;
grant select on public.cash_denominations to authenticated;
create policy cash_denominations_select on public.cash_denominations for select to authenticated using (true);
create policy mcp_delegated_deny on public.cash_denominations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- A table of no business is a personal surface (0564): it answers a recognised native session only.
create policy personal_native_session on public.cash_denominations as restrictive for all to public
  using ((select public.personal_native_session())) with check ((select public.personal_native_session()));

-- audience: all row readers
alter table public.counter_tills add column denominations bigint[]
  check (denominations is null or (cardinality(denominations) between 1 and 40 and 0 < all (denominations)));

-- The values [p_till] counts in: its pick, else every current value of the business currency; empty for a currency the
-- reference does not list.
create or replace function public.counter_till_cash_values(p_till public.counter_tills)
returns bigint[] language sql stable security definer set search_path = '' as $fn$
  select coalesce(array_agg(distinct d.value_minor order by d.value_minor desc), '{}')
    from public.cash_denominations d
    join public.workspaces w on w.id = p_till.workspace_id and d.currency = w.currency_code
   where d.withdrawn_on is null and (p_till.denominations is null or d.value_minor = any (p_till.denominations))
$fn$;
revoke execute on function public.counter_till_cash_values(public.counter_tills) from public, anon, authenticated;

-- Who manages the tills picks the values a till's drawer carries; an empty pick is every current one. Answers the pick.
create or replace function public.counter_till_denominations_set_v1(p_workspace_id uuid, p_till_id uuid, p_values bigint[])
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
declare
  v_till public.counter_tills;
  v_currency text;
  v_bad bigint;
begin
  perform public.command_actor(p_workspace_id, 'manageSites', 'counterTillSessions',
    'only who manages the sites sets up a till', 'till sessions are off in this business');
  select * into v_till from public.counter_tills where id = p_till_id and workspace_id = p_workspace_id for update;
  if v_till.id is null then
    perform public.refuse('DKL02', '{"reason": "till"}'::jsonb, 'no such till in this business');
  end if;
  select currency_code into v_currency from public.workspaces where id = p_workspace_id;
  select v into v_bad from unnest(coalesce(p_values, '{}')) v
   where not exists (select 1 from public.cash_denominations d where d.currency = v_currency and d.value_minor = v and d.withdrawn_on is null)
   limit 1;
  if v_bad is not null then
    perform public.refuse('DKL02', jsonb_build_object('reason', 'denomination', 'value', v_bad), 'a value the currency has no note or coin of');
  end if;
  update public.counter_tills set denominations = case when cardinality(coalesce(p_values, '{}')) = 0 then null
    else (select array_agg(distinct v order by v desc) from unnest(p_values) v) end
   where id = p_till_id
  returning * into v_till;
  return jsonb_build_object('till_id', v_till.id, 'denominations', to_jsonb(v_till.denominations),
                            'values', to_jsonb(public.counter_till_cash_values(v_till)));
end;
$fn$;
revoke execute on function public.counter_till_denominations_set_v1(uuid, uuid, bigint[]) from public, anon;
grant execute on function public.counter_till_denominations_set_v1(uuid, uuid, bigint[]) to authenticated;

-- The first value of [p_counted] the till does not count in, or null: a value stored before ([p_stored]) is kept, and a
-- till whose currency the reference does not list takes any.
create or replace function public.counter_count_refusal(p_till public.counter_tills, p_counted jsonb, p_stored jsonb)
returns bigint language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_values bigint[] := public.counter_till_cash_values(p_till);
  e record;
begin
  if p_counted is null or jsonb_typeof(p_counted) <> 'object' or cardinality(v_values) = 0 then return null; end if;
  for e in select key from jsonb_each(p_counted) loop
    if e.key ~ '^[1-9][0-9]{0,17}$' and not (e.key::bigint = any (v_values))
       and not (coalesce(p_stored, '{}'::jsonb) ? e.key) then
      return e.key::bigint;
    end if;
  end loop;
  return null;
end;
$fn$;
revoke execute on function public.counter_count_refusal(public.counter_tills, jsonb, jsonb) from public, anon, authenticated;

create or replace function public.counter_till_sessions_counted_in_till()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare
  v_till public.counter_tills;
  v_bad bigint;
begin
  select * into v_till from public.counter_tills where id = new.till_id;
  v_bad := coalesce(
    public.counter_count_refusal(v_till, new.float_denominations, case when tg_op = 'UPDATE' then old.float_denominations end),
    public.counter_count_refusal(v_till, new.counted_denominations, case when tg_op = 'UPDATE' then old.counted_denominations end));
  if v_bad is not null then
    perform public.refuse('DKL02', jsonb_build_object('reason', 'denomination', 'value', v_bad),
      'a value this till has no note or coin of');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.counter_till_sessions_counted_in_till() from public, anon, authenticated;
drop trigger if exists counter_till_sessions_counted_in_till on public.counter_till_sessions;
create trigger counter_till_sessions_counted_in_till
  before insert or update of float_denominations, counted_denominations on public.counter_till_sessions
  for each row execute function public.counter_till_sessions_counted_in_till();

select public.set_deskilo_schema_version(997);
