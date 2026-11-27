-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4492 (row 4) -- a posted row holds against the server's own role as it holds against a client.
-- `scripts/posted_documents_check.sh` tried every write on the rows the database tests post, as the owner, as a
-- delegated session and as the server's role (the Edge functions, an import). The first two change nothing; the
-- third is restrained by the guards alone, and five of its writes got through. Each is closed here; none of them
-- is reachable with a person's or an assistant's session, and no command of the app makes any of them.
--   * the SITE of a posted row. The guards compare a row without the system columns, and `site_id` is one of
--     them: on a ledger entry, a tender and a kept Verifactu record it could be rewritten. `posted_site_kept()`
--     refuses a change of it there. (An invoice keeps its own rule: its site is set once, while empty, 0770.)
--   * a recorded ORIGINAL of an invoice was guarded on UPDATE only: `invoice_originals_kept()` refuses its
--     deletion. It goes only with its invoice or its business (the cascade of their own deletion).
--   * a LINE of a finalized receipt handed to another receipt: `counter_frozen_guard()` read the state of the
--     receipt the line was given TO. It reads both now.
--   * the PIECES and the HANDLING UNITS a stock movement carried had no guard of their own:
--     `stock_movement_details_append_only()` refuses their edit and their deletion, as the movement's own guard
--     does (DKG08), until the business itself is deleted.
--   * a posted table EMPTIED in one statement: the row guards never see a TRUNCATE. `posted_rows_no_truncate()`
--     refuses it on every table of posted documents while the table holds a row; an empty one may be emptied
--     (a restore into a new installation truncates before it loads).
-- Existing rows are not read: nothing here can make the upgrade fail on what an installation holds. The codes
-- are the guards' own (DKL03, DKG08): a person never meets them.

-- ── a line of a finalized receipt stays with its receipt ──────────────────────────────────────────────────────
-- restates 0893: the live definition, the lines' branch reads the receipt the line leaves as well as the one it joins
create or replace function public.counter_frozen_guard()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_sys text[] := public.system_column_names();
  v_old jsonb;
  v_new jsonb;
begin
  -- only the cascade of a business's own deletion is let through: a DELETE run by the key's action while the business
  -- row is already gone. An update is refused at every depth, and a delete of a row of a business that still exists is
  -- an edit. (Deleting a business deletes what is its own; what must be kept for a retention period is the operator's
  -- decision before the deletion, as for the other records of the business.)
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  if tg_table_name = 'counter_receipts' then
    if tg_op = 'DELETE' then
      if old.state = 'finalized' then
        raise exception 'a finalized receipt is never deleted' using errcode = 'DKL03';
      end if;
      return old;
    end if;
    if old.state = 'finalized' then
      raise exception 'a finalized receipt is never edited: a correction is a new receipt' using errcode = 'DKL03';
    end if;
    return new;
  elsif tg_table_name = 'counter_receipt_lines' then
    -- the receipt the line belongs to and, on an update, the one it would join: neither is finalized
    if exists (select 1 from public.counter_receipts r
                where r.state = 'finalized'
                  and (r.id = old.receipt_id or (tg_op = 'UPDATE' and r.id = new.receipt_id))) then
      raise exception 'the lines of a finalized receipt are never edited' using errcode = 'DKL03';
    end if;
    return coalesce(new, old);
  else
    if tg_op = 'DELETE' then
      raise exception 'a tender is never deleted' using errcode = 'DKL03';
    end if;
    v_old := to_jsonb(old) - v_sys - array['state', 'provider_ref', 'reconciliation', 'resolved_at', 'resolved_by_member_id'];
    v_new := to_jsonb(new) - v_sys - array['state', 'provider_ref', 'reconciliation', 'resolved_at', 'resolved_by_member_id'];
    if v_old is distinct from v_new then
      raise exception 'what a tender is for and how much is never edited' using errcode = 'DKL03';
    end if;
    return new;
  end if;
end;
$fn$;
revoke execute on function public.counter_frozen_guard() from public, anon, authenticated;

-- ── the site of a posted row ──────────────────────────────────────────────────────────────────────────────────
-- Fires before `zz_system_columns_stamp` (by name), so it reads the site the statement itself wrote.
create function public.posted_site_kept()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'the site of a posted row never changes' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.posted_site_kept() from public, anon, authenticated;

create trigger posted_site_kept before update on public.ledger_entries
  for each row when (old.site_id is distinct from new.site_id) execute function public.posted_site_kept();
create trigger posted_site_kept before update on public.counter_tenders
  for each row when (old.site_id is distinct from new.site_id) execute function public.posted_site_kept();
create trigger posted_site_kept before update on public.verifactu_records
  for each row when (old.site_id is distinct from new.site_id) execute function public.posted_site_kept();

-- ── a recorded original is never deleted ──────────────────────────────────────────────────────────────────────
create function public.invoice_originals_kept()
returns trigger language plpgsql set search_path = public as $fn$
begin
  -- it leaves only with what it belongs to: the cascade of its invoice's or its business's own deletion
  if pg_trigger_depth() > 1
     and (not exists (select 1 from public.workspaces w where w.id = old.workspace_id)
          or not exists (select 1 from public.invoices i where i.id = old.invoice_id)) then
    return old;
  end if;
  raise exception 'an invoice''s original is never deleted' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.invoice_originals_kept() from public, anon, authenticated;

create trigger invoice_originals_no_delete before delete on public.invoice_originals
  for each row execute function public.invoice_originals_kept();

-- ── what a stock movement carried ─────────────────────────────────────────────────────────────────────────────
create function public.stock_movement_details_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'what a stock movement carried is never edited or deleted: a correction is a movement back'
    using errcode = 'DKG08';
end;
$fn$;
revoke execute on function public.stock_movement_details_append_only() from public, anon, authenticated;

create trigger stock_movement_units_append_only before delete or update on public.stock_movement_units
  for each row execute function public.stock_movement_details_append_only();
create trigger stock_movement_handling_units_append_only before delete or update on public.stock_movement_handling_units
  for each row execute function public.stock_movement_details_append_only();

-- ── a posted table is never emptied in one statement ──────────────────────────────────────────────────────────
-- The row guards do not fire on TRUNCATE, and 0563 took the privilege from the client roles only. A definer, so
-- that "holds a row" is answered whatever the caller may read.
create function public.posted_rows_no_truncate()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_holds boolean;
begin
  execute format('select exists (select 1 from %I.%I)', tg_table_schema, tg_table_name) into v_holds;
  if v_holds then
    raise exception 'posted documents are never emptied in one statement (%)', tg_table_name using errcode = 'DKL03';
  end if;
  return null;
end;
$fn$;
revoke execute on function public.posted_rows_no_truncate() from public, anon, authenticated;

create trigger posted_rows_no_truncate before truncate on public.invoices
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.invoice_originals
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.invoice_line_tracks
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.invoice_match_history
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.ledger_entries
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_receipts
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_receipt_lines
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_tenders
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_refunds
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_receipt_copies
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_cash_entries
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_till_sessions
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_day_closes
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.counter_offline_sales
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.stock_movements
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.stock_movement_units
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.stock_movement_handling_units
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.stock_returns
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.stock_reversals
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.verifactu_records
  for each statement execute function public.posted_rows_no_truncate();
create trigger posted_rows_no_truncate before truncate on public.vat_return_entries
  for each statement execute function public.posted_rows_no_truncate();

select public.set_deskilo_schema_version(977);
