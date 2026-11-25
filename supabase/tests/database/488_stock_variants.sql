-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4169 (0837, A2): dimensions, variants and the supplier's article. Variants are
-- separate stock (red and blue at one place), the ledger without a variant is
-- what it was, and the commands are guarded as the configuration's. (The A1 header follows.) Units are
-- exact and per item (1 carton = 12 pieces, 1 glass = 1/5 litre), a used
-- factor is frozen with each movement, the first movement fixes the unit and
-- the tracking, codes are unique per business and a GTIN has its check digit,
-- a stale revision changes nothing, a request id answers once, places form a
-- tree with no cycle and are deactivated, never deleted, and only a stock
-- manager of the business writes. Rolled back.
begin;
select plan(44);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
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

create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;

create or replace function pg_temp.rev(p_item int) returns int language sql stable as $f$
  select stock_revision from public.services where id = pg_temp.u(p_item)
$f$;

-- save_stock_item_v1 as a person; the request ids are numbers
create or replace function pg_temp.save_item(p_user int, p_item int, p_rev int, p_req int, p_body text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_item), p_rev, pg_temp.u(p_req), p_body), p_delegated)
$f$;

create or replace function pg_temp.save_place(p_user int, p_place uuid, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_location_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_place, p_rev, pg_temp.u(p_req), p_body))
$f$;

create or replace function pg_temp.move(p_req int, p_item int, p_qty numeric, p_from text, p_to text, p_unit text default null)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, '||(case when p_from = 'SUPPLIER' then '''receipt''' when p_to in ('CUSTOMER', 'LOSS') then '''loss''' else '''transfer''' end)||')::text',
    pg_temp.u(101), pg_temp.u(p_req), jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty,
      'from', pg_temp.loc(p_from), 'to', pg_temp.loc(case when p_to = 'CUSTOMER' then 'LOSS' else p_to end)) || case when p_unit is null then '{}'::jsonb else jsonb_build_object('unit', p_unit) end)))
$f$;

create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end
$f$;

grant execute on all functions in schema pg_temp to authenticated, anon;


create or replace function pg_temp.dim(p_user int, p_dim uuid, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_item_dimension_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_dim, p_rev, pg_temp.u(p_req), p_body))
$f$;
create or replace function pg_temp.variants(p_user int, p_item int, p_rev int, p_req int, p_body text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_item_variants_v1(%L, %L, %s, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_item), p_rev, pg_temp.u(p_req), p_body), p_delegated)
$f$;
create or replace function pg_temp.mapping(p_user int, p_map uuid, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_supplier_item_mapping_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_map, p_rev, pg_temp.u(p_req), p_body))
$f$;
create or replace function pg_temp.move(p_req int, p_item int, p_qty numeric, p_from text, p_to text, p_variant uuid default null, p_extra jsonb default '{}'::jsonb)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, '||(case when p_from = 'SUPPLIER' then '''receipt''' when p_to in ('CUSTOMER', 'LOSS') then '''loss''' else '''transfer''' end)||')::text',
    pg_temp.u(101), pg_temp.u(p_req), jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty,
      'from', pg_temp.loc(p_from), 'to', pg_temp.loc(case when p_to = 'CUSTOMER' then 'LOSS' else p_to end)) || case when p_variant is null then '{}'::jsonb else jsonb_build_object('variant_id', p_variant) end || p_extra)))
$f$;
create or replace function pg_temp.on_hand(p_variant uuid, p_item int default 301) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item)
    and variant_id is not distinct from p_variant and location_id = pg_temp.loc('MAIN')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'variants-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Variants A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": false}', '{"member": ["viewStock"]}'),
  (pg_temp.u(102), 'Variants B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Shirt', 2500, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Mug', 800, true, null, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(102), 'Hat', 900, true, null, 'piece', 'none', true);
-- #4471: an item's own unit is one of the business's units, so the fixtures say which
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'box', 'Box', 'count', 1, 1);
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Textiles Nord'),
  (pg_temp.u(402), pg_temp.u(102), 'S-1', 'Other business supplier');
update public.workspaces set feature_flags = '{"stockManagement": true, "stockTakeOut": true}' where id in (pg_temp.u(101), pg_temp.u(102));

-- Dimensions and their values.
select is((pg_temp.dim(1, null, null, 701, '{"name": "Colour", "values": [{"label": "Red"}, {"label": "Blue"}]}')::jsonb ->> 'revision'), '1',
  'a dimension is created with its values');
select set_config('t.colour', (select id::text from public.item_dimensions where name = 'Colour'), false);
select set_config('t.red', (select id::text from public.item_dimension_values where label = 'Red'), false);
select set_config('t.blue', (select id::text from public.item_dimension_values where label = 'Blue'), false);
select pg_temp.dim(1, null, null, 702, '{"name": "Size", "values": [{"label": "M"}, {"label": "L"}]}');
select set_config('t.size', (select id::text from public.item_dimensions where name = 'Size'), false);
select set_config('t.m', (select id::text from public.item_dimension_values where label = 'M'), false);
select is(pg_temp.dim(1, null, null, 703, '{"name": "Colour"}'),
  'ERR DKG11 {"field": "name", "reason": "name_duplicate"}', 'a dimension name is unique in the business');
select is(pg_temp.dim(1, current_setting('t.colour')::uuid, 1, 704, '{"values": [{"label": "Red"}, {"label": "Red"}]}'),
  'ERR DKG11 {"field": "values[0].label", "reason": "name_duplicate"}', 'a value label is unique in its dimension, existing values included');

-- Variants of one item.
select is((pg_temp.variants(1, 301, 1, 711, format('[{"values": {"%s": "%s", "%s": "%s"}, "price_cents": 2600}, {"values": {"%s": "%s", "%s": "%s"}}]',
            current_setting('t.colour'), current_setting('t.red'), current_setting('t.size'), current_setting('t.m'),
            current_setting('t.colour'), current_setting('t.blue'), current_setting('t.size'), current_setting('t.m')))::jsonb ->> 'revision'), '2',
  'red/M and blue/M are the variants of the shirt, the item revision moves');
select set_config('t.vr', (select id::text from public.item_variants where item_id = pg_temp.u(301) and price_cents = 2600), false);
select set_config('t.vb', (select id::text from public.item_variants where item_id = pg_temp.u(301) and price_cents is null), false);
select is(pg_temp.variants(1, 301, 2, 712, format('[{"values": {"%s": "%s"}}, {"values": {"%s": "%s"}}]',
            current_setting('t.colour'), current_setting('t.red'), current_setting('t.colour'), current_setting('t.red'))),
  'ERR DKG11 {"field": "variants[1].values", "reason": "variant_combination_duplicate"}', 'the same combination twice is refused');
select is(pg_temp.variants(1, 301, 2, 713, format('[{"values": {"%s": "%s"}}]', current_setting('t.size'), current_setting('t.red'))),
  'ERR DKG11 {"field": "variants[0].values", "reason": "value_foreign"}', 'a value that is not of its dimension is refused');
select is(pg_temp.variants(3, 303, 1, 715, format('[{"values": {"%s": "%s"}}]', current_setting('t.colour'), current_setting('t.red')), 102),
  'ERR DKG11 {"field": "variants[0].values", "reason": "value_foreign"}', 'a value of another business is refused');

-- Red and blue at one place are separate stock.
select pg_temp.move(801, 301, 5, 'SUPPLIER', 'MAIN', current_setting('t.vr')::uuid);
select pg_temp.move(802, 301, 3, 'SUPPLIER', 'MAIN', current_setting('t.vb')::uuid);
select is(pg_temp.on_hand(current_setting('t.vr')::uuid)::text || ' ' || pg_temp.on_hand(current_setting('t.vb')::uuid)::text, '5.000000 3.000000',
  'five red and three blue at MAIN are two balances');
select pg_temp.move(803, 301, 2, 'MAIN', 'CUSTOMER', current_setting('t.vr')::uuid);
select is(pg_temp.on_hand(current_setting('t.vr')::uuid)::text || ' ' || pg_temp.on_hand(current_setting('t.vb')::uuid)::text, '3.000000 3.000000',
  'taking two red leaves three red and three blue');
select is(left(pg_temp.move(804, 301, 4, 'MAIN', 'CUSTOMER', current_setting('t.vb')::uuid), 9), 'ERR DKG03',
  'four blue are not taken from three blue although six shirts are there');

-- Variant of another item or business, and an inactive one.
select is(left(pg_temp.move(806, 302, 1, 'SUPPLIER', 'MAIN', current_setting('t.vr')::uuid), 9), 'ERR DKG04',
  'a variant of another item is refused');
select is((select count(*) from public.stock_balances where item_id = pg_temp.u(301) and variant_id is null)::int, 0,
  'no balance exists without the variant for an item that is moved by variant');

-- Identical labels, different ids; a deactivated value keeps its variant's label.
select pg_temp.dim(1, null, null, 721, '{"name": "Tone", "values": [{"label": "Red"}]}');
select is((select count(*) from public.item_dimension_values where label = 'Red')::int, 2,
  'two values labelled Red are two ids');
select is(public.stock_variant_label(current_setting('t.vr')::uuid), 'Colour: Red · Size: M', 'a variant reads as its dimensions and values');
select pg_temp.dim(1, current_setting('t.colour')::uuid, 1, 722, format('{"values": [{"id": "%s", "label": "Blue"}]}', current_setting('t.blue')));
select is(public.stock_variant_label(current_setting('t.vr')::uuid), 'Colour: Red · Size: M',
  'a value left out of the list is deactivated, never deleted: the variant that names it keeps its label');
select is(pg_temp.variants(1, 301, 2, 723, format('[{"id": "%s", "values": {"%s": "%s"}}]', current_setting('t.vr'), current_setting('t.colour'), current_setting('t.blue'))),
  'ERR DKG11 {"field": "variants[0].values", "reason": "variant_in_use"}', 'the combination of a variant that has stock stays as written');

-- Codes name a variant of their item.
select is((pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text$q$,
          pg_temp.u(101), pg_temp.u(301), (select stock_revision from public.services where id = pg_temp.u(301)), pg_temp.u(731),
          format('{"codes": [{"code": "SHIRT-RED", "kind": "own", "variant_id": "%s"}]}', current_setting('t.vr'))))::jsonb ->> 'replayed'), 'false',
  'a barcode may name a variant');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text$q$,
          pg_temp.u(101), pg_temp.u(302), (select stock_revision from public.services where id = pg_temp.u(302)), pg_temp.u(732),
          format('{"codes": [{"code": "MUG-1", "kind": "own", "variant_id": "%s"}]}', current_setting('t.vr')))),
  'ERR DKG11 {"field": "codes[0].variant_id", "reason": "variant_unknown"}', 'a code cannot name the variant of another item');

-- A lot belongs to one variant.
select pg_temp.move(811, 301, 4, 'SUPPLIER', 'MAIN', current_setting('t.vr')::uuid, '{"new_lot": {"code": "L1", "total_cost_minor": 400}}');
select is(left(pg_temp.move(812, 301, 1, 'MAIN', 'CUSTOMER', current_setting('t.vb')::uuid,
            jsonb_build_object('lot_id', (select id from public.stock_lots where lot_code = 'L1'))), 9), 'ERR DKG06', 'a lot of red is not moved as blue');

-- The supplier's article.
select is((pg_temp.mapping(1, null, null, 741, format('{"supplier_id": "%s", "item_id": "%s", "variant_id": "%s", "article_ref": "TX-100"}',
            pg_temp.u(401), pg_temp.u(301), current_setting('t.vr')))::jsonb ->> 'revision'), '1', 'a supplier article is mapped to an item and its variant');
select is(pg_temp.mapping(1, null, null, 742, format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "TX-100"}', pg_temp.u(401), pg_temp.u(301))),
  'ERR DKG11 {"field": "article_ref", "reason": "mapping_duplicate"}', 'the same article of one supplier is mapped once');
select is(pg_temp.mapping(1, null, null, 743, format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "TX-2", "purchase_unit": "carton"}', pg_temp.u(401), pg_temp.u(301))),
  'ERR DKG11 {"field": "purchase_unit", "reason": "unit_not_of_item"}', 'a purchase unit the item does not list is refused');
select is(pg_temp.mapping(1, null, null, 744, format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "TX-3"}', pg_temp.u(402), pg_temp.u(301))),
  'ERR DKG11 {"field": "supplier_id", "reason": "supplier_foreign"}', 'a supplier of another business is refused');
select is(pg_temp.mapping(1, null, null, 745, format('{"supplier_id": "%s", "item_id": "%s", "variant_id": "%s", "article_ref": "TX-4"}', pg_temp.u(401), pg_temp.u(302), current_setting('t.vr'))),
  'ERR DKG11 {"field": "variant_id", "reason": "variant_unknown"}', 'the variant of another item is refused');
update public.suppliers set name = 'Textiles Nord SARL' where id = pg_temp.u(401);
select is((select article_ref || ' ' || supplier_id::text from public.supplier_item_mappings where article_ref = 'TX-100'), 'TX-100 ' || pg_temp.u(401)::text,
  'the mapping survives the supplier''s display name');

-- Guards and idempotence.
select is(pg_temp.dim(1, current_setting('t.colour')::uuid, 1, 751, '{"name": "Colour"}'), 'ERR DKG10 ', 'a stale dimension revision changes nothing');
select is(pg_temp.variants(1, 301, 1, 752, '[]'), 'ERR DKG10 ', 'a stale item revision changes no variant');
update public.workspaces set role_permissions = '{"member": ["viewStock"]}' where id = pg_temp.u(101);
select is(pg_temp.dim(2, null, null, 761, '{"name": "Fit"}') like 'ERR DKN01%'
          and pg_temp.variants(2, 301, 3, 762, '[]') like 'ERR DKN01%'
          and pg_temp.mapping(2, null, null, 763, '{}') like 'ERR DKN01%', true, 'a member who only sees the stock writes none of them');
select is(pg_temp.variants(1, 301, 3, 765, '[]', 101, true) like 'ERR DKN01%', true, 'a delegated assistant session writes nothing');
select pg_temp.dim(1, null, null, 771, '{"name": "Fit"}');
select is(pg_temp.dim(1, null, null, 771, '{"name": "Fit"}') like '%"replayed": true%' and pg_temp.dim(1, null, null, 771, '{"name": "Fit2"}') like 'ERR DKG07%', true,
  'a repeated request answers replayed, another body with its id is refused');


-- An item with active variants is never taken, moved or counted without one.
select is(left(pg_temp.move(821, 301, 1::numeric, 'MAIN', 'CUSTOMER', null::uuid), 9), 'ERR DKG12', 'a move of an item with variants names its variant');
select pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, 1)::text', pg_temp.u(101), pg_temp.u(201), pg_temp.u(301)));
select is(pg_temp.try(format($q$update public.events set status = 'confirmed' where workspace_id = %L and type = 'service_charge' and status <> 'confirmed'$q$, pg_temp.u(101)))
          || ' ' || (select count(*) from public.stock_movements where item_id = pg_temp.u(301) and reason = 'sale')::text,
  'DKG12 0', 'confirming a sale of an item with variants and no plain stock is refused and nothing moves');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.allow_negative', 'true'::jsonb);
select is(pg_temp.try(format($q$update public.events set status = 'confirmed' where workspace_id = %L and type = 'service_charge' and status <> 'confirmed'$q$, pg_temp.u(101)))
          || ' ' || (select count(*) from public.stock_balances where item_id = pg_temp.u(301) and location_id = pg_temp.loc('MAIN') and quantity < 0)::text,
  'DKG12 0', 'with allow_negative on it is still refused, never minus one');
delete from public.setting_values where key = 'stock.allow_negative' and workspace_id = pg_temp.u(101);
select is(pg_temp.try(format('update public.services set stock = 40 where id = %L', pg_temp.u(301))), 'DKG13', 'a shelf-count edit is refused: the ledger keeps the stock (and an item with variants keeps its count per variant)');
select is(pg_temp.on_hand(null::uuid)::text, '0', 'no plain stock was created by any of it');

-- Deactivating a variant that has stock, and activating variants over plain stock.
select is(pg_temp.variants(1, 301, (select stock_revision from public.services where id = pg_temp.u(301)), 831,
            format('[{"id": "%s", "values": {"%s": "%s", "%s": "%s"}, "price_cents": 2600}]', current_setting('t.vr'), current_setting('t.colour'), current_setting('t.red'), current_setting('t.size'), current_setting('t.m'))),
  'ERR DKG11 {"field": "variants", "reason": "variant_has_stock"}', 'a variant with stock is not deactivated by leaving it out');
select pg_temp.move(832, 302, 2::numeric, 'SUPPLIER', 'MAIN', null::uuid);
select is(pg_temp.variants(1, 302, (select stock_revision from public.services where id = pg_temp.u(302)), 833, format('[{"values": {"%s": "%s"}}]', current_setting('t.colour'), current_setting('t.red'))),
  'ERR DKG11 {"field": "variants", "reason": "stock_without_variant"}', 'variants are not added to an item that holds stock without one');

-- A unit a supplier mapping names is not removed; the others change in place.
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(301),
            (select stock_revision from public.services where id = pg_temp.u(301)), pg_temp.u(841), '{"units": [{"unit": "box", "factor_num": 12, "factor_den": 1}]}'))::jsonb ->> 'replayed', 'false',
  'a package unit is added');
select pg_temp.mapping(1, null, null, 842, format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "TX-BOX", "purchase_unit": "box"}', pg_temp.u(401), pg_temp.u(301)));
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(301),
            (select stock_revision from public.services where id = pg_temp.u(301)), pg_temp.u(843), '{"units": []}')),
  'ERR DKG11 {"field": "units", "reason": "unit_in_use"}', 'removing a unit a supplier mapping names is refused with its field');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(301),
            (select stock_revision from public.services where id = pg_temp.u(301)), pg_temp.u(844), '{"units": [{"unit": "box", "factor_num": 24, "factor_den": 1, "default_purchase": true}]}'))::jsonb ->> 'replayed', 'false',
  'a unit is changed in place under its mapping');

-- A value label cannot collide with one left out of the list.
select is(pg_temp.dim(1, current_setting('t.colour')::uuid, (select revision from public.item_dimensions where id = current_setting('t.colour')::uuid), 851,
            format('{"values": [{"id": "%s", "label": "Blue"}, {"label": "Red"}]}', current_setting('t.blue'))),
  'ERR DKG11 {"field": "values[1].label", "reason": "name_duplicate"}', 'a new value cannot take the label of a value left out of the list');

-- The variant is returned by the plain on-hand read too.
select is((select count(*) from jsonb_array_elements(pg_temp.run_as(pg_temp.u(1), format('select public.stock_on_hand_v1(%L)::text', pg_temp.u(101)))::jsonb) x
            where x ->> 'variant_label' = 'Colour: Red · Size: M')::int, 2, 'stock_on_hand_v1 names the variant of each row (red: plain and the lot)');

-- The ledger without a variant is what it was: a movement of an unvaried item has none.
select is((select count(*) from public.stock_movements where item_id = pg_temp.u(302) and variant_id is not null)::int, 0,
  'an item without variants keeps variant_id null (the released 410 test runs unchanged on this migration)');

-- The item row is locked before the quantity is computed, so the factor that computed it is the one frozen.
select ok(regexp_replace(pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure), '\s+', ' ', 'g') like '%order by id for update%',
  'the item rows are locked (in id order) before any quantity is converted');

select * from finish();
rollback;
