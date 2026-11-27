-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (two columns with their checks, two new functions; stock_take_out gains a defaulted parameter, so a call with the old
-- arguments still answers; stock_record and stock_movements_page_v1 restated whole from their live definitions)
--
-- #4492 (row 11, D3) -- a loss says why. Goods written off left under the one reason "loss": expired, damaged and
-- missing goods were one, and no report could tell waste from theft. Now:
--
--   * A loss carries a CAUSE from a fixed list -- expired, damaged, spoiled, missing, other -- and may carry a note.
--     Both are kept on the movement (`stock_movements.loss_cause`, `loss_note`), written once with it: a movement is
--     never edited. `stock_reasons` stays the list of the KINDS of movement; the cause is a fact of a loss. Goods the
--     business uses itself are not a loss: they leave as the kind `consumption` (stock_consume_v1), as before.
--   * `stock_loss_v2` is the loss command with its cause: a missing cause, one that is not on the list or a note
--     longer than 500 characters is refused (DKG11, the field and the reason) and nothing moves.
--   * `stock_movements_page_v1` answers the cause and the note with each movement that has them; every other row is
--     the row it was.
--
-- An app of the last release goes on working: it calls stock_loss_v1, which writes a loss off as before, without a
-- cause. A loss recorded before this file, or by such an app, has no cause; nothing is guessed for it.

-- audience: all row readers
alter table public.stock_movements add column if not exists loss_cause text;
alter table public.stock_movements add column if not exists loss_note text;
comment on column public.stock_movements.loss_cause is
  'Why the goods of a loss were lost: expired, damaged, spoiled, missing, other. Null on every other movement and on a loss recorded without one.';
comment on column public.stock_movements.loss_note is 'What the person wrote beside the cause of a loss; null without one.';

-- the causes a loss may name: the one list, read by the command and by the table
create or replace function public.stock_loss_cause_ok(p_cause text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_cause in ('expired', 'damaged', 'spoiled', 'missing', 'other')
$fn$;
revoke execute on function public.stock_loss_cause_ok(text) from public, anon, authenticated;

alter table public.stock_movements drop constraint if exists stock_movements_loss_cause_check;
alter table public.stock_movements add constraint stock_movements_loss_cause_check
  check (loss_cause is null or (reason = 'loss' and public.stock_loss_cause_ok(loss_cause))) not valid;
alter table public.stock_movements validate constraint stock_movements_loss_cause_check;
alter table public.stock_movements drop constraint if exists stock_movements_loss_note_check;
alter table public.stock_movements add constraint stock_movements_loss_note_check
  check (loss_note is null or (loss_cause is not null and char_length(loss_note) between 1 and 500)) not valid;
alter table public.stock_movements validate constraint stock_movements_loss_note_check;

-- ── the one writer writes them ───────────────────────────────────────────────────────────────────────────────────────────
-- the live definition (0837 as patched since: the replay's body, digest 1eebb71866fb in the contract), with the two
-- facts of a loss read from the links the loss command passes
-- restates 0837
create or replace function public.stock_record(
  p_workspace_id uuid, p_item_id uuid, p_lot_id uuid, p_from uuid, p_to uuid, p_quantity numeric, p_entered_unit text,
  p_entered_quantity numeric, p_occurred_at timestamptz, p_reason text, p_actor uuid, p_request_id uuid, p_line_no int,
  p_part int, p_links jsonb, p_variant_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_cost numeric;
  v_num bigint;
  v_den bigint;
begin
  if p_lot_id is not null then
    select total_cost_minor::numeric / quantity_received into v_cost
      from public.stock_lots where id = p_lot_id and cost_state = 'known';
  end if;
  select f.num, f.den into v_num, v_den from public.stock_unit_factor(p_item_id, p_entered_unit) f;
  insert into public.stock_movements
    (workspace_id, item_id, variant_id, lot_id, from_location_id, to_location_id, quantity,
     entered_unit, entered_quantity, occurred_at, reason, unit_cost, actor_member_id,
     request_id, line_no, part, receipt_line_id, purchase_line_id, event_id, invoice_id, counter_receipt_id, counter_line_id, invoice_line_id,
     entered_factor_num, entered_factor_den, loss_cause, loss_note)
  values
    (p_workspace_id, p_item_id, p_variant_id, p_lot_id, p_from, p_to, p_quantity,
     p_entered_unit, p_entered_quantity, p_occurred_at, p_reason, v_cost, p_actor,
     p_request_id, p_line_no, p_part,
     nullif(p_links ->> 'receipt_line_id', '')::uuid, nullif(p_links ->> 'purchase_line_id', '')::uuid,
     nullif(p_links ->> 'event_id', '')::uuid, nullif(p_links ->> 'invoice_id', '')::uuid, nullif(p_links ->> 'counter_receipt_id', '')::uuid, nullif(p_links ->> 'counter_line_id', '')::uuid, nullif(p_links ->> 'invoice_line_id', '')::uuid,
     v_num, v_den,
     -- why the goods were lost, and the note beside it: facts of a loss, written by the loss command alone
     case when p_reason = 'loss' then nullif(p_links ->> 'loss_cause', '') end,
     case when p_reason = 'loss' then nullif(p_links ->> 'loss_note', '') end)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb, uuid) from public, anon, authenticated;

-- ── goods taken out, with the facts of the act ───────────────────────────────────────────────────────────────────────────
-- the live definition (digest 073e036ff9f3), with one parameter more: the facts the movements keep (a loss's cause and
-- note). Without them it does what it did. The five minutes a command may be ahead of the clock are the same five,
-- written without a literal interval.
drop function if exists public.stock_take_out(uuid, uuid, jsonb, text, timestamptz);
-- restates 0847
create or replace function public.stock_take_out(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_reason text, p_occurred_at timestamptz,
  p_facts jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_at timestamptz := coalesce(p_occurred_at, now());
  v_loss uuid := public.stock_place(p_workspace_id, 'loss');
  v_lines jsonb;
begin
  if not public.feature_effective(p_workspace_id, 'stockTakeOut') then
    raise exception 'taking goods out is off in this business' using errcode = 'DKG01';
  end if;
  perform public.stock_command_args(p_request_id, p_lines);
  if v_at > now() + make_interval(mins => 5) then raise exception 'a command is not in the future' using errcode = 'DKG07'; end if;
  -- the facts are part of what was asked; without any the digest is the one it always was, so a request sent
  -- before this file answers the same after it
  v_digest := md5(p_reason || '|' || coalesce(p_occurred_at::text, '') || '|' || p_lines::text
                  || case when coalesce(p_facts, '{}'::jsonb) <> '{}'::jsonb then '|' || p_facts::text else '' end);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_' || p_reason, v_digest);
  if v_done is not null then return v_done; end if;
  select jsonb_agg(l || jsonb_build_object('to', v_loss)) into v_lines from jsonb_array_elements(p_lines) l;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_' || p_reason, v_digest,
    jsonb_build_object('request_id', p_request_id, 'movements',
      public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_lines, p_reason, v_at, coalesce(p_facts, '{}'::jsonb), 'take_out')));
end;
$fn$;
revoke execute on function public.stock_take_out(uuid, uuid, jsonb, text, timestamptz, jsonb) from public, anon, authenticated;

-- ── the loss command with its cause ──────────────────────────────────────────────────────────────────────────────────────
create or replace function public.stock_loss_v2(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_cause text, p_note text default null,
  p_occurred_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_cause text := nullif(btrim(coalesce(p_cause, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  perform public.stock_ops_actor(p_workspace_id);
  if v_cause is null then
    perform public.stock_config_refuse('cause', 'required');
  end if;
  if not public.stock_loss_cause_ok(v_cause) then
    perform public.stock_config_refuse('cause', 'malformed');
  end if;
  if char_length(v_note) > 500 then
    perform public.stock_config_refuse('note', 'too_long');
  end if;
  return public.stock_take_out(p_workspace_id, p_request_id, p_lines, 'loss', p_occurred_at,
    jsonb_strip_nulls(jsonb_build_object('loss_cause', v_cause, 'loss_note', v_note)));
end;
$fn$;
revoke execute on function public.stock_loss_v2(uuid, uuid, jsonb, text, text, timestamptz) from public, anon;
grant execute on function public.stock_loss_v2(uuid, uuid, jsonb, text, text, timestamptz) to authenticated;

-- ── the ledger reads them ────────────────────────────────────────────────────────────────────────────────────────────────
-- the live definition (digest 97db76dce2dc), each movement with the cause and the note of its loss. Its cursor check
-- handles the malformed value by name (a date or an id that is none) where it handled every exception: the refusal is
-- the same DKG09.
-- restates 0837
create or replace function public.stock_movements_page_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null, p_limit int default 50,
  p_after jsonb default null, p_movement_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_at timestamptz; v_id uuid;
  v_rows jsonb; v_n int; v_last jsonb; v_cost boolean;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  v_cost := public.stock_sees_cost(p_workspace_id);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_at := (p_after->>'occurred_at')::timestamptz;
      v_id := (p_after->>'id')::uuid;
      if v_at is null or v_id is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    -- a cursor whose date or id is no date or id: the one thing these two casts can raise
    exception when data_exception then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with page as (
    select m.id, m.item_id, m.variant_id, s.name as item_name, s.inventory_unit as unit, m.lot_id, t.lot_code,
           m.from_location_id, lf.code as from_code, m.to_location_id, lt.code as to_code,
           m.quantity, m.entered_quantity, m.entered_unit, m.occurred_at, m.reason, m.unit_cost,
           m.actor_member_id, m.receipt_line_id, m.purchase_line_id, m.event_id, m.invoice_id, m.loss_cause, m.loss_note
      from public.stock_movements m
      join public.services s on s.id = m.item_id
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_locations lt on lt.id = m.to_location_id
      left join public.stock_lots t on t.id = m.lot_id
     where m.workspace_id = p_workspace_id
       and (p_movement_id is null or m.id = p_movement_id)
       and (p_item_id is null or m.item_id = p_item_id)
       and (p_location_id is null or p_location_id in (m.from_location_id, m.to_location_id))
       and (p_after is null or (m.occurred_at, m.id) < (v_at, v_id))
     order by m.occurred_at desc, m.id desc
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'workspace_id', p_workspace_id, 'id', id, 'item_id', item_id, 'item_name', item_name,
           'variant_id', variant_id, 'variant_label', public.stock_variant_label(variant_id),
           'lot_id', lot_id, 'lot_code', lot_code,
           'from_location_id', from_location_id, 'from_location_code', from_code,
           'to_location_id', to_location_id, 'to_location_code', to_code,
           'quantity', quantity::text, 'unit', unit,
           'entered_quantity', entered_quantity::text, 'entered_unit', entered_unit,
           'occurred_at', occurred_at, 'reason', reason,
           'unit_cost', case when v_cost then unit_cost::text end, 'actor_member_id', actor_member_id,
           'receipt_line_id', case when v_cost then receipt_line_id end,
           'purchase_line_id', case when v_cost then purchase_line_id end,
           'event_id', event_id, 'invoice_id', invoice_id)
           -- the cause and the note of a loss, on the movements that have them: a row without them is the row it was
           || jsonb_strip_nulls(jsonb_build_object('loss_cause', loss_cause, 'loss_note', loss_note))
           order by occurred_at desc, id desc), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'occurred_at', v_last -> 'occurred_at', 'id', v_last -> 'id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) from public, anon;
grant execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(981);
