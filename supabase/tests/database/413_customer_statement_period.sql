-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3839 (0751, L2 of #3787): a customer's statement for a period. Per
-- currency, opening + movements = closing; the closing is the open-items
-- statement of the last day and the opening the one of the day before the
-- first. A payment of day -15, matched (awaiting approval) on day -12 and
-- approved on day -5, is "paid" in the period of its approval, with the
-- payment's own date on the line; in the period before, the invoice stays
-- due. A period with no movement has two equal balances. A period before
-- the match history says it is reconstructed. Rolled back.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000038390a1';
  u_1 uuid := '00000000-0000-4000-8000-0000038390a2';
  ws uuid; m_o uuid; m_1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'period-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_1]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Period', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_1, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_1 from public.members where workspace_id = ws and user_id = u_1;
  -- A: 10.00 EUR, paid; Y: 5000 JPY (no decimals), open.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_1, m_o, 'PE-A', 'One', '[]'::jsonb, 1000, 'EUR', 'One', 'Period', 'Owner', 'sig'),
         (ws, m_1, m_o, 'PE-Y', 'One', '[]'::jsonb, 5000, 'JPY', 'One', 'Period', 'Owner', 'sig');
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (ws, m_1, 'credit', 'payment', 1000, 'PA', '2026-09');
  perform set_config('pe.ws', ws::text, false);
  perform set_config('pe.m1', m_1::text, false);
  perform set_config('pe.owner', u_o::text, false);
end
$seed$;
select pg_temp.seed();
select set_config('TimeZone', 'Europe/Paris', true);

create or replace function pg_temp.id(p_kind text, p_name text) returns uuid language sql as $f$
  select case p_kind
    when 'inv' then (select id from public.invoices where workspace_id = current_setting('pe.ws')::uuid and number = p_name)
    else (select id from public.ledger_entries where workspace_id = current_setting('pe.ws')::uuid and description = p_name) end;
$f$;
create or replace function pg_temp.as_owner(p_sql text, p_delegated boolean default false) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (jsonb_build_object('sub', current_setting('pe.owner'), 'role', 'authenticated')
    || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR ' || sqlstate;
end
$f$;
create or replace function pg_temp.period(p_from date, p_to date) returns jsonb language sql as $f$
  select pg_temp.as_owner(format('select public.customer_statement_period_v1(%L, %L, %L, %L)::text',
    current_setting('pe.ws'), current_setting('pe.m1'), p_from, p_to))::jsonb
$f$;
create or replace function pg_temp.balance(p_as_of date, p_currency text) returns bigint language sql as $f$
  select coalesce((select (c ->> 'balance_cents')::bigint
    from jsonb_array_elements(pg_temp.as_owner(format('select public.customer_statement_v1(%L, %L, %L)::text',
           current_setting('pe.ws'), current_setting('pe.m1'), p_as_of))::jsonb -> 'currencies') c
   where c ->> 'currency' = p_currency), 0)
$f$;
-- Per currency of a period: does opening + movements = closing, and do the
-- two ends equal the open-items statements of the day before and the last day?
create or replace function pg_temp.holds(p_from date, p_to date) returns text language sql as $f$
  select string_agg(c ->> 'currency' || ':' ||
           ((c ->> 'opening_cents')::bigint + coalesce((select sum((m ->> 'amount_cents')::bigint)
                                                         from jsonb_array_elements(c -> 'movements') m), 0)
             = (c ->> 'closing_cents')::bigint
            and (c ->> 'closing_cents')::bigint = pg_temp.balance(p_to, c ->> 'currency')
            and (c ->> 'opening_cents')::bigint = pg_temp.balance(p_from - 1, c ->> 'currency'))::text,
           ' ' order by c ->> 'currency')
    from jsonb_array_elements(pg_temp.period(p_from, p_to) -> 'currencies') c
$f$;
create or replace function pg_temp.moves(p_from date, p_to date, p_currency text) returns text language sql as $f$
  select string_agg(m ->> 'what' || ' ' || (m ->> 'label') || ' ' || (m ->> 'amount_cents')
                    || ' on ' || ((m ->> 'decided_on')::date - current_date)
                    || ' own ' || ((m ->> 'own_on')::date - current_date), ', '
                    order by m ->> 'at', m ->> 'label')
    from jsonb_array_elements(pg_temp.period(p_from, p_to) -> 'currencies') c,
         jsonb_array_elements(c -> 'movements') m
   where c ->> 'currency' = p_currency
$f$;
grant execute on all functions in schema pg_temp to authenticated;

-- The payment is matched to A and waits for an approval (set here with the
-- triggers on, as 412 does); then everything is dated: A on day -20, Y on
-- day -10, the payment on day -15, its match on day -12.
select pg_temp.as_owner(format('select public.match_invoice(%L, %L, ''exact'', ''a part'', 1000)::text',
  pg_temp.id('inv', 'PE-A'), pg_temp.id('pay', 'PA')));
update public.invoice_matches set status = 'pending' where workspace_id = current_setting('pe.ws')::uuid;
update public.events set status = 'pending'
 where id in (select event_id from public.invoice_match_payments where workspace_id = current_setting('pe.ws')::uuid);
set local session_replication_role = replica;
update public.invoices set issued_at = now() - interval '20 days' where id = pg_temp.id('inv', 'PE-A');
update public.invoices set issued_at = now() - interval '10 days' where id = pg_temp.id('inv', 'PE-Y');
update public.ledger_entries set created_at = now() - interval '15 days', occurred_on = current_date - 15
 where id = pg_temp.id('pay', 'PA');
update public.invoice_match_history set at = now() - interval '12 days' where workspace_id = current_setting('pe.ws')::uuid;
set local session_replication_role = origin;
-- The approval, dated day -5.
update public.events set status = 'confirmed'
 where id in (select event_id from public.invoice_match_payments where workspace_id = current_setting('pe.ws')::uuid);
update public.invoice_matches set status = 'confirmed' where workspace_id = current_setting('pe.ws')::uuid;
set local session_replication_role = replica;
update public.invoice_match_history set at = now() - interval '5 days'
 where workspace_id = current_setting('pe.ws')::uuid and at > now() - interval '1 hour';
set local session_replication_role = origin;

select is(pg_temp.holds(current_date - 20, current_date - 8), 'EUR:true JPY:true',
  'days -20 to -8: opening + movements = closing per currency, and both ends are the open-items statements');
select is(pg_temp.holds(current_date - 7, current_date), 'EUR:true JPY:true',
  'days -7 to today: the same; the yen, open without a movement, keeps its own statement');
select is(pg_temp.moves(current_date - 20, current_date - 8, 'EUR'),
  'invoice PE-A 1000 on -20 own -20, payment PA -1000 on -15 own -15, allocated PA 1000 on -12 own -15',
  'the invoice, the payment, and its allocation awaiting approval: the invoice stays due at the end of the period');
select is((pg_temp.period(current_date - 20, current_date - 8) -> 'currencies' -> 0 ->> 'closing_cents')::int, 1000,
  'so the period closes with the invoice due in full, as the open-items statement of day -8 says');
select is(pg_temp.moves(current_date - 7, current_date, 'EUR'), 'paid PE-A -1000 on -5 own -15',
  'the approval is in the period of the decision, with the payment''s own date on its line');
select is(pg_temp.moves(current_date - 20, current_date - 8, 'JPY'), 'invoice PE-Y 5000 on -10 own -10',
  'the yen has its own statement, in whole yen, nothing added to the euros');
select ok((select bool_and(jsonb_array_length(c -> 'movements') = 0 and c ->> 'opening_cents' = c ->> 'closing_cents')
             from jsonb_array_elements(pg_temp.period(current_date - 3, current_date - 2) -> 'currencies') c)
          and jsonb_array_length(pg_temp.period(current_date - 3, current_date - 2) -> 'currencies') = 1,
  'a period with no movement has two equal balances');
select is((pg_temp.period(current_date - 20, current_date - 8) ->> 'reconstructed_before')
          || ' ' || (pg_temp.period(current_date + 1, current_date + 1) ->> 'reconstructed_before'),
  'true false', 'a period before the match history says it is reconstructed; one after it does not');
select is(pg_temp.as_owner(format('select public.customer_statement_period_v1(%L, %L, %L, %L)::text',
            current_setting('pe.ws'), current_setting('pe.m1'), current_date, current_date - 1)),
  'ERROR 22023', 'a period ends after it starts');
select is(pg_temp.as_owner(format('select public.customer_statement_period_v1(%L, %L, %L, %L)::text',
            current_setting('pe.ws'), current_setting('pe.m1'), current_date - 7, current_date), true),
  'ERROR 42501', 'an assistant''s delegated session does not read it');

-- The history names the function that acted, also as the API layer quotes it.
select is(public.invoice_match_history_function_of(
            'WITH pgrst_source AS (SELECT "public"."match_invoice"("p_invoice_id" := $1, "p_amount_cents" := $2) pgrst_scalar) SELECT 1'),
          'match_invoice', 'a call through the API layer, its identifiers quoted, is named');
select is(public.invoice_match_history_function_of('select public.release_invoice_payment(''x'')'),
          'release_invoice_payment', 'and a call written plainly');

select * from finish();
rollback;
