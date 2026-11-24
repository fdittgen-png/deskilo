-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one nullable column and its index on the stock movements; one setting; two functions patched at asserted anchors)
--
-- #4433 (G18b, first of two files) -- the stock side of goods sold on an invoice.
--
--   * A movement may name the invoice LINE that caused it (`invoice_line_id`, the line's stable `line_id` of the
--     commercial facts, beside the `invoice_id` the ledger already had): a sale of goods on an invoice is traced to the
--     line it was sold on, and its return to the same line. Invoice lines live inside the invoice (`invoices.lines`), so
--     the column has no key of its own; the invoice link it sits beside does.
--   * `stock_record` writes it; `stock_apply_lines` carries it from a line (`invoice_line_id`) like the counter line,
--     and only when the invoicing commands open their own door (`deskilo.invoice_links`) and name the invoice too: the
--     generic door never names one.
--   * The setting `stock.invoice_sale_place` names, by its code, the place goods sold on an invoice leave from
--     (default `MAIN`, the main store every business has). The second file (0940) reads it.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0939: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── the link ─────────────────────────────────────────────────────────────
-- audience: all row readers
alter table public.stock_movements add column invoice_line_id uuid;
comment on column public.stock_movements.invoice_line_id is
  '#4433 -- the line (commercial line_id) of the invoice a sale or a return of goods was made for; set with invoice_id only';
create index stock_movements_invoice on public.stock_movements (invoice_id, invoice_line_id) where invoice_id is not null;

-- ── the setting ──────────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.invoice_sale_place', 'text', '"MAIN"'::jsonb, null, 40, 'place code', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'goods on invoices (#4433)', 'The code of the place goods sold on an invoice leave from, for example MAIN (the main store) or the code of a shop floor. It must be a place of the business that holds stock and is in use; otherwise an invoice with goods lines is refused until it is corrected.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the one writer writes it ─────────────────────────────────────────────
-- restates 0896 (stock_record, as patched by 0896), by anchored patch
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamp with time zone, text, uuid, uuid, int, int, jsonb, uuid)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'counter_receipt_id, counter_line_id,\n     entered_factor_num',
    E'counter_receipt_id, counter_line_id, invoice_line_id,\n     entered_factor_num',
    'the column list of stock_record');
  v_def := pg_temp.anchor_once(v_def,
    E'nullif(p_links ->> \'counter_line_id\', \'\')::uuid,\n     v_num, v_den)',
    E'nullif(p_links ->> \'counter_line_id\', \'\')::uuid, nullif(p_links ->> \'invoice_line_id\', \'\')::uuid,\n     v_num, v_den)',
    'the values of stock_record');
  execute v_def;
end
$patch$;

-- ── the one stock path carries it from a line ────────────────────────────
-- restates 0896 (stock_apply_lines, as patched since), by anchored patch
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamp with time zone, jsonb, text)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'then jsonb_build_object(\'counter_line_id\', e ->> \'counter_line_id\') else \'{}\'::jsonb end;\n',
    E'then jsonb_build_object(\'counter_line_id\', e ->> \'counter_line_id\') else \'{}\'::jsonb end\n'
    || E'      || case when nullif(e ->> \'invoice_line_id\', \'\') is not null then jsonb_build_object(\'invoice_line_id\', e ->> \'invoice_line_id\') else \'{}\'::jsonb end;\n'
    || E'    -- #4433: an invoice line is named by the invoicing commands only, and beside its invoice\n'
    || E'    if v_links ? \'invoice_line_id\'\n'
    || E'       and (coalesce(current_setting(\'deskilo.invoice_links\', true), \'\') <> \'on\' or not (v_links ? \'invoice_id\')) then\n'
    || E'      perform public.stock_config_refuse(format(\'lines[%s]\', v_no - 1), \'malformed\');\n'
    || E'    end if;\n',
    'the line links of stock_apply_lines');
  execute v_def;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(939);
