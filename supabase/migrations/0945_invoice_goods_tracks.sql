-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new table, one internal function; two functions patched at asserted anchors)
--
-- #4436 (G21, the invoice half) -- a goods line of an issued invoice names the track IDs of what it took: the lot code
-- as received (else the lot's label code) with the quantity taken from it, and the tag code of each piece. The counter
-- freezes them in the receipt's own lines (0939); an issued invoice is immutable (`invoices_immutable`), and its sale
-- movements are written after the invoice row exists (they link to it), so the tracks cannot go into the invoice's
-- lines. They are frozen in a table of their own instead, in the issue's own transaction:
--
--   * `invoice_line_tracks` -- one row per goods line of an invoice that took something traced: the invoice, the line's
--     stable id (`commercial.line_id`, the id the sale movements name as `invoice_line_id`, 0941), and the tracks as
--     `stock_tracks_of` (0939) answers them. A row is never edited or deleted (a later change of a lot code or a tag
--     never alters an issued document; the cascade of a business's own deletion passes). A line that took nothing
--     traced has no row. Whoever may read the invoice reads its tracks (the invoice's own row security decides).
--   * `invoice_goods_tracks_freeze` writes the rows from the movements of the invoice, called by
--     `standalone_invoice_goods_post` (0942) after the last line is posted -- the standalone issue and the quote's
--     conversion both reach it. A replay of the issue writes nothing twice (unique on the invoice and the line).
--   * `export_workspace_records` (0937) carries the table: the finances' to export.
--
-- patches 0942 (standalone_invoice_goods_post) and 0937 (export_workspace_records), each at an asserted anchor

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0945: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. the frozen tracks of a goods line ────────────────────────────────
create table public.invoice_line_tracks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id),
  line_id text not null check (char_length(line_id) between 1 and 80),
  tracks jsonb not null check (jsonb_typeof(tracks) = 'array' and jsonb_array_length(tracks) between 1 and 500),
  unique (invoice_id, line_id)
);
select public.ensure_system_columns('invoice_line_tracks');
create index invoice_line_tracks_workspace on public.invoice_line_tracks (workspace_id);

create or replace function public.invoice_line_tracks_frozen_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'the track IDs of an issued invoice are never edited or deleted' using errcode = 'P0001';
end;
$fn$;
revoke execute on function public.invoice_line_tracks_frozen_guard() from public, anon, authenticated;
create trigger invoice_line_tracks_frozen before update or delete on public.invoice_line_tracks
  for each row execute function public.invoice_line_tracks_frozen_guard();

alter table public.invoice_line_tracks enable row level security;
revoke all on public.invoice_line_tracks from public, anon, authenticated;
grant select on public.invoice_line_tracks to authenticated;
-- whoever may read the invoice reads its tracks: the subselect runs under the invoice's own policy
create policy invoice_line_tracks_select on public.invoice_line_tracks for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id));
create policy mcp_delegated_deny on public.invoice_line_tracks as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- the tracks of each goods line of an invoice, from the sale movements that name the line
create or replace function public.invoice_goods_tracks_freeze(p_workspace_id uuid, p_invoice_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  r record;
  v_tracks jsonb;
  v_count integer := 0;
begin
  for r in
    select m.invoice_line_id::text line_id, array_agg(m.id order by m.created_datetime, m.id) movements
      from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.invoice_id = p_invoice_id
       and m.reason = 'sale' and m.invoice_line_id is not null
     group by m.invoice_line_id
  loop
    v_tracks := public.stock_tracks_of(p_workspace_id, r.movements);
    continue when jsonb_array_length(v_tracks) = 0;
    insert into public.invoice_line_tracks (workspace_id, invoice_id, line_id, tracks)
    values (p_workspace_id, p_invoice_id, r.line_id, v_tracks)
    on conflict (invoice_id, line_id) do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end
$fn$;
revoke execute on function public.invoice_goods_tracks_freeze(uuid, uuid) from public, anon, authenticated;

-- ── 2. the issue freezes them ───────────────────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.standalone_invoice_goods_post(uuid, uuid, uuid)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'  perform set_config(''deskilo.invoice_links'', ''off'', true);\n  return v_count;',
    E'  perform set_config(''deskilo.invoice_links'', ''off'', true);\n'
    || E'  -- #4436: what the lines took is frozen with the invoice\n'
    || E'  perform public.invoice_goods_tracks_freeze(p_workspace_id, p_invoice_id);\n  return v_count;',
    'the end of the goods posting');
  execute v_def;
end
$patch$;

-- ── 3. the export carries the table ─────────────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.export_workspace_records(uuid)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'''service_fulfilment_invoice_links'']',
    E'''service_fulfilment_invoice_links'',\n    -- #4436 the track IDs frozen on the goods lines of an issued invoice\n    ''invoice_line_tracks'']',
    'the end of the exported tables');
  v_def := pg_temp.anchor_once(v_def,
    E'''counter_offline_sales'') and not public.has_permission',
    E'''counter_offline_sales'', ''invoice_line_tracks'') and not public.has_permission',
    'the finances'' tables');
  execute v_def;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(945);
