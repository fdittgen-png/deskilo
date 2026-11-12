-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3811 (0740, part of #3657): an invoicing refusal carries its code, as the
-- booking refusals do since 0739. Structure: every invoicing sentence the app
-- read by its words carries its code, and the codes exist. The assistant's
-- outcome reads these codes as "refused" with their reason, as it reads
-- P0001. Behaviour: a second invoice for an invoiced period is DKI07, with
-- the message an app from before reads. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.refusal(sql text) returns text language plpgsql as $f$
declare v_state text; v_message text;
begin
  execute sql;
  return 'no refusal';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_message = message_text;
  return v_state || '|' || v_message;
end
$f$;

create temporary table invoicing_raises on commit drop as
  select p.proname, m[1] as stmt from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
         regexp_matches(p.prosrc, '(raise exception ''(?:[^'']|'''')*''[^;]*;)', 'g') m
   where n.nspname = 'public'
     and p.proname in ('respond_to_event', 'match_einvoice', 'reject_einvoice', 'apply_supplier_credit_note_v1',
                       'void_invoice', 'record_invoice_reminder', 'settle_credit_invoice', 'create_invoice',
                       'match_invoice');

select is((select string_agg(proname || ': ' || left(stmt, 80), E'\n') from invoicing_raises
            where stmt ~ '(already decided|invoice is voided|invoice is matched|invoice already replaced|invoice already matched|already invoiced for this member)'
              and stmt !~ 'errcode'), null,
  'every invoicing refusal the app read by its words carries its code');
select is((select count(distinct c[1])::int from invoicing_raises, regexp_matches(stmt, 'errcode = ''(DKI0[3-7]|DKD01)''', 'g') c), 6,
  'the six codes of 0740 are raised');

select is(public.mcp_outcome_of('DKI03', 'invoice is voided') ->> 'status',
          public.mcp_outcome_of('P0001', 'invoice is voided') ->> 'status',
  'the assistant reads a coded invoicing refusal as it read P0001');
select is(public.mcp_outcome_of('DKD01', 'already decided') -> 'data' ->> 'reason', 'already decided',
  'and gives its reason');
select is(public.mcp_outcome_of('DKI01', 'invoice_essentials_missing') ->> 'status',
          public.mcp_outcome_of('P0001', 'x') ->> 'status',
  'essentials missing answers "refused" too');

-- A second invoice for an invoiced period.
create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare u_o uuid := '00000000-0000-4000-8000-0000038110a1'; u_m uuid := '00000000-0000-4000-8000-0000038110a2';
        ws uuid; m_m uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'inv-refusal-' || x || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) x;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags,
                                 street, city, postal_code, vat_regime)
  values ('Refused invoices', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "numberSequences": true}'::jsonb,
          '1 rue du Pilote', 'Pézenas', '34120', 'exempt')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at, customer_capacity)
  values (ws, u_o, true, true, 'active', '2026-01-01', 'consumer'),
         (ws, u_m, false, false, 'active', '2026-01-01', 'consumer');
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR',
         street = '2 rue du Test', city = 'Pézenas', postal_code = '34120'
   where id = u_m;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (ws, m_m, 'charge', 'service', 1500, 'A room', '2026-09', '2026-09-10');
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.m', m_m::text, false);
  perform set_config('t.o', u_o::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as_owner(sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.o'), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  v := pg_temp.refusal(sql);
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(pg_temp.as_owner(format($$select public.create_invoice(%L, %L, '2026-09')$$, current_setting('t.ws'), current_setting('t.m'))),
  'no refusal', 'the month is invoiced once');
select is(pg_temp.as_owner(format($$select public.create_invoice(%L, %L, '2026-09')$$, current_setting('t.ws'), current_setting('t.m'))),
  'DKI07|period already invoiced for this member',
  'a second invoice for it is DKI07, with the message an app from before reads');

select * from finish();
rollback;
