-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3658 (0735): no currency is ever a default. No column of the schema
-- defaults to a currency and no function falls back to one; a payment that
-- names no currency is refused; every table holding amounts without a
-- currency of its own reaches one through its business or a parent; the
-- lock that keeps a business's currency once money exists is in place and
-- holds; workspace_status answers the business's own currency. Rolled back.
begin;
select plan(8);

do $seed$
declare u uuid := '00000000-0000-4000-8000-000000003658'; ws uuid; m uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@currency.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Yen space', 'JP', 'JPY', 'Asia/Tokyo', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (ws, u, true, true, 'active') returning id into m;
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.m', m::text, false);
  perform set_config('t.u', u::text, false);
end;
$seed$;

select is((select count(*)::int from information_schema.columns
            where table_schema = 'public' and column_default ~ '''[A-Z]{3}''::'), 0,
  'no column of the schema defaults to a currency');

select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public'
              and p.prosrc ~* 'coalesce\(\s*[a-z_.]*currenc[a-z_]*\s*,\s*''[A-Z]{3}''\s*\)'), 0,
  'no function falls back to a literal currency');

select throws_ok(
  format($$insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents)
           values (%L, %L, 'stripe', 'no-currency-1', '2026-11', 100)$$,
         current_setting('t.ws'), current_setting('t.m')),
  '23502', null, 'a payment that names no currency is refused, not given one');

-- Every table with an amount and no currency of its own reaches one: through
-- its business (workspace_id) or through a parent record (a foreign key).
select is((
  select count(*)::int from information_schema.tables t
   where t.table_schema = 'public' and t.table_type = 'BASE TABLE'
     and exists (select 1 from information_schema.columns c
                  where c.table_schema = 'public' and c.table_name = t.table_name
                    and c.column_name ~ '_cents$')
     and not exists (select 1 from information_schema.columns c
                      where c.table_schema = 'public' and c.table_name = t.table_name
                        and c.column_name ~ 'currenc')
     and not exists (select 1 from information_schema.columns c
                      where c.table_schema = 'public' and c.table_name = t.table_name
                        and c.column_name = 'workspace_id')
     and not exists (select 1 from information_schema.table_constraints k
                      where k.table_schema = 'public' and k.table_name = t.table_name
                        and k.constraint_type = 'FOREIGN KEY')), 0,
  'every table with amounts and no currency of its own reaches one through its business or a parent');

select ok(exists (select 1 from pg_trigger
                   where tgrelid = 'public.workspaces'::regclass
                     and tgname = 'workspaces_money_locale_guard' and tgenabled <> 'D'),
  'the lock that keeps a business''s currency once money exists is in place');

insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
values (current_setting('t.ws')::uuid, current_setting('t.m')::uuid, 'charge', 'subscription', 1250, 'A month', '2026-11');
select throws_ok(
  format($$update public.workspaces set currency_code = 'EUR' where id = %L$$, current_setting('t.ws')),
  'DK423', null, 'and holds: once money exists the currency does not change');

create function pg_temp.status() returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.workspace_status(current_setting('t.ws')::uuid, '2026-11', '2026-11');
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
select is(pg_temp.status() ->> 'currency', 'JPY', 'workspace_status answers the business''s own currency');
select is((select column_default from information_schema.columns
            where table_schema = 'public' and table_name = 'licence_plans' and column_name = 'currency'), null,
  'a licence plan names its currency');

select * from finish();
rollback;
