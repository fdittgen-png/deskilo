-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4479 -- an item group carries the unit its items are SOLD in, as it carries the one they are bought in: a sale unit, what one of it makes
-- of the inventory unit, and its price. Like the purchase unit these are PROPOSALS: copied into a new item of the group as its starting
-- point, never inherited and never linked, so a change of one reaches no item.
--   * `item_groups.default_sale_unit`, `default_sale_factor_num/den` (both or none), `default_sale_price_cents` (0..2e9, in the minor
--     units of the items' prices; empty: the item's price times the factor, `item_unit_price` 0974).
--   * the catalogue of parameters (`item_group_param_kind`, `item_group_params`) names the four as proposals; `item_group_check_value`
--     refuses a sale unit that is not one of the business's units (`unit_unknown`) and a price that is not a whole number of minor units
--     (`price_invalid`); `item_group_save_core` stores them.
-- Anchored patches of the live definitions (0883, patched by 0952 and 0961), each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0975: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- audience: all row readers (a group's sale unit is as readable as its purchase unit)
alter table public.item_groups
  add column default_sale_unit text check (char_length(btrim(default_sale_unit)) between 1 and 30),
  add column default_sale_factor_num bigint check (default_sale_factor_num > 0),
  add column default_sale_factor_den bigint check (default_sale_factor_den > 0),
  add column default_sale_price_cents bigint check (default_sale_price_cents between 0 and 2000000000),
  add constraint item_groups_sale_factor_pair check ((default_sale_factor_num is null) = (default_sale_factor_den is null));

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.item_group_param_kind(text)'::regprocedure) into v_def;
  if position('default_sale_unit' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'''home_zone_id'') then ''proposal''',
      E'''home_zone_id'', ''default_sale_unit'', ''default_sale_factor_num'', ''default_sale_factor_den'',\n                     ''default_sale_price_cents'') then ''proposal''', 'the proposals');
    execute v_def;
  end if;

  select pg_get_functiondef('public.item_group_params()'::regprocedure) into v_def;
  if position('default_sale_unit' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'''home_zone_id''];',
      E'''home_zone_id'', ''default_sale_unit'', ''default_sale_factor_num'', ''default_sale_factor_den'',\n               ''default_sale_price_cents''];', 'the parameters');
    execute v_def;
  end if;

  select pg_get_functiondef('public.item_group_check_value(uuid,text,jsonb)'::regprocedure) into v_def;
  if position('default_sale_unit' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'  elsif p_param = ''vat_rate_id'' and not exists (',
      E'  elsif p_param = ''default_sale_unit'' and not exists (\n' ||
      E'      select 1 from public.workspace_units u where u.workspace_id = p_workspace_id and u.code = p_value #>> ''{}'') then\n' ||
      E'    perform public.stock_config_refuse(p_param, ''unit_unknown'');\n' ||
      E'  elsif p_param = ''default_sale_price_cents'' and ((p_value #>> ''{}'') !~ ''^[0-9]{1,10}$'' or (p_value #>> ''{}'')::bigint > 2000000000) then\n' ||
      E'    perform public.stock_config_refuse(p_param, ''price_invalid'');\n' ||
      E'  elsif p_param = ''vat_rate_id'' and not exists (', 'the value checks');
    execute v_def;
  end if;

  select pg_get_functiondef('public.item_group_save_core(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,boolean)'::regprocedure) into v_def;
  if position('default_sale_unit' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'        deposit_item_id, deposit_minor, label_template)\n      values (',
      E'        deposit_item_id, deposit_minor, label_template, default_sale_unit, default_sale_factor_num, default_sale_factor_den,\n        default_sale_price_cents)\n      values (', 'the insert columns');
    v_def := pg_temp.anchor_once(v_def, E'        v_new.deposit_minor, v_new.label_template);',
      E'        v_new.deposit_minor, v_new.label_template, v_new.default_sale_unit, v_new.default_sale_factor_num, v_new.default_sale_factor_den,\n        v_new.default_sale_price_cents);', 'the insert values');
    v_def := pg_temp.anchor_once(v_def, E'deposit_minor = v_new.deposit_minor, label_template = v_new.label_template\n       where id = v_new.id;',
      E'deposit_minor = v_new.deposit_minor, label_template = v_new.label_template,\n        default_sale_unit = v_new.default_sale_unit, default_sale_factor_num = v_new.default_sale_factor_num,\n        default_sale_factor_den = v_new.default_sale_factor_den, default_sale_price_cents = v_new.default_sale_price_cents\n       where id = v_new.id;', 'the update');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(975);
