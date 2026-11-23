-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (one nullable column and its key on the stock movements; two functions patched at asserted anchors)
--
-- #4185 (S4) -- goods sold at the counter leave through the one stock path, linked to the receipt.
--
--   * A movement of the ledger may name the counter receipt that caused it (`counter_receipt_id`, a composite key to
--     the receipt of the same business): history names its cause and outlives it, as it does for an invoice or an
--     event. `stock_record` writes it; `stock_apply_lines` accepts it as the link a sale needs (a sale names an event,
--     an invoice or a counter receipt) and as the link a return from the customer needs.
--   * Issuing a receipt does not move goods by itself: the finalize of 0894 asks the one stock path for its goods lines
--     in its own transaction, under its own request id, so a replay moves nothing twice and a line that cannot leave
--     rolls the sale back; a correction (a credit document) moves nothing; a physical return is its own command (0897).

-- audience: all row readers
alter table public.stock_movements add column counter_receipt_id uuid;
-- audience: all row readers
alter table public.stock_movements add column counter_line_id uuid;
alter table public.stock_movements add constraint stock_movements_counter_receipt_fkey
  foreign key (workspace_id, counter_receipt_id) references public.counter_receipts (workspace_id, id);
alter table public.stock_movements add constraint stock_movements_counter_line_fkey
  foreign key (workspace_id, counter_line_id) references public.counter_receipt_lines (workspace_id, id);
create index stock_movements_counter_receipt on public.stock_movements (counter_receipt_id) where counter_receipt_id is not null;


-- the number of times p_old occurs in p_def
create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
revoke execute on function pg_temp.occurrences(text, text) from public;

-- restates 0836
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamp with time zone, text, uuid, uuid, int, int, jsonb, uuid)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'event_id, invoice_id,\n     entered_factor_num',
    E'nullif(p_links ->> \'invoice_id\', \'\')::uuid,\n     v_num, v_den)'];
  v_news text[] := array[
    E'event_id, invoice_id, counter_receipt_id, counter_line_id,\n     entered_factor_num',
    E'nullif(p_links ->> \'invoice_id\', \'\')::uuid, nullif(p_links ->> \'counter_receipt_id\', \'\')::uuid, nullif(p_links ->> \'counter_line_id\', \'\')::uuid,\n     v_num, v_den)'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0896: anchor % not found exactly once in stock_record', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

-- restates 0889
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'(p_links ? \'event_id\' or p_links ? \'invoice_id\')',
    E'v_from.kind = \'customer\' and not v_tv and p_links ? \'invoice_id\'',
    E'then jsonb_build_object(\'receipt_line_id\', e ->> \'receipt_line_id\') else \'{}\'::jsonb end;'];
  v_news text[] := array[
    E'(p_links ? \'event_id\' or p_links ? \'invoice_id\' or p_links ? \'counter_receipt_id\')',
    E'v_from.kind = \'customer\' and not v_tv and (p_links ? \'invoice_id\' or p_links ? \'counter_receipt_id\')',
    E'then jsonb_build_object(\'receipt_line_id\', e ->> \'receipt_line_id\') else \'{}\'::jsonb end\n      || case when nullif(e ->> \'counter_line_id\', \'\') is not null then jsonb_build_object(\'counter_line_id\', e ->> \'counter_line_id\') else \'{}\'::jsonb end;'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0896: anchor % not found exactly once in stock_apply_lines', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(896);
