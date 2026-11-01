-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2578 (0643) -- the payments behind the collected figure. The rows of
-- workspace_recorded_payments_v1 for a month are exactly the ones
-- kpi_finance_summary sums as collected (same total, same count, the same
-- local-midnight bounds on the workspace clock); a paged read returns every
-- row once, newest match first, and ends with no cursor; viewFinances reads,
-- a member, the owner of another space and anyone signed out are refused
-- (42501), money switched off is refused (55000), a malformed window or
-- cursor is refused (22023); another space's rows never appear.
begin;
select plan(22);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000025780a1';
  u_f uuid := '00000000-0000-4000-8000-0000025780a2';
  u_m uuid := '00000000-0000-4000-8000-0000025780a3';
  u_x uuid := '00000000-0000-4000-8000-0000025780a4';
  ws uuid; ws2 uuid; m uuid; m2 uuid; inv uuid; inv2 uuid; pay uuid;
  r record;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'recpay-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_f, u_m, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Collected', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x) returning id into ws2;
  -- The admin role here reads finances and nothing of the analysis: the
  -- payments are the finance reader's, not the analyst's.
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb)
                         || '{"moneyTab": true, "invoicing": true, "workspaceStatus": true}'
   where id in (ws, ws2);
  update public.workspaces
     set role_permissions = coalesce(role_permissions, '{}'::jsonb)
                            || '{"admin": ["viewFinances"]}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_f, false, true), (ws, u_m, false, false);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws2, u_x, true, true) returning id into m2;

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind)
  values (ws, m, m, 'F-1', 'May', '[]', 900000, 'EUR', 'Payer One', 'Collected', 'M', 's', '2025-05', 'full')
  returning id into inv;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind)
  values (ws2, m2, m2, 'E-1', 'May', '[]', 5000, 'EUR', 'Other', 'Elsewhere', 'X', 's', '2025-05', 'full')
  returning id into inv2;

  -- Seven payments of the space, matched at these instants (UTC):
  --   30 Apr 22:30 = 1 May 00:30 in Paris (in May), five in May (two at
  --   the very same instant: the id breaks the tie), 31 May 23:30 = June.
  for r in select * from (values
      (101, '2025-04-30 22:30+00'::timestamptz),
      (202, '2025-05-03 09:00+00'),
      (303, '2025-05-10 12:00+00'),
      (404, '2025-05-10 12:00+00'),
      (505, '2025-05-20 08:00+00'),
      (606, '2025-05-31 21:59+00'),
      (707, '2025-05-31 23:30+00')) v(amount, matched) loop
    insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                       amount_cents, description, period)
    values (ws, m, 'credit', 'payment', r.amount, 'bank transfer', '2025-05')
    returning id into pay;
    insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id,
                                               amount_cents, resolution, matched_at)
    values (ws, inv, pay, r.amount, 'under_accepted', r.matched);
  end loop;
  -- A recorded payment no match consumed is not collected.
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 99999, 'unmatched', '2025-05');
  -- The other space's one payment, in May too.
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws2, m2, 'credit', 'payment', 5000, 'elsewhere', '2025-05')
  returning id into pay;
  insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id,
                                             amount_cents, resolution, matched_at)
  values (ws2, inv2, pay, 5000, 'exact', '2025-05-15 10:00+00');

  perform set_config('rp.ws', ws::text, false);
  perform set_config('rp.ws2', ws2::text, false);
  perform set_config('rp.inv2', inv2::text, false);
  perform set_config('rp.owner', u_o::text, false);
  perform set_config('rp.finance', u_f::text, false);
  perform set_config('rp.member', u_m::text, false);
  perform set_config('rp.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    case when p_who = 'anonymous' then '{"role": "anon"}'
         else json_build_object('sub', current_setting('rp.' || p_who),
                                'role', 'authenticated')::text end, true);
end
$act$;

-- One page as p_who, or the SQLSTATE that refused it.
create or replace function pg_temp.page(p_who text, p_ws text, p_from date, p_to date,
                                        p_after jsonb default null, p_limit int default null)
returns jsonb language plpgsql as $p$
begin
  perform pg_temp.act_as(p_who);
  return public.workspace_recorded_payments_v1(current_setting('rp.' || p_ws)::uuid,
                                               p_from, p_to, p_after, p_limit);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$p$;

-- Every page of a read, followed by its cursor: {"items": [...], "pages": n}.
create or replace function pg_temp.all_pages(p_from date, p_to date, p_limit int)
returns jsonb language plpgsql as $a$
declare
  v_page jsonb; v_after jsonb; v_items jsonb := '[]'; v_pages int := 0;
begin
  loop
    v_page := pg_temp.page('owner', 'ws', p_from, p_to, v_after, p_limit);
    v_items := v_items || (v_page -> 'items');
    v_pages := v_pages + 1;
    v_after := v_page -> 'next_cursor';
    exit when v_after is null or jsonb_typeof(v_after) = 'null' or v_pages > 20;
  end loop;
  return jsonb_build_object('items', v_items, 'pages', v_pages);
end
$a$;

-- The KPI's own figure, as the owner (who also reads the analysis).
create or replace function pg_temp.kpi(p_month text) returns jsonb language plpgsql as $k$
begin
  perform pg_temp.act_as('owner');
  return public.kpi_finance_summary(current_setting('rp.ws')::uuid, p_month, p_month);
end
$k$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- ── the rows are the figure's ─────────────────────────────────────────
select is((select sum((e ->> 'amount_minor')::bigint)::bigint
             from jsonb_array_elements(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') -> 'items') e),
          (pg_temp.kpi('2025-05') ->> 'collected_minor')::bigint,
          'May: the listed amounts add up to the collected figure, to the cent');
select is(jsonb_array_length(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') -> 'items'),
          (pg_temp.kpi('2025-05') ->> 'matches')::int,
          'May: one row per payment the figure counts');
select is((select sum((e ->> 'amount_minor')::bigint)::bigint
             from jsonb_array_elements(pg_temp.page('owner', 'ws', '2025-06-01', '2025-06-30') -> 'items') e),
          (pg_temp.kpi('2025-06') ->> 'collected_minor')::bigint,
          'June: the match at 23:30 UTC on 31 May is June in Paris, as in the figure');
select is((select array_agg((e ->> 'amount_minor')::int order by (e ->> 'amount_minor')::int)
             from jsonb_array_elements(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') -> 'items') e),
          array[101, 202, 303, 404, 505, 606],
          'May holds the match of 22:30 UTC on 30 April and not the unmatched payment');
select is((pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') -> 'items' -> 0) - 'id' - 'invoice_id' - 'matched_at',
          jsonb_build_object('paid_on', (select occurred_on from public.ledger_entries
                                          where workspace_id = current_setting('rp.ws')::uuid
                                            and amount_cents = 606),
                             'amount_minor', '606', 'currency', 'EUR',
                             'invoice_number', 'F-1', 'payer_name', 'Payer One',
                             'resolution', 'under_accepted', 'label', 'bank transfer'),
          'a row names the date, the exact amount and currency, the invoice and the payer, nothing else');

-- ── paging ─────────────────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.all_pages('2025-05-01', '2025-05-31', 2) -> 'items'), 6,
          'two rows a page: six rows in all');
select is((pg_temp.all_pages('2025-05-01', '2025-05-31', 2) ->> 'pages')::int, 3,
          'in three pages, the last with no cursor');
select is((select count(distinct e ->> 'id')::int
             from jsonb_array_elements(pg_temp.all_pages('2025-05-01', '2025-05-31', 2) -> 'items') e),
          6, 'every row exactly once, the equal instants included');
select ok((select bool_and(prev is null or (prev_at, prev_id) > ((e ->> 'matched_at')::timestamptz, (e ->> 'id')::uuid))
             from (select e,
                          lag(e) over (order by n) as prev,
                          (lag(e) over (order by n) ->> 'matched_at')::timestamptz as prev_at,
                          (lag(e) over (order by n) ->> 'id')::uuid as prev_id
                     from jsonb_array_elements(pg_temp.all_pages('2025-05-01', '2025-05-31', 2) -> 'items')
                          with ordinality t(e, n)) s),
          'newest match first, the id breaking a tie, across pages');
select ok(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') -> 'next_cursor' = 'null'::jsonb,
          'a read that fits one page ends with no cursor');
select is((pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31', null, 100000) ->> 'page_size')::int,
          (public.setting_value(current_setting('rp.ws')::uuid, 'bi.detail_page_size') #>> '{}')::int,
          'a caller cannot ask for more than the registry''s page size');

-- ── who reads ──────────────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.page('finance', 'ws', '2025-05-01', '2025-05-31') -> 'items'), 6,
          'viewFinances alone reads the payments');
select is(pg_temp.page('member', 'ws', '2025-05-01', '2025-05-31') ->> 'refused', '42501',
          'a member without viewFinances is refused');
select is(pg_temp.page('stranger', 'ws', '2025-05-01', '2025-05-31') ->> 'refused', '42501',
          'the owner of another space is refused');
select is(pg_temp.page('anonymous', 'ws', '2025-05-01', '2025-05-31') ->> 'refused', '42501',
          'anyone signed out is refused');
select ok(not has_function_privilege('anon',
            'public.workspace_recorded_payments_v1(uuid, date, date, jsonb, int)', 'execute')
          and has_function_privilege('authenticated',
            'public.workspace_recorded_payments_v1(uuid, date, date, jsonb, int)', 'execute'),
          'anon cannot execute it; authenticated can');
select is((select array_agg(e ->> 'invoice_id')
             from jsonb_array_elements(pg_temp.page('stranger', 'ws2', '2025-05-01', '2025-05-31') -> 'items') e),
          array[current_setting('rp.inv2')],
          'the other space''s owner reads only that space''s payment');

-- ── refusals of the request ────────────────────────────────────────────
select is(pg_temp.page('owner', 'ws', '2025-05-31', '2025-05-01') ->> 'refused', '22023',
          'a reversed window is refused');
select is(pg_temp.page('owner', 'ws', '2023-05-01', '2025-05-01') ->> 'refused', '22023',
          'a window beyond 24 months is refused, the figure''s own bound');
select is(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31', '{"matched_at": "soon", "id": "x"}') ->> 'refused',
          '22023', 'a malformed cursor is refused');
select is(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31', null, 0) ->> 'refused', '22023',
          'a page of no rows is refused');

update public.workspaces set feature_flags = feature_flags || '{"moneyTab": false}'
 where id = current_setting('rp.ws')::uuid;
select is(pg_temp.page('owner', 'ws', '2025-05-01', '2025-05-31') ->> 'refused', '55000',
          'with money switched off nothing is read');

select * from finish();
rollback;
