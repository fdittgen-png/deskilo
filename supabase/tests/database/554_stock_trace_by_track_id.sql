-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4436 (0933): the trace finds the sale from the track ID, and the track ID from the sale. A lot code as received, a
-- label code or a tag answers its lots or pieces and the counter receipt lines that sold them; a receipt is named only to
-- a finance reader; a sold line's chain names the track IDs it took; an unknown code answers nothing; an empty code, a
-- member of another business and an assistant are refused. Rolled back.
begin;
select plan(10);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
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
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
create or replace function pg_temp.loc(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and (code = p_kind or kind = p_kind) order by (code = p_kind) desc, created_datetime limit 1
$f$;
create or replace function pg_temp.find(p_user int, p_code text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_trace_find_v1(%L, %L)::text', pg_temp.u(101), p_code), p_delegated)
$f$;
create or replace function pg_temp.sell(p_req int, p_lines text, p_cash bigint) returns text language plpgsql as $f$
declare v_d text;
begin
  v_d := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req), '{"lines": ' || p_lines || '}'));
  if v_d like 'ERR%' then return v_d; end if;
  return pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req + 1), v_d::jsonb ->> 'receipt_id', format('[{"kind": "cash", "amount_minor": %s}]', p_cash)));
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trackfind-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Find FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{"member": ["viewStock"]}'),
  (pg_temp.u(102), 'Find other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'vat_registered', '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Honey', 500, true, 'piece', 'lot', true, null),
  (pg_temp.u(303), pg_temp.u(101), 'Basket', 1000, true, 'piece', 'serial', true, 'per_unit');

do $s$ begin
  perform pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(1001),
    format('[{"item_id": "%s", "quantity": "4", "from": "%s", "to": "%s", "new_lot": {"code": "SUP-A", "expires_on": "2090-01-01", "total_cost_minor": 100}},
             {"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6DD01"}, {"tag": "E28068940000401561D6DD02"}], "new_lot": {"code": "SUP-P", "total_cost_minor": 300}}]',
      pg_temp.u(301), pg_temp.loc('supplier'), pg_temp.loc('MAIN'), pg_temp.u(303), pg_temp.loc('supplier'), pg_temp.loc('MAIN')), 'receipt'));
end $s$;
select set_config('t.s', pg_temp.sell(1100, format('[{"item_id": "%s", "quantity": "3"}, {"item_id": "%s", "quantity": "1", "units": [{"tag": "E28068940000401561D6DD02"}]}]',
  pg_temp.u(301), pg_temp.u(303)), 2500), false);
select set_config('t.n', coalesce(pg_temp.j(current_setting('t.s')) ->> 'number', ''), false);

select is((pg_temp.j(pg_temp.find(1, 'SUP-A')) #>> '{lots,0,item}') || ' ' || (pg_temp.j(pg_temp.find(1, 'SUP-A')) #>> '{sales,0,quantity}') || ' ' ||
          ((pg_temp.j(pg_temp.find(1, 'SUP-A')) #>> '{sales,0,document,label}') = current_setting('t.n'))::text,
  'Honey 3 true', 'a lot code as received finds the lot and the receipt that sold from it, with the quantity');
select is(pg_temp.j(pg_temp.find(1, 'sup-a')) #>> '{lots,0,code}', 'SUP-A', 'the lot code is found whatever its case');
select is((pg_temp.j(pg_temp.find(1, 'E28068940000401561D6DD02')) #>> '{pieces,0,item}') || ' ' ||
          jsonb_array_length(pg_temp.j(pg_temp.find(1, 'E28068940000401561D6DD02')) -> 'sales')::text || ' ' ||
          (pg_temp.j(pg_temp.find(1, 'E28068940000401561D6DD02')) #>> '{pieces,0,state}'),
  'Basket 1 sold', 'a piece''s tag finds the piece, sold, and its sale');
select is(jsonb_array_length(pg_temp.j(pg_temp.find(1, 'E28068940000401561D6DD01')) -> 'sales'), 0, 'a piece still on hand has no sale');
select is(pg_temp.j(pg_temp.find(2, 'SUP-A')) #>> '{sales,0,document,state}', 'unavailable', 'a reader of the stock without the finances sees that a receipt sold it, not which');
select is(pg_temp.j(pg_temp.find(1, 'NOTHING-HERE')) ->> 'lots', '[]', 'an unknown code answers nothing');
select is(pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.stock_trace_chain_v1(%L, p_counter_line_id => %L)::text', pg_temp.u(101),
            (select id from public.counter_receipt_lines where receipt_id = (pg_temp.j(current_setting('t.s')) ->> 'receipt_id')::uuid and line_no = 2))))
          #>> '{took,tracks,1,code}', 'E28068940000401561D6DD02', 'a sold line''s chain names the track IDs it took (its lot, then its piece by its tag)');
select is(left(pg_temp.find(1, ''), 9), 'ERR DKG11', 'an empty code is refused');
select is(left(pg_temp.find(3, 'SUP-A'), 9), 'ERR DKN01', 'a member of another business reads nothing');
select is(left(pg_temp.find(1, 'SUP-A', true), 9), 'ERR DKN01', 'an assistant reads nothing');

select * from finish();
rollback;
