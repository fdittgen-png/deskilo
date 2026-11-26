-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4478 (0973): a deposit returned at the till. A sale of bread with two bottle deposits brought back is the bread less
-- the deposits; the returned line is the sale of the same deposits with every amount negated; finalized, the deposits come
-- back into stock once (a replay moves nothing again); a return alone is a draft and is refused at the finalize; a
-- negative tax under a positive total finalizes; a non-deposit item, a price on a returned line, a client's own `kind`, a
-- tracked deposit, a cashier without the right and a body that says it came offline are refused; the cap is on what is
-- sold; a correction takes a returned line back negated, within its absolute amount. Rolled back.
begin;
select plan(18);

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
create or replace function pg_temp.draft(p_user int, p_req int, p_lines text, p_extra text default '') returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), '{' || p_extra || '"lines": ' || p_lines || '}'))
$f$;
create or replace function pg_temp.fin(p_user int, p_req int, p_draft text) returns text language sql as $f$
  select case when p_draft not like '{%' then p_draft else pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), p_draft::jsonb ->> 'receipt_id', (p_draft::jsonb ->> 'revision')::int,
    format('[{"kind": "cash", "amount_minor": %s}]', p_draft::jsonb #>> '{totals,gross_minor}'))) end
$f$;
create or replace function pg_temp.corr(p_req int, p_orig uuid, p_lines text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), p_orig, '{"reason": "test", "lines": ' || p_lines || '}'))
$f$;
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
create or replace function pg_temp.t(p text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb #>> '{totals,gross_minor}' else p end
$f$;
create or replace function pg_temp.line(p_item int, p_qty text, p_extra text default '') returns text language sql as $f$
  select format('{"item_id": "%s", "quantity": "%s"%s}', pg_temp.u(p_item), p_qty, p_extra)
$f$;
create or replace function pg_temp.on_hand(p_item int) returns text language sql stable as $f$
  select coalesce(trim_scale(sum(b.quantity))::text, '0') from public.stock_balances b where b.item_id = pg_temp.u(p_item) and b.location_id = pg_temp.loc('MAIN')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'deposit-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Deposit FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true}',
   '{"member": ["issueInvoices"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
  (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard'),
  (pg_temp.u(802), pg_temp.u(101), 'Reduced', 5.5, 'S', false, 'reduced');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
-- the bottle deposit (stockable, untracked), the water sold with it, bread at the reduced rate, a mug (no deposit), and a
-- crate deposit tracked by lot that a crate of beer names
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, vat_rate_id) values
  (pg_temp.u(301), pg_temp.u(101), 'Bottle deposit', 25, true, 'piece', 'none', true, null, pg_temp.u(801)),
  (pg_temp.u(303), pg_temp.u(101), 'Bread', 200, true, 'piece', 'none', false, null, pg_temp.u(802)),
  (pg_temp.u(304), pg_temp.u(101), 'Mug', 500000000, true, 'piece', 'none', false, null, pg_temp.u(801)),
  (pg_temp.u(305), pg_temp.u(101), 'Crate deposit', 300, true, 'piece', 'lot', true, null, pg_temp.u(801));
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, deposit_item_id) values
  (pg_temp.u(302), pg_temp.u(101), 'Water', 100, true, 'piece', 'none', false, null, pg_temp.u(301)),
  (pg_temp.u(306), pg_temp.u(101), 'Crate of beer', 1500, true, 'piece', 'none', false, null, pg_temp.u(305));
select pg_temp.mv(1001, format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s"}]', pg_temp.u(301), pg_temp.loc('supplier'), pg_temp.loc('MAIN')));

-- a sale with two bottles brought back
select set_config('t.d', pg_temp.draft(1, 901, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(301, '2', ', "returned": true') || ']'), false);
select is(pg_temp.t(current_setting('t.d')), '150', 'bread at 2.00 less two bottle deposits at 0.25 is 1.50');
select set_config('t.twin', pg_temp.draft(1, 902, '[' || pg_temp.line(301, '2') || ']'), false);
select is((select string_agg(k || '=' || ((pg_temp.j(current_setting('t.d')) #>> array['lines','1','commercial','amounts',k])::bigint
                                          + (pg_temp.j(current_setting('t.twin')) #>> array['lines','0','commercial','amounts',k])::bigint)::text, ' ' order by k)
             from unnest(array['gross_minor','net_minor','tax_minor']) k)
          || ' cents=' || ((pg_temp.j(current_setting('t.d')) #>> '{lines,1,amount_cents}')::bigint + (pg_temp.j(current_setting('t.twin')) #>> '{lines,0,amount_cents}')::bigint)::text,
          'gross_minor=0 net_minor=0 tax_minor=0 cents=0', 'the returned line is exactly the opposite of the sale of the same deposits');
select is(pg_temp.j(current_setting('t.d')) #>> '{lines,1,kind}', 'deposit_return', 'and it says it is a returned deposit');
select set_config('t.f', pg_temp.fin(1, 903, current_setting('t.d')), false);
select is((pg_temp.j(current_setting('t.f')) ->> 'number') is not null and pg_temp.on_hand(301) = '12', true, 'finalized, the two bottles are back in stock');
select is(pg_temp.j(pg_temp.fin(1, 903, current_setting('t.d'))) ->> 'number', pg_temp.j(current_setting('t.f')) ->> 'number', 'the same request answers the same sale');
select is(pg_temp.on_hand(301), '12', 'and moves nothing again');

-- a return alone is a draft, never a receipt
select set_config('t.a', pg_temp.draft(1, 904, '[' || pg_temp.line(301, '1', ', "returned": true') || ']'), false);
select is(pg_temp.t(current_setting('t.a')), '-25', 'deposits brought back before anything is sold are a draft below zero');
select is(pg_temp.fin(1, 905, current_setting('t.a')), 'ERR DKL02 total_not_positive', 'which is not finalized');

-- a tax below zero under a total above zero
select set_config('t.n', pg_temp.draft(1, 906, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(301, '4', ', "returned": true') || ']'), false);
select is((pg_temp.j(current_setting('t.n')) #>> '{totals,tax_minor}')::bigint < 0 and (pg_temp.j(pg_temp.fin(1, 907, current_setting('t.n'))) ->> 'number') is not null, true,
          'bread at 5.5 % less deposits at 20 % has a negative tax and still finalizes');

-- refused
select is(left(pg_temp.draft(1, 910, '[' || pg_temp.line(304, '1', ', "returned": true') || ']'), 9) || (pg_temp.draft(1, 910, '[' || pg_temp.line(304, '1', ', "returned": true') || ']') like '%line_1_returned%')::text,
          'ERR DKL02true', 'a mug is no deposit to return');
select is(pg_temp.draft(1, 911, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(301, '1', ', "returned": true, "unit_price": "1"') || ']') like 'ERR DKL02%line_2_returned_price%', true,
          'a returned deposit takes no price of its own');
select is(pg_temp.draft(1, 912, '[' || pg_temp.line(304, '1', ', "kind": "deposit_return"') || ']') like 'ERR DKL02%line_1_kind%', true, 'a client''s kind is not the server''s');
select is(pg_temp.draft(1, 913, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(305, '1', ', "returned": true') || ']') like 'ERR DKL02%line_2_returned_tracked%', true,
          'a crate tracked by lot is not taken back at the till');
select is(pg_temp.draft(2, 914, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(301, '1', ', "returned": true') || ']'), 'ERR DKN01 {"reason": "deposit_return"}',
          'a cashier without the right to change a price returns no deposit');
select is(pg_temp.draft(1, 915, '[' || pg_temp.line(303, '1') || ', ' || pg_temp.line(301, '1', ', "returned": true') || ']', '"source_kind": "offline_till", '),
          'ERR DKL02 {"reason": "deposit_return_offline"}', 'nor offline');
select is(pg_temp.draft(1, 916, '[' || pg_temp.line(304, '3') || ', ' || pg_temp.line(304, '3') || ', ' || pg_temp.line(301, '40000000', ', "returned": true') || ']') like 'ERR DKL02%total_amount%', true,
          'the cap is on what is sold, not on what is left once the deposits are taken off');

-- a correction takes a returned line back negated, within its absolute amount
select set_config('t.lines', (select string_agg(x.id::text, ',' order by x.line_no) from public.counter_receipt_lines x where x.receipt_id = (pg_temp.j(current_setting('t.f')) ->> 'receipt_id')::uuid), false);
select set_config('t.c', pg_temp.corr(920, (pg_temp.j(current_setting('t.f')) ->> 'receipt_id')::uuid,
  format('[{"corrects_line_id": "%s", "quantity": "1"}, {"corrects_line_id": "%s", "quantity": "1"}]', split_part(current_setting('t.lines'), ',', 1), split_part(current_setting('t.lines'), ',', 2))), false);
select is(pg_temp.j(current_setting('t.c')) #>> '{totals,gross_minor}', '175', 'the bread and one returned bottle corrected: 2.00 less 0.25');
select is(pg_temp.corr(921, (pg_temp.j(current_setting('t.f')) ->> 'receipt_id')::uuid,
  format('[{"corrects_line_id": "%s", "quantity": "2"}]', split_part(current_setting('t.lines'), ',', 2))) like 'ERR DKL08%beyond_original%', true,
  'no more is corrected than the returned line has left');

select * from finish();
rollback;
