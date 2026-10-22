-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0531 (#2582 C2) -- a shared operating cost spread over the resources that
-- use it, by weights a person entered. Small and explicit: it never bills a
-- member, never calls expense_repartitions, never touches a posting or an
-- issued document.
--
--   * `bi_cost_allocation_rules`: append-only revisions of a rule. A rule
--     scopes the operating lines of one purchase line, or of the purchase
--     documents of one category; it has an effective interval, a basis text,
--     nonnegative whole weights per level, office, desk or seat, and its
--     author. A change appends a revision; retiring a rule is a revision too.
--     For a line dated d, a rule applies through its highest revision whose
--     interval holds d (none when that revision is retired), so a revision
--     effective later never rewrites an earlier month.
--   * `save_cost_allocation_rule_v1`: manageBilling AND viewAnalytics with
--     `purchaseAnalytics` on; the expected revision guards a concurrent edit;
--     a request id replays.
--   * `cost_allocation_rules_v1`: every revision of the workspace's rules,
--     newest first, for the editor and the history.
--   * `kpi_cost_allocation(ws, from, to)`: the operating costs of the months
--     (0529's per-line cost) split into direct (a rule with one resource),
--     shared (several) and unallocated (no rule, a rule whose weights add up
--     to 0, or two rules claiming the same line); each rule revision's total
--     is spread once by largest remainder, a tie to the resource that sorts
--     first (kind, then id). direct + shared + unallocated = the operating
--     costs. The resources carry the rule revisions behind their share.

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create table public.bi_cost_allocation_rules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  rule_id uuid not null,
  revision int not null check (revision >= 1),
  category text not null default '' check (char_length(category) <= 80),
  purchase_line_id uuid references public.purchase_lines(id),
  effective_from date not null,
  effective_to date,
  basis text not null check (char_length(btrim(basis)) between 1 and 300),
  weights jsonb not null default '[]'::jsonb check (jsonb_typeof(weights) = 'array'),
  retired boolean not null default false,
  author_member_id uuid not null,
  request_id uuid not null,
  foreign key (workspace_id, author_member_id) references public.members (workspace_id, id),
  unique (rule_id, revision),
  unique (workspace_id, request_id),
  check ((purchase_line_id is null) <> (category = '')),
  check (effective_to is null or effective_to >= effective_from)
);
select public.ensure_system_columns('bi_cost_allocation_rules');
create index bi_cost_allocation_rules_workspace
  on public.bi_cost_allocation_rules (workspace_id, rule_id, revision desc);

alter table public.bi_cost_allocation_rules enable row level security;
revoke all on public.bi_cost_allocation_rules from public, anon, authenticated;
grant select on public.bi_cost_allocation_rules to authenticated;
create policy bi_cost_allocation_rules_select on public.bi_cost_allocation_rules
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.bi_cost_allocation_rules as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.bi_cost_allocation_rules_guard()
returns trigger language plpgsql as $fn$
begin
  raise exception 'an allocation rule revision is never edited; append a revision';
end;
$fn$;
revoke execute on function public.bi_cost_allocation_rules_guard() from public, anon, authenticated;
create trigger bi_cost_allocation_rules_guard
  before update on public.bi_cost_allocation_rules
  for each row execute function public.bi_cost_allocation_rules_guard();

create or replace function public.cost_allocation_rule_json(r public.bi_cost_allocation_rules)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
    'id', r.id, 'rule_id', r.rule_id, 'revision', r.revision,
    'category', r.category, 'purchase_line_id', r.purchase_line_id,
    'effective_from', r.effective_from, 'effective_to', r.effective_to,
    'basis', r.basis, 'weights', r.weights, 'retired', r.retired,
    'author_member_id', r.author_member_id, 'created_at', r.created_datetime);
$fn$;
revoke execute on function public.cost_allocation_rule_json(public.bi_cost_allocation_rules) from public, anon;

create or replace function public.save_cost_allocation_rule_v1(
  p_workspace_id uuid, p_rule_id uuid, p_expected_revision int, p_rule jsonb, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_done public.bi_cost_allocation_rules;
  v_latest int;
  v_line uuid := nullif(p_rule ->> 'purchase_line_id', '')::uuid;
  v_category text := btrim(coalesce(p_rule ->> 'category', ''));
  v_retired boolean := coalesce((p_rule ->> 'retired')::boolean, false);
  v_weights jsonb := coalesce(p_rule -> 'weights', '[]'::jsonb);
  v_w jsonb;
  v_seen text[] := '{}';
  v_key text;
  v_row public.bi_cost_allocation_rules;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to change the cost allocation' using errcode = '42501';
  end if;
  select mem.id into v_me from public.members mem
   where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid() and mem.status = 'active';
  if v_me is null then raise exception 'not an active member' using errcode = '42501'; end if;
  if not public.feature_effective(p_workspace_id, 'purchaseAnalytics') then
    raise exception 'the purchase figures are not enabled for this workspace' using errcode = '42501';
  end if;
  if not (public.has_permission(p_workspace_id, 'manageBilling')
          and public.has_permission(p_workspace_id, 'viewAnalytics')) then
    raise exception 'you may not change the cost allocation' using errcode = '42501';
  end if;
  if p_request_id is null or p_rule is null or jsonb_typeof(p_rule) <> 'object' then
    raise exception 'a rule and a request id are required' using errcode = '22023';
  end if;

  select * into v_done from public.bi_cost_allocation_rules
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if found then return public.cost_allocation_rule_json(v_done); end if;
  perform pg_advisory_xact_lock(hashtext('cost_allocation:' || p_workspace_id::text));

  if p_rule_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then
      raise exception 'a new rule has no revision yet' using errcode = '40001';
    end if;
    v_latest := 0;
  else
    select max(revision) into v_latest from public.bi_cost_allocation_rules
     where workspace_id = p_workspace_id and rule_id = p_rule_id;
    if v_latest is null then raise exception 'unknown allocation rule' using errcode = '22023'; end if;
    if v_latest <> coalesce(p_expected_revision, -1) then
      raise exception 'the rule changed meanwhile: reload it' using errcode = '40001';
    end if;
  end if;

  if (v_line is null) = (v_category = '') then
    raise exception 'a rule scopes one purchase line or one category' using errcode = '22023';
  end if;
  if v_line is not null and not exists (
       select 1 from public.purchase_lines l
        where l.id = v_line and l.workspace_id = p_workspace_id and l.recognition_kind = 'operating') then
    raise exception 'the line is not an operating line of this workspace' using errcode = '22023';
  end if;
  if jsonb_typeof(v_weights) <> 'array' or jsonb_array_length(v_weights) > 100
     or (not v_retired and jsonb_array_length(v_weights) = 0) then
    raise exception 'a rule names between 1 and 100 resources' using errcode = '22023';
  end if;
  for v_w in select * from jsonb_array_elements(v_weights) loop
    if jsonb_typeof(v_w) <> 'object'
       or coalesce(v_w ->> 'resource_kind', '') not in ('level', 'office', 'desk', 'seat')
       or coalesce(v_w ->> 'weight', '') !~ '^[0-9]{1,7}$' then
      raise exception 'a weight names a level, office, desk or seat and a whole number from 0'
        using errcode = '22023';
    end if;
    v_key := (v_w ->> 'resource_kind') || ':' || (v_w ->> 'resource_id');
    if v_key = any(v_seen) then raise exception 'a resource is named twice' using errcode = '22023'; end if;
    v_seen := v_seen || v_key;
    if not exists (
         select 1 from public.levels x where v_w ->> 'resource_kind' = 'level'
            and x.id::text = v_w ->> 'resource_id' and x.workspace_id = p_workspace_id
         union all
         select 1 from public.offices x where v_w ->> 'resource_kind' = 'office'
            and x.id::text = v_w ->> 'resource_id' and x.workspace_id = p_workspace_id
         union all
         select 1 from public.desks x where v_w ->> 'resource_kind' = 'desk'
            and x.id::text = v_w ->> 'resource_id' and x.workspace_id = p_workspace_id
         union all
         select 1 from public.seats x where v_w ->> 'resource_kind' = 'seat'
            and x.id::text = v_w ->> 'resource_id' and x.workspace_id = p_workspace_id) then
      raise exception 'unknown resource %', v_key using errcode = '22023';
    end if;
  end loop;

  insert into public.bi_cost_allocation_rules
    (workspace_id, rule_id, revision, category, purchase_line_id, effective_from, effective_to,
     basis, weights, retired, author_member_id, request_id)
  values (p_workspace_id, coalesce(p_rule_id, gen_random_uuid()), v_latest + 1, v_category, v_line,
          (p_rule ->> 'effective_from')::date, nullif(p_rule ->> 'effective_to', '')::date,
          coalesce(p_rule ->> 'basis', ''),
          (select coalesce(jsonb_agg(jsonb_build_object(
              'resource_kind', e ->> 'resource_kind', 'resource_id', e ->> 'resource_id',
              'weight', (e ->> 'weight')::int)
              order by e ->> 'resource_kind', e ->> 'resource_id'), '[]'::jsonb)
             from jsonb_array_elements(v_weights) e),
          v_retired, v_me, p_request_id)
  returning * into v_row;
  return public.cost_allocation_rule_json(v_row);
end;
$fn$;
revoke execute on function public.save_cost_allocation_rule_v1(uuid, uuid, int, jsonb, uuid) from public, anon;
grant execute on function public.save_cost_allocation_rule_v1(uuid, uuid, int, jsonb, uuid) to authenticated;

create or replace function public.cost_allocation_rules_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'finance.cost_allocation') then
    raise exception 'not allowed to read the cost allocation' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'purchaseAnalytics') then
    raise exception 'the purchase figures are not enabled for this workspace' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(public.cost_allocation_rule_json(r)
                                    order by r.rule_id, r.revision desc)
                     from public.bi_cost_allocation_rules r
                    where r.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.cost_allocation_rules_v1(uuid) from public, anon;
grant execute on function public.cost_allocation_rules_v1(uuid) to authenticated;

create or replace function public.kpi_cost_allocation(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_total bigint; v_direct bigint; v_shared bigint; v_conflicts int; v_mixed boolean;
  v_resources jsonb; v_rules jsonb;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'finance.cost_allocation') then
    raise exception 'not allowed to read the cost allocation of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'purchaseAnalytics') then
    raise exception 'the purchase figures are not enabled for this workspace'
      using errcode = '42501';
  end if;
  if p_from is null or p_to is null
     or p_from !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' or p_to !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or p_from > p_to
     or to_date(p_to, 'YYYY-MM') > to_date(p_from, 'YYYY-MM') + interval '23 months' then
    raise exception 'the KPI months must be YYYY-MM, from <= to, at most 24 months'
      using errcode = '22023';
  end if;
  select w.currency_code, coalesce(nullif(w.timezone, ''), 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  if v_currency is null or btrim(v_currency) = '' then
    raise exception 'the workspace has no currency' using errcode = '22023';
  end if;
  v_now_month := to_char(now() at time zone v_tz, 'YYYY-MM');
  v_start := to_date(p_from, 'YYYY-MM');
  v_cut := (to_date(p_to, 'YYYY-MM') + interval '1 month')::date - 1;

  with lines as (
    -- 0529's cost of an operating line, by the document's date.
    select l.id, d.category, d.currency, coalesce(d.original_date, d.received_on) as dated,
           (case when d.kind = 'credit_note' then -1 else 1 end)
           * (case when l.net_cents is null then l.gross_cents
                   when l.nonrecoverable_tax_cents is null then l.net_cents + l.tax_cents
                   else l.net_cents + l.nonrecoverable_tax_cents end) as cost
      from public.purchase_lines l
      join public.purchase_documents d on d.id = l.purchase_id and d.workspace_id = l.workspace_id
     where l.workspace_id = p_workspace_id and d.state = 'approved'
       and d.kind in ('bill', 'credit_note', 'member_receipt')
       and l.recognition_kind = 'operating'
       and coalesce(d.original_date, d.received_on) between v_start and v_cut
  ), governing as (
    -- For each line and rule: the rule's highest revision in force that day.
    select distinct on (ln.id, r.rule_id) ln.id as line_id, r.*
      from lines ln
      join public.bi_cost_allocation_rules r
        on r.workspace_id = p_workspace_id
       and ln.dated >= r.effective_from and (r.effective_to is null or ln.dated <= r.effective_to)
       and (r.purchase_line_id = ln.id or (r.purchase_line_id is null and r.category = ln.category))
     order by ln.id, r.rule_id, r.revision desc
  ), live as (
    select * from governing g where not g.retired
  ), chosen as (
    -- A line rule beats a category rule; two rules of the same reach conflict.
    select ln.id, ln.cost,
           (select count(*) from live g where g.line_id = ln.id
             and (g.purchase_line_id is not null) = exists (
               select 1 from live g2 where g2.line_id = ln.id and g2.purchase_line_id is not null)) as claims,
           (select g.id from live g where g.line_id = ln.id
             order by (g.purchase_line_id is null), g.rule_id limit 1) as rule_row
      from lines ln
  ), groups as (
    select c.rule_row, sum(c.cost)::bigint as amount
      from chosen c where c.claims = 1
     group by c.rule_row
  ), weights as (
    select gr.rule_row, gr.amount, r.rule_id, r.revision, r.basis,
           w ->> 'resource_kind' as kind, w ->> 'resource_id' as resource_id, (w ->> 'weight')::bigint as weight,
           (sum((w ->> 'weight')::bigint) over (partition by gr.rule_row))::bigint as total_weight,
           count(*) filter (where (w ->> 'weight')::bigint > 0) over (partition by gr.rule_row) as positive
      from groups gr
      join public.bi_cost_allocation_rules r on r.id = gr.rule_row
      cross join lateral jsonb_array_elements(r.weights) w
  ), parts as (
    select wt.*, abs(wt.amount) * wt.weight / wt.total_weight as floor_part,
           abs(wt.amount) * wt.weight % wt.total_weight as remainder
      from weights wt where wt.total_weight > 0
  ), ranked as (
    select p.*, row_number() over (partition by p.rule_row
                                   order by p.remainder desc, p.kind, p.resource_id) as rank,
           abs(p.amount) - (sum(p.floor_part) over (partition by p.rule_row))::bigint as units_left
      from parts p
  ), shares as (
    select rk.rule_row, rk.rule_id, rk.revision, rk.basis, rk.amount, rk.positive, rk.kind, rk.resource_id,
           (case when rk.amount < 0 then -1 else 1 end)
             * (rk.floor_part + case when rk.rank <= rk.units_left then 1 else 0 end) as minor
      from ranked rk
  )
  select coalesce((select sum(cost) from lines), 0),
         coalesce((select sum(s.minor) from shares s where s.positive = 1), 0),
         coalesce((select sum(s.minor) from shares s where s.positive > 1), 0),
         (select count(*) from chosen c where c.claims > 1),
         coalesce((select bool_or(upper(currency) <> upper(v_currency)) from lines), false),
         coalesce((select jsonb_agg(jsonb_build_object(
             'resource_kind', x.kind, 'resource_id', x.resource_id,
             'name', coalesce((select lv.name from public.levels lv where x.kind = 'level' and lv.id::text = x.resource_id),
                              (select o.name from public.offices o where x.kind = 'office' and o.id::text = x.resource_id),
                              (select d.name from public.desks d where x.kind = 'desk' and d.id::text = x.resource_id),
                              (select st.name from public.seats st where x.kind = 'seat' and st.id::text = x.resource_id), ''),
             'allocated_minor', x.minor::text, 'rules', x.rules) order by x.kind, x.resource_id)
            from (select s.kind, s.resource_id, sum(s.minor) as minor,
                         jsonb_agg(distinct jsonb_build_object('rule_id', s.rule_id, 'revision', s.revision)) as rules
                    from shares s where s.minor <> 0
                   group by s.kind, s.resource_id) x), '[]'::jsonb),
         coalesce((select jsonb_agg(jsonb_build_object(
             'rule_id', y.rule_id, 'revision', y.revision, 'basis', y.basis,
             'cost_minor', y.amount::text, 'allocated', y.total_weight > 0)
             order by y.rule_id)
            from (select distinct gr.rule_row, r.rule_id, r.revision, r.basis, gr.amount,
                         (select coalesce(sum((w ->> 'weight')::bigint), 0)
                            from jsonb_array_elements(r.weights) w) as total_weight
                    from groups gr join public.bi_cost_allocation_rules r on r.id = gr.rule_row) y), '[]'::jsonb)
    into v_total, v_direct, v_shared, v_conflicts, v_mixed, v_resources, v_rules;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;
  if v_conflicts > 0 then
    v_reasons := v_reasons || 'rule_conflict'::text;
  end if;
  if v_total - v_direct - v_shared <> 0 then
    v_reasons := v_reasons || 'unallocated'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'finance.cost_allocation', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz,
    'currency', upper(v_currency),
    'operating_costs_minor', v_total::text,
    'direct_minor', v_direct::text,
    'shared_minor', v_shared::text,
    'unallocated_minor', (v_total - v_direct - v_shared)::text,
    'conflicting_lines', v_conflicts,
    'resources', v_resources,
    'rules', v_rules,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_cost_allocation(uuid, text, text) from public, anon;
grant execute on function public.kpi_cost_allocation(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(531);
