-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2573) -- the rest of the purchase line's contract:
--
--   * A line names where its cost belongs: a site of the space
--     (`cost_site_id`) and/or one of its resources (`resource_kind` level,
--     office, desk or seat + `resource_id`). Both are optional. A resource
--     alone names its site (its level's); a resource of another site than
--     the one the line names is refused, as is a site or a resource of
--     another space. `purchase_write_lines` (0461) and `purchase_detail_v1`
--     (0466) are restated whole; the detail also returns the place's name.
--   * A member's receipt may carry several tax rates, zero-rated lines and
--     long-lasting equipment beside other lines. `submit_purchase_v1`
--     (0468, restated whole) checks the lines of each rate, refuses a taxed
--     receipt with a line whose tax is not stated, and still refuses an
--     unqualified deductible share. A receipt of one rate and one class
--     files its expense exactly as before (one VAT payload on the event).
--     Any other taxed receipt files its expense with `vat: {source: lines}`
--     (the stamp, 0461, restated whole), and `vat_input_amounts` (0413,
--     restated whole) reads that receipt's input tax from its lines, one row
--     per rate and class: the purchase replaces the event's input, never
--     adds to it. The posting engine already books a receipt line by line
--     (0524).
--
-- Not here: a purchase in another currency than the space's stays refused
-- (`a purchase is in the currency of the space`, 0461); booking a purchase
-- under another issuer than the default one.

-- ── the place of a line ────────────────────────────────────────────────
create unique index if not exists sites_workspace_id_id_key
  on public.sites (workspace_id, id);

alter table public.purchase_lines
  add column cost_site_id uuid,
  add column resource_kind text
    check (resource_kind is null or resource_kind in ('level', 'office', 'desk', 'seat')),
  add column resource_id uuid,
  add constraint purchase_lines_resource_pair
    check ((resource_kind is null) = (resource_id is null)),
  add constraint purchase_lines_cost_site_fkey
    foreign key (workspace_id, cost_site_id) references public.sites (workspace_id, id);

-- The site a resource of [p_workspace_id] lies on (its level's); found =
-- false when the space has no such resource.
create or replace function public.purchase_resource_site(
  p_workspace_id uuid, p_kind text, p_id uuid
) returns table (found boolean, site_id uuid)
language sql stable security definer set search_path = public as $fn$
  select true, x.site_id from (
    select lv.site_id from public.levels lv
     where p_kind = 'level' and lv.id = p_id and lv.workspace_id = p_workspace_id
    union all
    select lv.site_id from public.offices o join public.levels lv on lv.id = o.level_id
     where p_kind = 'office' and o.id = p_id and o.workspace_id = p_workspace_id
    union all
    select lv.site_id from public.desks d join public.offices o on o.id = d.office_id
      join public.levels lv on lv.id = o.level_id
     where p_kind = 'desk' and d.id = p_id and d.workspace_id = p_workspace_id
    union all
    select lv.site_id from public.seats s join public.desks d on d.id = s.desk_id
      join public.offices o on o.id = d.office_id join public.levels lv on lv.id = o.level_id
     where p_kind = 'seat' and s.id = p_id and s.workspace_id = p_workspace_id
  ) x
  limit 1;
$fn$;
revoke execute on function public.purchase_resource_site(uuid, text, uuid)
  from public, anon, authenticated;

-- The name a person knows the place of a line by: the resource's, else the
-- site's; '' when the line names none.
create or replace function public.purchase_place_name(p_line public.purchase_lines)
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce(
    case p_line.resource_kind
      when 'level' then (select lv.name from public.levels lv where lv.id = p_line.resource_id)
      when 'office' then (select o.name from public.offices o where o.id = p_line.resource_id)
      when 'desk' then (select d.name from public.desks d where d.id = p_line.resource_id)
      when 'seat' then (select s.name from public.seats s where s.id = p_line.resource_id)
    end,
    (select si.name from public.sites si where si.id = p_line.cost_site_id),
    '');
$fn$;
revoke execute on function public.purchase_place_name(public.purchase_lines)
  from public, anon, authenticated;

-- 0461's lines, with their place.
create or replace function public.purchase_write_lines(
  p_workspace_id uuid, p_purchase_id uuid, p_lines jsonb
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  n int := 0;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rec bigint;
  v_kind text;
  v_site uuid;
  v_rkind text;
  v_rid uuid;
  v_found boolean;
  v_rsite uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200 then
    raise exception 'a purchase has between 1 and 200 lines';
  end if;
  delete from public.purchase_lines where purchase_id = p_purchase_id;
  for e in select value from jsonb_array_elements(p_lines) loop
    n := n + 1;
    v_gross := (e ->> 'gross_cents')::bigint;
    if v_gross is null or v_gross < 0 then raise exception 'a line needs a gross amount'; end if;
    v_net := nullif(e ->> 'net_cents', '')::bigint;
    v_tax := nullif(e ->> 'tax_cents', '')::bigint;
    if (v_net is null) <> (v_tax is null) then
      raise exception 'net and tax are given together or not at all';
    end if;
    if v_net is not null and v_net + v_tax <> v_gross then
      raise exception 'net plus tax is not the gross amount';
    end if;
    v_rec := nullif(e ->> 'recoverable_tax_cents', '')::bigint;
    if v_rec is not null and (v_tax is null or v_rec < 0 or v_rec > v_tax) then
      raise exception 'the recoverable tax lies between 0 and the tax';
    end if;
    v_kind := coalesce(nullif(e ->> 'recognition_kind', ''), 'unresolved');
    -- Where the cost belongs: the space's own site and resource, never
    -- another space's; a resource alone names its site.
    v_site := nullif(e ->> 'cost_site_id', '')::uuid;
    v_rkind := nullif(e ->> 'resource_kind', '');
    v_rid := nullif(e ->> 'resource_id', '')::uuid;
    if (v_rkind is null) <> (v_rid is null) then
      raise exception 'a resource is named by its kind and its id';
    end if;
    if v_rkind is not null then
      if v_rkind not in ('level', 'office', 'desk', 'seat') then
        raise exception 'unknown resource kind';
      end if;
      v_found := false;
      v_rsite := null;
      select r.found, r.site_id into v_found, v_rsite
        from public.purchase_resource_site(p_workspace_id, v_rkind, v_rid) r;
      if not coalesce(v_found, false) then raise exception 'unknown resource'; end if;
      if v_site is not null and v_rsite is not null and v_site <> v_rsite then
        raise exception 'the resource lies on another site';
      end if;
      v_site := coalesce(v_site, v_rsite);
    end if;
    if v_site is not null and not exists (
         select 1 from public.sites s where s.id = v_site and s.workspace_id = p_workspace_id) then
      raise exception 'unknown site';
    end if;
    insert into public.purchase_lines
      (workspace_id, purchase_id, line_no, description, quantity, unit, gross_cents,
       net_cents, tax_cents, tax_rate_percent, recoverable_tax_cents,
       nonrecoverable_tax_cents, tax_component_keys, supply, recognition_kind,
       cost_site_id, resource_kind, resource_id)
    values
      (p_workspace_id, p_purchase_id, n, left(coalesce(e ->> 'description', ''), 500),
       coalesce(nullif(e ->> 'quantity', '')::numeric, 1), left(coalesce(e ->> 'unit', ''), 20),
       v_gross, v_net, v_tax, nullif(e ->> 'tax_rate_percent', '')::numeric, v_rec,
       case when v_rec is null then null else v_tax - v_rec end,
       coalesce(array(select jsonb_array_elements_text(e -> 'tax_component_keys')), '{}'),
       e -> 'supply', v_kind, v_site, v_rkind, v_rid);
  end loop;
end;
$fn$;
revoke execute on function public.purchase_write_lines(uuid, uuid, jsonb)
  from public, anon, authenticated;

-- ── the expense event of a receipt whose tax lies on its lines ─────────
create or replace function public.purchase_expense_event_stamp()
returns trigger language plpgsql as $fn$
declare
  v_native text := nullif(current_setting('deskilo.purchase_bridge', true), '');
begin
  if new.type = 'expense' and v_native is not null then
    new.payload := new.payload
      || jsonb_build_object('purchase_id', v_native, 'payer', 'member')
      -- Several rates or classes: the event carries no rate of its own; the
      -- input tax is read from the purchase lines (vat_input_amounts).
      || case when current_setting('deskilo.purchase_vat_lines', true) = 'on'
              then jsonb_build_object('vat', jsonb_build_object('source', 'lines'))
              else '{}'::jsonb end;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_expense_event_stamp() from public, anon, authenticated;

-- 0413's amounts, and the input tax of a receipt that states it per line.
create or replace function public.vat_input_amounts(
  p_workspace_id uuid, p_start date, p_end date
) returns table (expense_id uuid, tax_point date, percent numeric,
                 category text, gross_cents bigint, net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  with w as (
    select coalesce(nullif(ws.timezone, ''), 'UTC') as tz
      from public.workspaces ws where ws.id = p_workspace_id
  ), ev as (
    select e.id, e.workspace_id, e.actor_member_id, e.payload,
           (e.decided_at at time zone w.tz)::date as tax_point
      from public.events e cross join w
     where e.workspace_id = p_workspace_id
       and e.type = 'expense' and e.status = 'confirmed'
       and e.decided_at is not null
       and (e.decided_at at time zone w.tz)::date between p_start and p_end
       and public.feature_effective(p_workspace_id, 'inputVat')
  )
  select ev.id, ev.tax_point,
         trim_scale((ev.payload #>> '{vat,percent}')::numeric),
         case when coalesce((ev.payload #>> '{vat,asset}')::boolean, false)
              then 'asset' else 'S' end,
         s.net_cents + s.deductible_cents, s.net_cents
    from ev
    cross join lateral public.vat_input_split(
      (ev.payload ->> 'amount_cents')::bigint,
      (ev.payload #>> '{vat,percent}')::numeric,
      coalesce((ev.payload #>> '{vat,deductible_pct}')::numeric, 100)) s
   where coalesce((ev.payload #>> '{vat,percent}')::numeric, 0) > 0
  union all
  -- The receipt's own lines, once: the event that filed it states no rate.
  select ev.id, ev.tax_point, trim_scale(l.tax_rate_percent),
         case when l.recognition_kind = 'asset' then 'asset' else 'S' end,
         sum(l.net_cents + l.recoverable_tax_cents)::bigint, sum(l.net_cents)::bigint
    from ev
    join public.purchase_sources ps
      on ps.workspace_id = ev.workspace_id and ps.source_kind = 'expense_event'
     and ps.source_id = ev.id and ps.role = 'origin'
    join public.purchase_documents d
      on d.workspace_id = ps.workspace_id and d.id = ps.purchase_id
     and d.kind = 'member_receipt' and d.submitter_member_id = ev.actor_member_id
    join public.purchase_lines l on l.workspace_id = d.workspace_id and l.purchase_id = d.id
   where ev.payload #>> '{vat,source}' = 'lines'
     and l.tax_rate_percent > 0 and l.tax_cents > 0 and l.recoverable_tax_cents is not null
   group by ev.id, ev.tax_point, trim_scale(l.tax_rate_percent),
            case when l.recognition_kind = 'asset' then 'asset' else 'S' end;
$fn$;
revoke execute on function public.vat_input_amounts(uuid, date, date)
  from public, anon, authenticated;

-- ── submitting: 0468's, a receipt of several rates and classes ─────────
create or replace function public.submit_purchase_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_revision int, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_doc public.purchase_documents;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rates int;
  v_unstated int;
  v_unknown int;
  v_assets int;
  v_lines int;
  v_percent numeric;
  v_rec bigint;
  v_unqualified int;
  v_single boolean;
  v_vat_lines boolean := false;
  v_vat jsonb := null;
  v_supply jsonb := null;
  v_desc text;
  v_event uuid;
  v_state text;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || p_purchase_id::text || coalesce(p_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'submit', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  if v_doc.kind = 'credit_note' then
    raise exception 'a credit note is applied to its bill in a later step';
  end if;
  if v_doc.state <> 'draft' then raise exception 'only a draft can be submitted'; end if;
  if v_doc.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if v_doc.kind = 'bill' then
    -- A supplier bill goes to a second person: the submitter captured it
    -- (managePurchases, checked on the draft), the approver decides it.
    if not public.has_permission(p_workspace_id, 'managePurchases') then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.supplier_id is null then raise exception 'a bill needs its supplier'; end if;
    if v_doc.payer_kind <> 'unpaid' then
      raise exception 'only a bill still to be paid goes to approval';
    end if;
    select count(*), coalesce(sum(gross_cents), 0) into v_lines, v_gross
      from public.purchase_lines where purchase_id = v_doc.id;
    if v_lines = 0 or v_gross <= 0 then raise exception 'a bill needs an amount'; end if;
    if v_gross > 2147483647 then raise exception 'the amount of a bill is too large'; end if;
    -- Whoever sends it to approval cannot decide it either: the drafter and
    -- the sender may be two people, and neither is the second person.
    update public.purchase_documents
       set state = 'pending', submitted_by_member_id = v_me where id = v_doc.id;
    v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                   'state', 'pending');
    return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
  end if;
  if v_doc.submitter_member_id <> v_me then raise exception 'not your purchase'; end if;
  if v_doc.category = '' then raise exception 'a receipt needs a category'; end if;

  -- v_unstated: a line without a stated tax or rate (the one-rate payload
  -- needs both); v_unknown: a line whose tax is not known at all, or taxed
  -- at no stated rate.
  select count(*), coalesce(sum(gross_cents), 0),
         count(*) filter (where tax_cents is null or tax_rate_percent is null),
         count(*) filter (where tax_cents is null or (tax_cents > 0 and coalesce(tax_rate_percent, 0) <= 0)),
         count(distinct tax_rate_percent), count(*) filter (where recognition_kind = 'asset'),
         coalesce(sum(net_cents), 0), coalesce(sum(tax_cents), 0),
         coalesce(sum(recoverable_tax_cents), 0),
         count(*) filter (where tax_cents > 0 and recoverable_tax_cents is null)
    into v_lines, v_gross, v_unstated, v_unknown, v_rates, v_assets, v_net, v_tax, v_rec,
         v_unqualified
    from public.purchase_lines where purchase_id = v_doc.id;
  if v_lines = 0 or v_gross <= 0 then raise exception 'a receipt needs an amount'; end if;
  if v_gross > 2147483647 then raise exception 'the amount of a receipt is too large'; end if;
  v_single := v_unstated = 0 and v_rates = 1 and v_assets in (0, v_lines);
  if v_tax > 0 then
    if v_unknown > 0 then
      raise exception 'state the tax and the rate of every line of a taxed receipt';
    end if;
    if v_unqualified > 0 then
      raise exception 'qualify the deductible tax of every line before submitting';
    end if;
    -- Each rate's lines follow from it: line by line, or as a whole.
    if exists (
         select 1 from (
           select l.tax_rate_percent as r, sum(l.gross_cents) as g, sum(l.net_cents) as n,
                  bool_and(l.net_cents = public.vat_split_net(l.gross_cents, l.tax_rate_percent)) as each_ok
             from public.purchase_lines l
            where l.purchase_id = v_doc.id and l.tax_rate_percent > 0
            group by l.tax_rate_percent) x
          where not x.each_ok and x.n <> public.vat_split_net(x.g, x.r)) then
      raise exception 'the tax amounts do not follow from the rate';
    end if;
    if public.feature_effective(p_workspace_id, 'inputVat') then
      if v_single then
        -- One rate and one class: ONE rate and ONE deductible share on the
        -- expense, as before.
        select max(tax_rate_percent) into v_percent
          from public.purchase_lines where purchase_id = v_doc.id;
        v_vat := jsonb_build_object('percent', trim_scale(v_percent),
                   'deductible_pct', trim_scale(round(v_rec::numeric * 100 / v_tax, 4)))
                 || case when v_assets > 0 then jsonb_build_object('asset', true) else '{}'::jsonb end;
      else
        v_vat_lines := true;
      end if;
    end if;
  end if;
  select l.description, l.supply into v_desc, v_supply from public.purchase_lines l
   where l.purchase_id = v_doc.id and l.line_no = 1;
  if v_lines > 1 then v_supply := null; end if;

  perform set_config('deskilo.purchase_bridge', v_doc.id::text, true);
  perform set_config('deskilo.purchase_vat_lines', case when v_vat_lines then 'on' else '' end, true);
  v_event := public.submit_expense(p_workspace_id, v_gross::int, v_doc.category,
                                   coalesce(v_desc, ''), v_supply, v_vat);
  perform set_config('deskilo.purchase_vat_lines', '', true);
  perform set_config('deskilo.purchase_bridge', '', true);

  select d.state into v_state from public.purchase_documents d where d.id = v_doc.id;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'event_id', v_event,
                                 'revision', v_doc.revision, 'state', v_state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
end;
$fn$;
revoke execute on function public.submit_purchase_v1(uuid, uuid, int, uuid) from public, anon;
grant execute on function public.submit_purchase_v1(uuid, uuid, int, uuid) to authenticated;

-- ── the detail: 0466's, each line with its place ───────────────────────
create or replace function public.purchase_detail_v1(p_workspace_id uuid, p_purchase_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  d public.purchase_documents;
  v_wide boolean;
  v_readable boolean;
  v_me uuid;
begin
  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id;
  if d.id is not null then
    v_wide := public.has_permission(p_workspace_id, 'viewFinances')
      or public.has_permission(p_workspace_id, 'managePurchases');
    select m.id into v_me from public.members m
     where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
    v_readable := v_wide or v_me = d.submitter_member_id;
  end if;
  if d.id is null or not coalesce(v_readable, false) then
    raise exception 'unknown purchase';
  end if;
  return jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'state', d.state, 'revision', d.revision,
    'category', d.category, 'currency', d.currency,
    'original_reference', d.original_reference, 'original_date', d.original_date,
    'received_on', d.received_on, 'service_from', d.service_from, 'service_to', d.service_to,
    'due_on', d.due_on, 'payer_kind', d.payer_kind, 'payer_member_id', d.payer_member_id,
    'submitter_member_id', d.submitter_member_id, 'approved_event_id', d.approved_event_id,
    'classification_status', d.classification_status,
    'legacy_qualification', d.legacy_qualification,
    'supplier', (select jsonb_build_object('id', s.id, 'supplier_number', s.supplier_number,
                                           'name', s.name)
                   from public.suppliers s where s.id = d.supplier_id),
    'supplier_snapshot', d.supplier_snapshot, 'recipient_snapshot', d.recipient_snapshot,
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
        'line_no', l.line_no, 'description', l.description, 'quantity', l.quantity,
        'unit', l.unit, 'gross_cents', l.gross_cents, 'net_cents', l.net_cents,
        'tax_cents', l.tax_cents, 'tax_rate_percent', l.tax_rate_percent,
        'recoverable_tax_cents', l.recoverable_tax_cents,
        'nonrecoverable_tax_cents', l.nonrecoverable_tax_cents,
        'recognition_kind', l.recognition_kind,
        'cost_site_id', l.cost_site_id, 'resource_kind', l.resource_kind,
        'resource_id', l.resource_id, 'place_name', public.purchase_place_name(l))
        order by l.line_no)
        from public.purchase_lines l where l.purchase_id = d.id), '[]'::jsonb),
    'sources', coalesce((select jsonb_agg(jsonb_build_object(
        'source_kind', s.source_kind, 'source_id', s.source_id, 'role', s.role,
        'original_hash', s.original_hash, 'original_reference', s.original_reference)
        order by s.created_datetime)
        from public.purchase_sources s where s.purchase_id = d.id), '[]'::jsonb),
    -- A member reads only their own claim; a manager all of them.
    'obligations', coalesce((select jsonb_agg(public.purchase_obligation_json(o)
                                              order by o.created_datetime, o.id)
        from public.purchase_obligations o
       where o.purchase_id = d.id
         and (v_wide or o.creditor_member_id = v_me)), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.purchase_detail_v1(uuid, uuid) from public, anon;
grant execute on function public.purchase_detail_v1(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
