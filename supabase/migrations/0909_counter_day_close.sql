-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (two functions)
--
-- #4367 (CS5, fifth file) -- the day close: once every till of the site is closed, a person who may see the finances closes
-- the day. The day report is an immutable, numbered business record: the sales by tax rate and by tender, the corrections and
-- the refunds of the day, the cash paid in and out, the difference of every session with its reason, the unresolved card
-- authorizations (listed, never counted as cash), and the range of receipt numbers. It is the BUSINESS record only: the legal
-- content a country requires of a day close comes with its own adapter and is not claimed here.
--
--   * A till still open refuses the day close, naming it (DKL14 till_open). A day closed once is closed (DKL14 day_closed). A
--     day with no closed session has nothing to close (DKL14 nothing_to_close). The request id replays the same close.
--   * Closing the day stamps each of its sessions with the close; a closed session is otherwise never edited.
--   * `counter_day_report_v1` reads a close back: with the right to see the finances, also for an assistant session.

create or replace function public.counter_day_close_v1(p_workspace_id uuid, p_request_id uuid, p_site_id uuid, p_business_date date)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_site_key text := coalesce(p_site_id::text, '');
  v_today date;
  v_open record;
  v_sessions uuid[];
  v_report jsonb;
  v_number text;
  v_close public.counter_day_closes;
  v_tz text;
  v_result jsonb;
begin
  v_me := public.counter_finance_actor(p_workspace_id);
  if p_request_id is null or p_business_date is null then
    raise exception 'a day is closed with a request id and its date' using errcode = '22023';
  end if;
  v_today := public.workspace_today(p_workspace_id);
  if p_business_date > v_today then
    raise exception 'a day is closed after it has begun' using errcode = 'DKL14', detail = jsonb_build_object('reason', 'future')::text;
  end if;
  if p_site_id is not null and not exists (select 1 from public.sites s where s.id = p_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'not a site of this business' using errcode = 'DKL14', detail = jsonb_build_object('reason', 'site_unknown')::text;
  end if;
  v_digest := md5(v_site_key || '|' || p_business_date::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_day_close', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  -- serialised per business: two day closes (and the sessions they read) never interleave
  perform pg_advisory_xact_lock(hashtextextended('counter_day_close:' || p_workspace_id::text, 0));
  if exists (select 1 from public.counter_day_closes c where c.workspace_id = p_workspace_id and c.site_key = v_site_key and c.business_date = p_business_date) then
    raise exception 'this day is already closed' using errcode = 'DKL14', detail = jsonb_build_object('reason', 'day_closed')::text;
  end if;
  select w.timezone into v_tz from public.workspaces w where w.id = p_workspace_id;
  v_tz := coalesce(nullif(v_tz, ''), 'UTC');
  -- a till of the site that is still open since that day or before refuses it, naming the till (a session opened later is another day's)
  select t.id, t.name into v_open from public.counter_tills t
   join public.counter_till_sessions s on s.till_id = t.id and s.state = 'open'
   where t.workspace_id = p_workspace_id and (p_site_id is null or t.site_id = p_site_id)
     and (s.opened_at at time zone v_tz)::date <= p_business_date
   order by t.name limit 1;
  if v_open.id is not null then
    raise exception 'a till is still open' using errcode = 'DKL14',
      detail = jsonb_build_object('reason', 'till_open', 'till_id', v_open.id, 'name', v_open.name)::text;
  end if;
  select array_agg(s.id order by s.closed_at) into v_sessions
    from public.counter_till_sessions s join public.counter_tills t on t.id = s.till_id
   where s.workspace_id = p_workspace_id and s.state = 'closed' and s.day_close_id is null
     and (p_site_id is null or t.site_id = p_site_id)
     and (s.closed_at at time zone v_tz)::date = p_business_date;
  if v_sessions is null then
    raise exception 'nothing to close on this day' using errcode = 'DKL14', detail = jsonb_build_object('reason', 'nothing_to_close')::text;
  end if;
  v_report := jsonb_build_object(
    'version', 1,
    'business_date', p_business_date,
    'site_id', p_site_id,
    'sessions', (select jsonb_agg(jsonb_build_object(
        'session_id', s.id, 'till', t.name, 'opened_at', s.opened_at, 'closed_at', s.closed_at,
        'float_minor', s.float_minor::text, 'expected_minor', s.expected_minor::text, 'counted_minor', s.counted_minor::text,
        'difference_minor', s.difference_minor::text, 'difference_reason', s.difference_reason, 'banked_minor', s.banked_minor::text,
        'unresolved_card_minor', s.unresolved_card_minor::text) order by s.closed_at)
        from public.counter_till_sessions s join public.counter_tills t on t.id = s.till_id where s.id = any (v_sessions)),
    'differences_minor', (select coalesce(sum(s.difference_minor), 0)::text from public.counter_till_sessions s where s.id = any (v_sessions)),
    'sales_by_rate', (select coalesce(jsonb_agg(jsonb_build_object('percent', g.pct, 'category', g.cat, 'gross_minor', g.gross::text, 'net_minor', g.net::text, 'tax_minor', g.tax::text) order by g.pct desc, g.cat), '[]'::jsonb)
        from (select (b ->> 'percent')::numeric pct, b ->> 'category' cat, sum((b ->> 'gross_minor')::bigint) gross, sum((b ->> 'net_minor')::bigint) net, sum((b ->> 'tax_minor')::bigint) tax
                from public.counter_receipts r, jsonb_array_elements(r.frozen -> 'tax_breakdown') b
               where r.till_session_id = any (v_sessions) and r.state = 'finalized' and r.kind = 'sale' group by 1, 2) g),
    'sales_by_tender', (select coalesce(jsonb_object_agg(g.kind, g.amount::text), '{}'::jsonb)
        from (select t.kind, sum(t.amount_minor) amount from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
               where r.till_session_id = any (v_sessions) and r.state = 'finalized' and r.kind = 'sale' and t.state = 'accepted' group by 1) g),
    'sales_total_minor', (select coalesce(sum(r.total_minor), 0)::text from public.counter_receipts r where r.till_session_id = any (v_sessions) and r.state = 'finalized' and r.kind = 'sale'),
    'receipts', (select jsonb_build_object('count', count(*), 'first', min(r.number), 'last', max(r.number))
        from public.counter_receipts r where r.till_session_id = any (v_sessions) and r.state = 'finalized' and r.kind = 'sale'),
    -- scoped to THESE sessions: a correction and a refund of another way than cash belong to the session the original receipt was sold in
    -- (a cash refund carries its own session); what is refunded of a receipt after its day was closed is in no closed report
    'scope', jsonb_build_object('sales', 'sessions', 'cash_refunds', 'sessions', 'other_refunds', 'original_receipt_session', 'corrections', 'original_receipt_session'),
    'corrections', (select jsonb_build_object('count', count(*), 'total_minor', coalesce(sum(r.total_minor), 0)::text)
        from public.counter_receipts r join public.counter_receipts o on o.id = r.corrects_receipt_id and o.workspace_id = r.workspace_id
        where r.workspace_id = p_workspace_id and r.kind = 'correction' and r.state = 'finalized' and o.till_session_id = any (v_sessions)),
    'refunds', (select coalesce(jsonb_object_agg(g.kind, g.amount::text), '{}'::jsonb)
        from (select f.kind, sum(f.amount_minor) amount from public.counter_refunds f
               left join public.counter_receipts c on c.id = f.receipt_id and c.workspace_id = f.workspace_id
               left join public.counter_receipts o on o.id = c.corrects_receipt_id and o.workspace_id = f.workspace_id
               where f.workspace_id = p_workspace_id
                 and ((f.kind = 'cash' and f.till_session_id = any (v_sessions))
                      or (f.kind <> 'cash' and o.till_session_id = any (v_sessions))) group by 1) g),
    'paid_in_minor', (select coalesce(sum(e.amount_minor), 0)::text from public.counter_cash_entries e where e.session_id = any (v_sessions) and e.kind = 'paid_in'),
    'paid_out_minor', (select coalesce(sum(e.amount_minor), 0)::text from public.counter_cash_entries e where e.session_id = any (v_sessions) and e.kind = 'paid_out'),
    'cash_entries', (select coalesce(jsonb_agg(jsonb_build_object('kind', e.kind, 'amount_minor', e.amount_minor::text, 'reason', e.reason,
                                                                    'purchase_document_id', e.purchase_document_id) order by e.created_datetime), '[]'::jsonb)
        from public.counter_cash_entries e where e.session_id = any (v_sessions)));
  v_number := public.next_document_number(p_workspace_id, 'day_close');
  insert into public.counter_day_closes (workspace_id, site_key, business_date, number, report, closed_by_member_id)
  values (p_workspace_id, v_site_key, p_business_date, v_number, v_report, v_me) returning * into v_close;
  update public.counter_till_sessions set day_close_id = v_close.id where id = any (v_sessions);
  v_result := jsonb_build_object('day_close_id', v_close.id, 'number', v_number, 'report', v_report, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_day_close', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_day_close_v1(uuid, uuid, uuid, date) from public, anon;
grant execute on function public.counter_day_close_v1(uuid, uuid, uuid, date) to authenticated;

-- a close read back: the right to see the finances, an assistant session included
create or replace function public.counter_day_report_v1(p_workspace_id uuid, p_day_close_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_close public.counter_day_closes;
begin
  if auth.uid() is null or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'not allowed to read the day report' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'counterTillSessions') then
    raise exception 'till sessions are off in this business' using errcode = 'DKG01';
  end if;
  select * into v_close from public.counter_day_closes c where c.id = p_day_close_id and c.workspace_id = p_workspace_id;
  if v_close.id is null then
    raise exception 'not a day close of this business' using errcode = 'DKL14', detail = jsonb_build_object('reason', 'day_unknown')::text;
  end if;
  return jsonb_build_object('day_close_id', v_close.id, 'number', v_close.number, 'business_date', v_close.business_date, 'report', v_close.report);
end;
$fn$;
revoke execute on function public.counter_day_report_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_day_report_v1(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(909);
