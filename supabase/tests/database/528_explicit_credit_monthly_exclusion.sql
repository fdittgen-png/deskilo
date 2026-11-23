-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4165 B1: an explicit credit is spent only by its allocations. The monthly derivation (invoice_lines_for) deducts
-- the legacy credits of its month and never an explicit one; the customer statement keeps showing an explicit credit
-- after a monthly invoice of its month is issued, while a legacy one stays treated as deducted there; match_invoice_part
-- lets an explicit credit settle a standalone invoice where a legacy credit of an invoiced month is refused; and the
-- credit-note excess of an explicit payment stays explicit. Rolled back.
begin;
select plan(8);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000041651a1';
  u_a uuid := '00000000-0000-4000-8000-0000041651a2';
  ws uuid; m_o uuid; m_a uuid;
  d date;
  p text;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'explicit-credit-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Explicit credit', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws;
  delete from public.validation_policies where workspace_id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_a, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  d := public.workspace_today(ws);
  p := to_char(d, 'YYYY-MM');
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, allocation_mode)
  values (ws, m_a, 'credit', 'payment', 800, 'explicit receipt', p, 'explicit'),
         (ws, m_a, 'credit', 'payment', 300, 'legacy receipt', p, 'legacy'),
         (ws, m_a, 'credit', 'payment', 1500, 'explicit overpayment', p, 'explicit');
  -- A monthly invoice of the credits' month, issued after them.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, issued_at, kind,
                               source, service_date, due_on)
  values (ws, m_a, m_o, 'EC-M1', 'M1', '[]'::jsonb, 2000, 'EUR', 'Ada', 'Explicit credit', 'Owner', 'sig', p, now() + interval '1 minute', 'full', 'monthly', null, null),
         (ws, m_a, m_o, 'EC-S1', 'S1', '[]'::jsonb, 800, 'EUR', 'Ada', 'Explicit credit', 'Owner', 'sig', null, now() + interval '1 minute', 'full', 'standalone', d, d + 10),
         (ws, m_a, m_o, 'EC-S2', 'S2', '[]'::jsonb, 300, 'EUR', 'Ada', 'Explicit credit', 'Owner', 'sig', null, now() + interval '1 minute', 'full', 'standalone', d, d + 10),
         (ws, m_a, m_o, 'EC-S3', 'S3', '[]'::jsonb, 1000, 'EUR', 'Ada', 'Explicit credit', 'Owner', 'sig', null, now() + interval '1 minute', 'full', 'standalone', d, d + 10);
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.m_o', m_o::text, true);
  perform set_config('t.m_a', m_a::text, true);
  perform set_config('t.p', p, true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as
  $$ select id from public.invoices where number = p_number $$;
create or replace function pg_temp.credit(p_description text) returns uuid language sql as
  $$ select id from public.ledger_entries where description = p_description and member_id = current_setting('t.m_a')::uuid $$;
create or replace function pg_temp.owner() returns public.members language sql as
  $$ select m from public.members m where m.id = current_setting('t.m_o')::uuid $$;
create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000041651' || p_user, 'role', 'authenticated')::text, true);
end $$;
grant execute on all functions in schema pg_temp to authenticated;
create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlerrm; end $$;

-- ── The monthly derivation, as the owner who issues it ──────────────────
-- invoice_lines_for is the server's (create_invoice calls it); member_statement reads who asks.
select pg_temp.act('a1');
select is((select coalesce(sum((l ->> 'amount_cents')::int), 0)::int from jsonb_array_elements(
             public.invoice_lines_for(current_setting('t.m_a')::uuid, current_setting('t.p'))) l
            where l ->> 'kind' = 'payment'),
  -300, 'a month''s bill deducts its legacy credit only, never the explicit ones');

-- ── The customer statement, after the monthly invoice of their month ────
select is((select string_agg(line ->> 'description', ', ' order by line ->> 'description')
             from public.customer_statement_items(current_setting('t.ws')::uuid, current_setting('t.m_a')::uuid,
                                                  now() + interval '1 hour')
            where kind = 'credit'),
  'explicit overpayment, explicit receipt', 'the explicit credits stay on the statement; the legacy one counts as deducted');

-- ── Allocation ───────────────────────────────────────────────────────────
select lives_ok($$select public.match_invoice_part(pg_temp.owner(), pg_temp.inv('EC-S1'), pg_temp.credit('explicit receipt'), 'exact', '', 800)$$,
  'an explicit credit settles a standalone invoice although a monthly invoice of its month was issued');
select is(public.invoice_still_due_cents(pg_temp.inv('EC-S1')), 0::bigint, 'and the standalone invoice is paid');
select is(pg_temp.refusal($$select public.match_invoice_part(pg_temp.owner(), pg_temp.inv('EC-S2'), pg_temp.credit('legacy receipt'), 'exact', '', 300)$$),
  'credit already deducted on an issued invoice', 'a legacy credit of an invoiced month is still refused');
select lives_ok($$select public.match_invoice_part(pg_temp.owner(), pg_temp.inv('EC-S3'), pg_temp.credit('explicit overpayment'), 'over_credit_note', '', 1500)$$,
  'an explicit overpayment settles a standalone invoice with a credit note for the excess');
select is((select l.allocation_mode || ':' || l.amount_cents from public.ledger_entries l
             join public.invoice_matches m on m.credit_ledger_id = l.id
            where m.invoice_id = pg_temp.inv('EC-S3')),
  'explicit:500', 'the excess credit stays explicit');
select is((select count(*)::int from public.ledger_entries
            where member_id = current_setting('t.m_a')::uuid and allocation_mode = 'legacy'),
  1, 'nothing else became legacy');

select * from finish();
rollback;
