-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one row of the settings registry; workspace_recorded_payments_v1 added)
--
-- 0643 (#2578) -- the rows behind the collected figure. finance.collected
-- (kpi_finance_summary, 0351/0398) sums invoice_match_payments: every
-- payment a match consumed, by the instant of the match (matched_at) on the
-- workspace clock, the invoice's currency or the workspace's. A recorded
-- payment that no match consumed is not collected, so it is not listed
-- either; this read lists exactly the rows the figure sums, one per match
-- payment, so the BI drill opens the payments that make up the amount.
--
-- workspace_recorded_payments_v1(ws, from, to, after, limit):
--   * the window is two local dates, both included: [local midnight of
--     p_from, local midnight after p_to) on the workspace clock -- the
--     KPI's month window, given as its first and last day, is the same set;
--     from <= to and at most 24 months, the KPI's own bound (22023);
--   * a page is bi.detail_page_size rows (registry, 10..200, default 50),
--     or fewer when p_limit asks for fewer; rows in matched_at desc, id desc;
--     p_after is the last row's {matched_at, id} as next_cursor sent it
--     (null for the first page); next_cursor is null on the last page. Amounts are exact decimal strings, like the KPI's.
--
-- Refusals, in this order:
--   42501  signed out, a delegated assistant, or without viewFinances: the
--          readers of the figure's amounts (the figure also needs
--          viewAnalytics; a finance reader who may not see the analysis
--          still reads the payments elsewhere in Money)
--   55000  money is switched off in this space (moneyTab), as 0637/0640
--   22023  a malformed window, cursor or limit

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bi.detail_page_size', 'int', '50'::jsonb, 10, 200, 'rows', 'kpi', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'workspace_recorded_payments_v1 (#2578)', 'How many rows one page of a figure''s detail returns, such as the payments behind the collected amount. A bound on one read, not on what the period holds: the next page continues where this one stopped.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.workspace_recorded_payments_v1(
  p_workspace_id uuid,
  p_from date,
  p_to date,
  p_after jsonb default null,
  p_limit int default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_currency text; v_tz text;
  v_start timestamptz; v_end timestamptz;
  v_size int;
  v_after_at timestamptz; v_after_id uuid;
  v_rows jsonb;
  v_count int;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'not allowed to read the payments of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'moneyTab') then
    raise exception 'money is switched off in this space' using errcode = '55000';
  end if;
  if p_from is null or p_to is null or p_from > p_to
     or p_to >= p_from + interval '24 months' then
    raise exception 'the window is two dates, from <= to, at most 24 months'
      using errcode = '22023';
  end if;
  -- No cursor (SQL or JSON null) reads the first page.
  if p_after is not null and jsonb_typeof(p_after) <> 'null' then
    if jsonb_typeof(p_after) <> 'object'
       or jsonb_typeof(p_after -> 'matched_at') is distinct from 'string'
       or jsonb_typeof(p_after -> 'id') is distinct from 'string' then
      raise exception 'a cursor names the last row''s matched_at and id'
        using errcode = '22023';
    end if;
    begin
      v_after_at := (p_after ->> 'matched_at')::timestamptz;
      v_after_id := (p_after ->> 'id')::uuid;
    exception when others then
      raise exception 'a cursor names the last row''s matched_at and id'
        using errcode = '22023';
    end;
  end if;

  -- The page size is the registry's; a missing row raises (unknown
  -- setting), never a hidden literal. A caller may ask for fewer.
  v_size := (public.setting_value(p_workspace_id, 'bi.detail_page_size') #>> '{}')::int;
  if p_limit is not null then
    if p_limit < 1 then
      raise exception 'a page holds at least one row' using errcode = '22023';
    end if;
    v_size := least(v_size, p_limit);
  end if;

  select upper(w.currency_code), coalesce(w.timezone, 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_start := p_from::timestamp at time zone v_tz;
  v_end := (p_to + 1)::timestamp at time zone v_tz;

  -- One more than the page, to know whether another page follows.
  select coalesce(jsonb_agg(r.item order by r.matched_at desc, r.id desc), '[]'::jsonb),
         count(*)
    into v_rows, v_count
    from (
      select mp.matched_at, mp.id,
             jsonb_build_object(
               'id', mp.id,
               'matched_at', mp.matched_at,
               'paid_on', le.occurred_on,
               'amount_minor', mp.amount_cents::text,
               'currency', upper(coalesce(nullif(btrim(i.currency), ''), v_currency)),
               'invoice_id', mp.invoice_id,
               'invoice_number', i.number,
               'payer_name', i.member_name,
               'resolution', mp.resolution,
               'label', le.description) as item
        from public.invoice_match_payments mp
        left join public.invoices i on i.id = mp.invoice_id
        left join public.ledger_entries le on le.id = mp.payment_ledger_id
       where mp.workspace_id = p_workspace_id
         and mp.matched_at >= v_start and mp.matched_at < v_end
         and (v_after_at is null or (mp.matched_at, mp.id) < (v_after_at, v_after_id))
       order by mp.matched_at desc, mp.id desc
       limit v_size + 1
    ) r;

  if v_count > v_size then
    v_rows := v_rows - v_size;
  end if;

  return jsonb_build_object(
    'from', p_from, 'to', p_to, 'timezone', v_tz,
    'page_size', v_size,
    'items', v_rows,
    'next_cursor', case when v_count > v_size then jsonb_build_object(
                     'matched_at', v_rows -> (v_size - 1) -> 'matched_at',
                     'id', v_rows -> (v_size - 1) -> 'id') end);
end
$fn$;
revoke execute on function public.workspace_recorded_payments_v1(uuid, date, date, jsonb, int) from public, anon;
grant execute on function public.workspace_recorded_payments_v1(uuid, date, date, jsonb, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(643);
