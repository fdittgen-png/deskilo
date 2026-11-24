-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (the sequence of an offline sale is numbered per device within a session; the price tolerance and the cash taken are checked
--  against the sale's own lines; whoever works the till may send into an open session; no stored row moves)
--
-- #4373 (review of 0937):
--  (a) two devices of one till session both number their sales from 1: the number is now unique per (session, device); a device
--      names itself in each sale (`device_id`, a uuid it keeps; absent means the one legacy device), and the gaps are reported per device;
--  (c) the price tolerance compared only a base quantity written exactly '1' and skipped a line without an item: it now compares the
--      price of one base unit whatever the base quantity is written as, and a line without an item is refused as `item`;
--  (d) the opener and the finance readers were the only senders, although any cashier sells online in the same session: whoever works
--      the till of the business may send into its OPEN session (the cash belongs to the session as an online sale's does; a closed
--      session still takes nothing);
--  (g) the cash given of a refused sale stayed in the drawer count unbounded: given minus change may not exceed what the sale's own lines
--      price to (plus the tolerance), otherwise the whole call is refused (DKL02).

alter table public.counter_offline_sales add column device_id uuid not null default '00000000-0000-0000-0000-000000000000';
alter table public.counter_offline_sales drop constraint counter_offline_sales_workspace_id_till_session_id_seq_key;
alter table public.counter_offline_sales add constraint counter_offline_sales_session_device_seq_key unique (workspace_id, till_session_id, device_id, seq);

-- what a sale's own lines price to, gross, minor units (the unit price of the line times its quantity, half up per line; a line with
-- no unit price is read at the item's price); null when a line cannot be read
create or replace function public.counter_offline_body_total(p_workspace_id uuid, p_body jsonb, p_digits int)
returns bigint language plpgsql stable security definer set search_path = public as $fn$
declare
  l jsonb;
  v_sum bigint := 0;
  v_qty numeric;
  v_unit numeric;
  v_item public.services;
begin
  if coalesce(jsonb_typeof(p_body -> 'lines'), '') <> 'array' then
    return null;
  end if;
  for l in select value from jsonb_array_elements(p_body -> 'lines') loop
    if jsonb_typeof(l) <> 'object' then
      return null;
    end if;
    begin
      v_qty := (l ->> 'quantity')::numeric;
      if v_qty is null or v_qty <= 0 then
        return null;
      end if;
      if coalesce(l ->> 'unit_price', '') <> '' then
        v_unit := (l ->> 'unit_price')::numeric * (10::numeric ^ p_digits);
      else
        select * into v_item from public.services s where s.id = (l ->> 'item_id')::uuid and s.workspace_id = p_workspace_id;
        if v_item.id is null then
          return null;
        end if;
        v_unit := v_item.price_cents;
      end if;
      v_sum := v_sum + round(v_unit * v_qty)::bigint;
    exception when invalid_text_representation or numeric_value_out_of_range then
      return null;
    end;
  end loop;
  return v_sum;
end;
$fn$;
revoke execute on function public.counter_offline_body_total(uuid, jsonb, int) from public, anon, authenticated;

-- the sequence numbers missing between the recorded ones of each of [p_devices], as one list of numbers
drop function if exists public.counter_offline_gaps(uuid);
create or replace function public.counter_offline_gaps(p_session_id uuid, p_devices uuid[])
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(distinct g.n order by g.n), '[]'::jsonb)
    from (select m.device_id, generate_series(1, m.top) as n
            from (select o.device_id, max(o.seq) as top from public.counter_offline_sales o
                   where o.till_session_id = p_session_id and o.device_id = any (p_devices) group by o.device_id) m) g
   where not exists (select 1 from public.counter_offline_sales o where o.till_session_id = p_session_id and o.device_id = g.device_id and o.seq = g.n)
$fn$;
revoke execute on function public.counter_offline_gaps(uuid, uuid[]) from public, anon, authenticated;

-- the same per device, for the list the owner reads: `{device_id, seq}` of each missing number
create or replace function public.counter_offline_gap_list(p_session_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object('device_id', g.device_id, 'seq', g.n) order by g.device_id, g.n), '[]'::jsonb)
    from (select m.device_id, generate_series(1, m.top) as n
            from (select o.device_id, max(o.seq) as top from public.counter_offline_sales o where o.till_session_id = p_session_id group by o.device_id) m) g
   where not exists (select 1 from public.counter_offline_sales o where o.till_session_id = p_session_id and o.device_id = g.device_id and o.seq = g.n)
$fn$;
revoke execute on function public.counter_offline_gap_list(uuid) from public, anon, authenticated;

-- restates 0937
create or replace function public.counter_offline_list_v1(p_workspace_id uuid, p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_sess public.counter_till_sessions;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not public.feature_effective(p_workspace_id, 'counterOfflineCash') then
    raise exception 'selling offline is off in this business' using errcode = 'DKG01';
  end if;
  select * into v_sess from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id;
  if v_sess.id is null then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  if not public.has_permission(p_workspace_id, 'viewFinances')
     and not (public.has_permission(p_workspace_id, 'issueInvoices') and v_sess.opened_by_member_id = v_me) then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  return jsonb_build_object(
    'sales', coalesce((select jsonb_agg(jsonb_build_object('device_id', o.device_id, 'seq', o.seq, 'state', o.state, 'reason', o.reason, 'receipt_id', o.receipt_id,
                'number', o.number, 'total_minor', o.total_minor, 'cash_given_minor', o.cash_given_minor, 'change_minor', o.change_minor,
                'occurred_at', o.occurred_at, 'fiscal', 'not_signed') order by o.device_id, o.seq)
                from public.counter_offline_sales o where o.till_session_id = v_sess.id), '[]'::jsonb),
    'gaps', public.counter_offline_gap_list(v_sess.id));
end;
$fn$;
revoke execute on function public.counter_offline_list_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_offline_list_v1(uuid, uuid) to authenticated;

-- restates 0937
create or replace function public.counter_offline_sync_v1(p_workspace_id uuid, p_session_id uuid, p_offline_since timestamptz, p_sales jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_sess public.counter_till_sessions;
  v_max_minutes int;
  v_max_sales int;
  v_tolerance int;
  v_digits int;
  v_cur text;
  e jsonb;
  l jsonb;
  v_seq int;
  v_req uuid;
  v_at timestamptz;
  v_given bigint;
  v_change bigint;
  v_body jsonb;
  v_digest text;
  v_old public.counter_offline_sales;
  v_reason text;
  v_draft jsonb;
  v_final jsonb;
  v_total bigint;
  v_item public.services;
  v_price numeric;
  v_results jsonb := '[]'::jsonb;
  v_accepted int := 0;
  v_refused int := 0;
  v_row public.counter_offline_sales;
  v_dev uuid;
  v_devs uuid[] := '{}';
  v_base numeric;
  v_body_total bigint;
begin
  v_me := public.counter_offline_actor(p_workspace_id);
  if p_session_id is null or p_offline_since is null or coalesce(jsonb_typeof(p_sales), '') <> 'array'
     or jsonb_array_length(p_sales) not between 1 and 200 then
    perform public.refuse('DKL02', null, 'offline_sale');
  end if;
  -- two devices of one session sync one after the other; a close (for update) waits for this transaction
  perform pg_advisory_xact_lock(hashtextextended('counter_offline:' || p_session_id::text, 0));
  select * into v_sess from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id for share;
  -- as a sale on the till is: whoever works the till of this business may send into its open session (the cash belongs to the session)
  if v_sess.id is null then
    raise exception 'not allowed to send sales for this session' using errcode = 'DKN01';
  end if;
  v_max_minutes := coalesce((public.setting_value(p_workspace_id, 'counter.offline_max_minutes') #>> '{}')::int, 240);
  v_max_sales := coalesce((public.setting_value(p_workspace_id, 'counter.offline_max_sales') #>> '{}')::int, 200);
  v_tolerance := coalesce((public.setting_value(p_workspace_id, 'counter.offline_price_tolerance_percent') #>> '{}')::int, 0);
  select upper(w.currency_code) into v_cur from public.workspaces w where w.id = p_workspace_id;
  v_digits := public.currency_minor_digits(v_cur);
  for e in select value from jsonb_array_elements(p_sales) loop
    if jsonb_typeof(e) <> 'object' or coalesce(jsonb_typeof(e -> 'body'), '') <> 'object' then
      perform public.refuse('DKL02', null, 'offline_sale');
    end if;
    begin
      v_seq := (e ->> 'seq')::int;
      v_req := (e ->> 'request_id')::uuid;
      v_at := (e ->> 'occurred_at')::timestamptz;
      v_given := (e ->> 'cash_given_minor')::bigint;
      v_change := (e ->> 'change_minor')::bigint;
      v_dev := coalesce(nullif(e ->> 'device_id', ''), '00000000-0000-0000-0000-000000000000')::uuid;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
      perform public.refuse('DKL02', null, 'offline_sale');
    end;
    if v_seq is null or v_seq < 1 or v_req is null or v_at is null or v_given is null or v_given < 0 or v_change is null
       or v_change < 0 or v_change > v_given then
      perform public.refuse('DKL02', null, 'offline_sale');
    end if;
    v_body := e -> 'body';
    v_digest := md5(p_session_id::text || '|' || v_seq || '|' || v_req || '|' || v_at::text || '|' || v_given || '|' || v_change || '|' || v_body::text
                      || case when v_dev = '00000000-0000-0000-0000-000000000000'::uuid then '' else '|' || v_dev::text end);
    v_devs := v_devs || v_dev;
    -- a sale already received answers what it answered; other content under its request id, or its number under another request, is refused
    select * into v_old from public.counter_offline_sales o
     where o.workspace_id = p_workspace_id and (o.request_id = v_req or (o.till_session_id = p_session_id and o.device_id = v_dev and o.seq = v_seq));
    if v_old.id is not null then
      if v_old.request_id <> v_req or v_old.digest <> v_digest or v_old.till_session_id <> p_session_id or v_old.device_id <> v_dev then
        raise exception 'this request id or sequence number already holds another sale' using errcode = 'DKL16',
          detail = jsonb_build_object('seq', v_seq)::text;
      end if;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_old.seq, 'request_id', v_old.request_id, 'state', v_old.state,
        'receipt_id', v_old.receipt_id, 'number', v_old.number, 'reason', v_old.reason, 'replayed', true));
      continue;
    end if;
    -- the cash taken is bounded by what the sale's own lines price to (and the price tolerance): a refused sale's cash stays in the
    -- drawer count, so it can never be more than what was sold
    v_body_total := public.counter_offline_body_total(p_workspace_id, v_body, v_digits);
    if v_body_total is null or v_given - v_change > ceil(v_body_total * (100 + v_tolerance) / 100.0) then
      perform public.refuse('DKL02', null, 'offline_cash');
    end if;
    v_reason := null;
    v_total := null;
    v_draft := null;
    -- a closed session is counted: nothing new is recorded against it, not even a refusal whose cash would change its figures
    if v_sess.state <> 'open' then
      raise exception 'open the till first' using errcode = 'DKL12', detail = '{"reason": "session"}';
    elsif v_at > now() then
      v_reason := 'clock';
    elsif v_at < v_sess.opened_at or p_offline_since < v_sess.opened_at then
      v_reason := 'before_session';
    elsif v_at > p_offline_since + make_interval(mins => v_max_minutes) then
      v_reason := 'too_long';
    elsif (select count(*) from public.counter_offline_sales o where o.till_session_id = p_session_id and o.state = 'accepted') >= v_max_sales then
      v_reason := 'too_many';
    elsif coalesce(nullif(v_body ->> 'price_basis', ''), 'gross') <> 'gross' then
      v_reason := 'price';
    end if;
    -- the items and their prices
    if v_reason is null and coalesce(jsonb_typeof(v_body -> 'lines'), '') = 'array' then
      for l in select value from jsonb_array_elements(v_body -> 'lines') loop
        if jsonb_typeof(l) <> 'object' or coalesce(l ->> 'item_id', '') = '' then
          v_reason := 'item';
          exit;
        end if;
        begin
          select * into v_item from public.services s where s.id = (l ->> 'item_id')::uuid and s.workspace_id = p_workspace_id;
        exception when invalid_text_representation then v_item := null;
        end;
        if v_item.id is null or not v_item.active then
          v_reason := 'item';
          exit;
        end if;
        -- the price of one base unit, whatever way the base quantity is written ('1', '1.0', '10')
        if coalesce(l ->> 'unit_price', '') <> '' then
          begin
            v_base := coalesce(nullif(l ->> 'base_quantity', ''), '1')::numeric;
            v_price := case when v_base > 0 then (l ->> 'unit_price')::numeric / v_base * (10::numeric ^ v_digits) end;
          exception when invalid_text_representation or numeric_value_out_of_range or division_by_zero then v_price := null;
          end;
          if v_price is null or abs(v_price - v_item.price_cents) * 100 > v_tolerance * v_item.price_cents then
            v_reason := 'price';
            exit;
          end if;
        end if;
      end loop;
    end if;
    -- the sale itself, through the ordinary commands, in its own sub-transaction: a refusal leaves nothing but its record
    if v_reason is null then
      begin
        v_draft := public.counter_receipt_draft_v1(p_workspace_id, v_req, null, null,
          v_body || jsonb_build_object('till_id', v_sess.till_id, 'source_kind', 'offline_till', 'source_ref', p_session_id::text || ':' || v_seq));
        v_total := (v_draft #>> '{totals,gross_minor}')::bigint;
        if v_given < v_total or v_change <> v_given - v_total then
          perform public.refuse('DKL06', null, 'tender_sum');
        end if;
        v_final := public.counter_receipt_finalize_v1(p_workspace_id, md5(v_req::text || ':finalize')::uuid, (v_draft ->> 'receipt_id')::uuid, (v_draft ->> 'revision')::int,
          jsonb_build_array(jsonb_build_object('kind', 'cash', 'amount_minor', v_total)));
        insert into public.counter_offline_sales (workspace_id, till_session_id, device_id, seq, request_id, digest, occurred_at, offline_since, state,
                                                  receipt_id, number, total_minor, cash_given_minor, change_minor, body, synced_by_member_id)
        values (p_workspace_id, p_session_id, v_dev, v_seq, v_req, v_digest, v_at, p_offline_since, 'accepted',
                (v_draft ->> 'receipt_id')::uuid, v_final ->> 'number', v_total, v_given, v_change, v_body, v_me)
        returning * into v_row;
      -- the refusals of the commands (the DK codes of the counter and the stock); anything else is a fault and stops the call
      exception when sqlstate 'DKG01' or sqlstate 'DKG02' or sqlstate 'DKG03' or sqlstate 'DKG04' or sqlstate 'DKG05' or sqlstate 'DKG06' or sqlstate 'DKG07' or sqlstate 'DKG08' or sqlstate 'DKG09' or sqlstate 'DKG10' or sqlstate 'DKG11' or sqlstate 'DKG12' or sqlstate 'DKG13' or sqlstate 'DKG15' or sqlstate 'DKG16' or sqlstate 'DKG17' or sqlstate 'DKG18' or sqlstate 'DKG19' or sqlstate 'DKG20' or sqlstate 'DKG21' or sqlstate 'DKG22' or sqlstate 'DKG23' or sqlstate 'DKG24' or sqlstate 'DKG25' or sqlstate 'DKG26' or sqlstate 'DKGZZ' or sqlstate 'DKL01' or sqlstate 'DKL02' or sqlstate 'DKL03' or sqlstate 'DKL04' or sqlstate 'DKL05' or sqlstate 'DKL06' or sqlstate 'DKL07' or sqlstate 'DKL08' or sqlstate 'DKL09' or sqlstate 'DKL10' or sqlstate 'DKL11' or sqlstate 'DKL12' or sqlstate 'DKL13' or sqlstate 'DKL14' or sqlstate 'DKL15' or sqlstate 'DKL16' or sqlstate 'DKN01' then
        v_reason := case when sqlstate = 'DKL06' and sqlerrm = 'tender_sum' then 'cash' else 'refused:' || sqlstate end;
        v_row := null;
      end;
    end if;
    if v_row.id is not null and v_reason is null then
      v_accepted := v_accepted + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_seq, 'request_id', v_req, 'state', 'accepted',
        'receipt_id', v_row.receipt_id, 'number', v_row.number, 'reason', null, 'replayed', false));
    else
      insert into public.counter_offline_sales (workspace_id, till_session_id, device_id, seq, request_id, digest, occurred_at, offline_since, state, reason,
                                                cash_given_minor, change_minor, body, synced_by_member_id)
      values (p_workspace_id, p_session_id, v_dev, v_seq, v_req, v_digest, v_at, p_offline_since, 'refused', v_reason, v_given, v_change, v_body, v_me);
      v_refused := v_refused + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_seq, 'request_id', v_req, 'state', 'refused',
        'receipt_id', null, 'number', null, 'reason', v_reason, 'replayed', false));
    end if;
    v_row := null;
  end loop;
  return jsonb_build_object('results', v_results, 'gaps', public.counter_offline_gaps(p_session_id, v_devs), 'accepted', v_accepted, 'refused', v_refused);
end;
$fn$;
revoke execute on function public.counter_offline_sync_v1(uuid, uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.counter_offline_sync_v1(uuid, uuid, timestamptz, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(944);
