-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4366 / #4436 (0967): the lots a till may sell an item from. The cashier (no stock right) reads the honey's lots at the
-- place a sale takes from, the first to expire first, each with its code, its date and what is on hand, the expired one
-- marked; an untracked item has none; a member who works no counter, and another business's item, are refused; a sale
-- naming the second lot takes that lot, not the first to expire. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.loc(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and (code = p_kind or kind = p_kind) order by (code = p_kind) desc, created_datetime limit 1
$f$;
create or replace function pg_temp.mv(p_req int, p_lines text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, 'receipt'))
$f$;
create or replace function pg_temp.sell(p_req int, p_lines text, p_cash bigint) returns text language plpgsql as $f$
declare v_d text;
begin
  v_d := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req), '{"lines": ' || p_lines || '}'));
  if v_d like 'ERR%' then return v_d; end if;
  -- the cash is the draft's total when none is given
  return pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req + 1), v_d::jsonb ->> 'receipt_id',
           format('[{"kind": "cash", "amount_minor": %s}]', coalesce(p_cash, (v_d::jsonb #>> '{totals,gross_minor}')::bigint))));
end
$f$;
create or replace function pg_temp.codes(p jsonb) returns text language sql immutable as $f$
  select coalesce(string_agg((t ->> 'kind') || ':' || coalesce(t ->> 'code', '-') || coalesce('x' || (t ->> 'quantity'), ''), ' ' order by o), '')
    from jsonb_array_elements(p) with ordinality x (t, o)
$f$;
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.lots(p_user int, p_item int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_item_lots_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(p_item)))
$f$;
create or replace function pg_temp.said(p text) returns text language sql immutable as $f$
  select case when p like '{%' then coalesce((select string_agg((l ->> 'code') || ':' || (l ->> 'quantity') || case when (l ->> 'expired')::boolean then ':expired' else '' end, ' ' order by o)
                                               from jsonb_array_elements(p::jsonb -> 'lots') with ordinality x (l, o)), '') else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tlots-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Till lots FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true}',
   '{"member": ["issueInvoices"]}'),
  (pg_temp.u(102), 'Till lots other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(298), pg_temp.u(102), pg_temp.u(3), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Honey', 500, true, 'piece', 'lot', true, null),
  (pg_temp.u(306), pg_temp.u(101), 'Bag', 50, true, 'piece', 'none', true, null),
  (pg_temp.u(307), pg_temp.u(102), 'Foreign honey', 500, true, 'piece', 'lot', true, null);

-- honey: an expired lot (OLD), SUP-A first to expire of the good ones, SUP-B; the bag untracked
do $s$
declare
  v_line text := '{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s", "expired_ack": true, "new_lot": {"code": "%s", "expires_on": "%s", "total_cost_minor": 100}}';
begin
  perform pg_temp.mv(1001, '[' || concat_ws(', ',
    format(v_line, pg_temp.u(301), '10', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'OLD', '2020-01-01'),
    format(v_line, pg_temp.u(301), '2', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'SUP-A', '2090-01-01'),
    format(v_line, pg_temp.u(301), '5', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'SUP-B', '2091-01-01')) || ', ' ||
    format('{"item_id": "%s", "quantity": "4", "from": "%s", "to": "%s"}', pg_temp.u(306), pg_temp.loc('supplier'), pg_temp.loc('MAIN')) || ']');
end $s$;

select is(pg_temp.said(pg_temp.lots(2, 301)), 'OLD:10:expired SUP-A:2 SUP-B:5', 'the cashier reads the honey''s lots, the first to expire first, the expired one marked');
select is(pg_temp.said(pg_temp.lots(2, 306)), '', 'an untracked item has no lot to choose');
select is(left(pg_temp.lots(3, 301), 9), 'ERR DKN01', 'a member who works no counter here reads none');
select is(pg_temp.lots(2, 307), 'ERR DKL02 {"reason": "item"}', 'another business''s item is not this business''s');

-- a sale naming SUP-B takes SUP-B
select set_config('t.lot', (select id::text from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = 'SUP-B'), false);
select is(pg_temp.j(pg_temp.sell(2001, format('[{"item_id": "%s", "quantity": "1", "lot_id": "%s"}]', pg_temp.u(301), current_setting('t.lot')), null)) ->> 'number' is not null, true,
          'a sale naming the lot is finalized');
select is((select string_agg(l.lot_code || '=' || trim_scale(b.quantity)::text, ' ' order by l.lot_code)
             from public.stock_balances b join public.stock_lots l on l.id = b.lot_id
            where b.item_id = pg_temp.u(301) and b.location_id = pg_temp.loc('MAIN')),
          'OLD=10 SUP-A=2 SUP-B=4', 'it took the lot named, not the first to expire');
select is(pg_temp.said(pg_temp.lots(2, 301)), 'OLD:10:expired SUP-A:2 SUP-B:4', 'and the lots read what is left');

select * from finish();
rollback;
