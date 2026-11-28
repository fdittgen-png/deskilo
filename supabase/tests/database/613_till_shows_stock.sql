-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4520 (1006): an item shows its stock at the till by its own setting, else its subgroup's, else its group's, and is
-- off when none says; whoever may sell reads, where it is on, the quantity on hand of each item that shows it, over the
-- places that hold stock (not a virtual one), 0 included; no other item; nothing for someone who may not sell. Rolled back.
begin;
select plan(9);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.stock(p_user int, p_ws int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_till_stock_v1(%L, null)::text', pg_temp.u(p_ws)))
$f$;
create or replace function pg_temp.qty(p_list text, p_item int) returns text language sql as $f$
  select x ->> 'quantity' from jsonb_array_elements(p_list::jsonb) x where x ->> 'item_id' = pg_temp.u(p_item)::text
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tstock-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, role_permissions, feature_flags) values
  (pg_temp.u(101), 'Stock at the till FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"admin": ["issueInvoices"]}',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "counterStockOnKeys": true}'),
  (pg_temp.u(102), 'Stock off FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{}',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active'),    -- a cashier: an admin, who may sell
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active'),   -- a member who may not sell
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(1), true, true, 'active');
insert into public.item_groups (id, workspace_id, name, till_shows_stock) values (pg_temp.u(301), pg_temp.u(101), 'Bakery', true);
insert into public.item_groups (id, workspace_id, parent_id, name) values (pg_temp.u(302), pg_temp.u(101), pg_temp.u(301), 'Bread');
insert into public.services (id, workspace_id, name, price_cents, active, stockable, group_id, till_shows_stock) values
  (pg_temp.u(901), pg_temp.u(101), 'Baguette', 120, true, true, pg_temp.u(302), null),   -- from its group, through its subgroup
  (pg_temp.u(902), pg_temp.u(101), 'Croissant', 110, true, true, pg_temp.u(302), false),  -- its own: off
  (pg_temp.u(903), pg_temp.u(101), 'Jam', 450, true, true, null, true),                   -- its own: on, none in stock
  (pg_temp.u(904), pg_temp.u(101), 'Flour', 300, true, true, null, null);                 -- nobody says: off
insert into public.stock_locations (id, workspace_id, kind, code, name) values
  (pg_temp.u(401), pg_temp.u(101), 'shelf', 'S1', 'Shelf'), (pg_temp.u(402), pg_temp.u(101), 'shelf', 'S2', 'Back');
insert into public.stock_balances (workspace_id, item_id, location_id, quantity) values
  (pg_temp.u(101), pg_temp.u(901), pg_temp.u(401), 7), (pg_temp.u(101), pg_temp.u(901), pg_temp.u(402), 5),
  (pg_temp.u(101), pg_temp.u(901), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'loss'), 3),
  (pg_temp.u(101), pg_temp.u(902), pg_temp.u(401), 9);

select is(public.item_till_shows_stock(s), true, 'an item without its own setting takes its subgroup''s, then its group''s')
  from public.services s where s.id = pg_temp.u(901);
select is(public.item_till_shows_stock(s), false, 'an item''s own setting overrides its group''s')
  from public.services s where s.id = pg_temp.u(902);
select is(public.item_till_shows_stock(s), false, 'and an item nobody set shows nothing') from public.services s where s.id = pg_temp.u(904);
select is(pg_temp.qty(pg_temp.stock(2, 101), 901)::numeric, 12::numeric, 'a cashier reads the stock of a shown item over the places that hold stock, not the loss');
select is(pg_temp.qty(pg_temp.stock(2, 101), 903)::numeric, 0::numeric, 'an item with none in stock says 0');
select is(pg_temp.qty(pg_temp.stock(2, 101), 902), null, 'an item that does not show its stock is not read');
select is(pg_temp.qty(pg_temp.stock(2, 101), 904), null, 'nor one nobody set');
select is(left(pg_temp.stock(3, 101), 9), 'ERR DKN01', 'a member who may not sell reads nothing');
select is(left(pg_temp.stock(1, 102), 9), 'ERR DKN01', 'where the stock is not shown at the till, nothing is read');

select * from finish();
rollback;
