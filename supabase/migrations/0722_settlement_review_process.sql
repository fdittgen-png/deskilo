-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (an event type, three columns on provider_settlement_reviews, an alert
--  and a hand-off RPC; the recorder restated with the alert)
--
-- #3510 (second pull request) -- a refused settlement report becomes a
-- process before a schedule reads settlements by itself:
--
--  * a handled review is history: only waiting reviews are unique per
--    settlement and reason; the same report after a hand-off writes nothing,
--    a different one is a new waiting review and is told;
--  * someone is told: a review kept for the first time raises a
--    `settlement_review` event to every active member who may see the
--    finances (viewFinances), once per settlement and reason. The workspace's
--    owner is its actor (the recorder runs as the service role and has no
--    member of its own); the event is applied, nothing waits on it;
--  * a review ends: mark_settlement_review_handled_v1 records who handled
--    it, when and a note (billing managers, manageBilling). A handled review
--    leaves the waiting list and stays readable. Nothing is accepted
--    automatically: replacing recorded amounts is an accounting correction
--    and goes through the existing correction path;
--  * the recorder is restated from 0720 (live on dev) with the alert only.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  r record;
begin
  -- the new event type: both type checks, as 0666 did
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name;
    end if;
    if position('settlement_review' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'settlement_review'));
    end if;
  end loop;

  -- who reads it: whoever may see the finances
  select pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure) into v_def;
  if position('settlement_review' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $a$when p_type = 'privacy_incident'
      then array['managePrivacy']$a$,
      $a$when p_type = 'privacy_incident'
      then array['managePrivacy']
    when p_type = 'settlement_review'
      then array['viewFinances']$a$);
    if v_def is null then raise exception '0722: event_type_view_permissions anchor missing'; end if;
    execute v_def;
  end if;
end
$migration$;

alter table public.provider_settlement_reviews
  add column if not exists handled_at timestamptz,
  add column if not exists handled_by uuid references auth.users(id) on delete set null,
  add column if not exists handled_note text;
-- A handled review is history and is never written again: only WAITING
-- reviews are unique per settlement and reason (0720's constraint held them
-- unique for ever, so a later report overwrote a handled one).
do $unique$
declare v_name text;
begin
  for v_name in select conname from pg_constraint
                 where conrelid = 'public.provider_settlement_reviews'::regclass and contype = 'u' loop
    execute format('alter table public.provider_settlement_reviews drop constraint %I', v_name);
  end loop;
end
$unique$;
create unique index if not exists provider_settlement_reviews_waiting
  on public.provider_settlement_reviews (workspace_id, provider, settlement_id, reason)
  where handled_at is null;

alter table public.provider_settlement_reviews
  drop constraint if exists provider_settlement_reviews_handled_note;
alter table public.provider_settlement_reviews
  add constraint provider_settlement_reviews_handled_note
  check ((handled_at is null) = (handled_note is null)
         and (handled_note is null or length(btrim(handled_note)) between 1 and 1000));

-- One event per member who may see the finances, the owner as actor.
create or replace function public.alert_settlement_review(p_review_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_review public.provider_settlement_reviews;
  v_owner uuid;
  v_told integer;
begin
  select * into v_review from public.provider_settlement_reviews where id = p_review_id;
  if v_review.id is null then return 0; end if;
  select m.id into v_owner from public.members m
   where m.workspace_id = v_review.workspace_id and m.is_owner and m.status = 'active'
   order by m.id limit 1;
  if v_owner is null then return 0; end if;
  with told as (
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    select v_review.workspace_id, 'settlement_review', 'created', v_owner, h.id,
           jsonb_build_object('review_id', v_review.id, 'provider', v_review.provider,
                              'settlement_id', v_review.settlement_id, 'reason', v_review.reason),
           'applied'
      from public.members h
     where h.workspace_id = v_review.workspace_id and h.status = 'active'
       and public.member_has_permission(h.id, 'viewFinances')
    returning 1)
  select count(*) into v_told from told;
  return v_told;
end;
$fn$;
revoke execute on function public.alert_settlement_review(uuid) from public, anon, authenticated;

create or replace function public.mark_settlement_review_handled_v1(p_review_id uuid, p_note text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_review public.provider_settlement_reviews;
  v_note text := btrim(coalesce(p_note, ''));
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_review from public.provider_settlement_reviews where id = p_review_id for update;
  if v_review.id is null or not public.has_permission(v_review.workspace_id, 'manageBilling') then
    raise exception 'unknown review' using errcode = '42501';
  end if;
  if length(v_note) not between 1 and 1000 then
    raise exception 'a note of 1 to 1000 characters is required' using errcode = '22023';
  end if;
  if v_review.handled_at is not null then
    return jsonb_build_object('handled', false, 'handled_at', v_review.handled_at);
  end if;
  update public.provider_settlement_reviews
     set handled_at = now(), handled_by = auth.uid(), handled_note = v_note
   where id = p_review_id;
  return jsonb_build_object('handled', true);
end;
$fn$;
revoke execute on function public.mark_settlement_review_handled_v1(uuid, text) from public, anon;
grant execute on function public.mark_settlement_review_handled_v1(uuid, text) to authenticated;

create or replace function public.record_provider_settlement_v1(
  p_workspace_id uuid,
  p_provider text,
  p_settlement_id text,
  p_amount_cents bigint,
  p_currency text,
  p_arrival_date date,
  p_status text,
  p_costs jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_currency text := upper(coalesce(p_currency, ''));
  v_costs jsonb;
  v_payout public.provider_payouts;
  v_reason text;
  v_answer jsonb;
  v_n int := 0;
  v_review uuid;
  v_first boolean;
  v_reported jsonb;
begin
  -- Two reports of one settlement at the same moment (the on-demand fetch
  -- beside a scheduled poll): the second waits here and then reads what the
  -- first booked, so it answers "unchanged" instead of inserting the costs
  -- again into a unique violation.
  perform pg_advisory_xact_lock(hashtextextended(
    'provider_settlement:' || p_workspace_id::text || '|' || p_provider || '|' || p_settlement_id, 0));

  -- The report's costs in the canonical form: a cost names its own currency
  -- or is in the settlement's; lines with the same period, method,
  -- description and currency (the same fee at two rates in one month) are
  -- one cost with their counts and nets summed, as the table keeps one row
  -- per period, method and description. Nothing reported is lost, and the
  -- comparison stays total.
  select coalesce(jsonb_agg(jsonb_build_object(
           'period', g.period, 'method', g.method, 'description', g.description,
           'cost_count', g.cost_count, 'amount_net_cents', g.amount_net_cents, 'currency', g.currency)
         order by g.period, g.method, g.description, g.currency), '[]'::jsonb)
    into v_costs
    from (select x.period, coalesce(x.method, '') as method, coalesce(x.description, '') as description,
                 upper(coalesce(nullif(x.currency, ''), v_currency)) as currency,
                 sum(x.cost_count)::int as cost_count, sum(x.amount_net_cents)::bigint as amount_net_cents
            from jsonb_to_recordset(coalesce(p_costs, '[]'::jsonb))
                 as x(period text, method text, description text, cost_count int, amount_net_cents bigint, currency text)
           group by 1, 2, 3, 4) g;

  select * into v_payout from public.provider_payouts
   where workspace_id = p_workspace_id and provider = p_provider and payout_id = p_settlement_id;
  if exists (select 1 from jsonb_array_elements(v_costs) c where c ->> 'currency' <> v_currency) then
    v_reason := 'currency_mismatch';
  elsif v_payout.id is not null
        and (v_payout.amount_cents, v_payout.currency) is distinct from (p_amount_cents, v_currency) then
    v_reason := 'amount_changed';
  elsif v_payout.id is not null
        and public.provider_settlement_cost_set(p_workspace_id, p_provider, p_settlement_id) <> v_costs then
    v_reason := 'costs_changed';
  end if;

  if v_reason is not null then
    v_reported := jsonb_build_object('amount_cents', p_amount_cents, 'currency', v_currency,
                                     'arrival_date', p_arrival_date, 'status', p_status, 'costs', v_costs);
    -- The provider repeating, after a person dealt with it, the report of
    -- the latest handled review (no review of this kind waiting): nothing is
    -- written and no one is told. A different report becomes a new waiting
    -- review below; a waiting one keeps absorbing newer reports silently.
    -- The settlement's lock is held, so this read is safe.
    if not exists (select 1 from public.provider_settlement_reviews
                    where workspace_id = p_workspace_id and provider = p_provider
                      and settlement_id = p_settlement_id and reason = v_reason
                      and handled_at is null)
       and (select r.reported from public.provider_settlement_reviews r
             where r.workspace_id = p_workspace_id and r.provider = p_provider
               and r.settlement_id = p_settlement_id and r.reason = v_reason
             order by r.handled_at desc limit 1) = v_reported then
      return jsonb_build_object('outcome', 'refused', 'reason', v_reason, 'costs_added', 0);
    end if;
    insert into public.provider_settlement_reviews
      (workspace_id, provider, settlement_id, reason, reported)
    values (p_workspace_id, p_provider, p_settlement_id, v_reason, v_reported)
    on conflict (workspace_id, provider, settlement_id, reason) where handled_at is null do update
      set reported = excluded.reported, last_reported_at = now()
    returning id, (xmax = 0) into v_review, v_first;
    -- #3510: the people who may see the finances are told once per
    -- settlement and reason, when the review is first kept.
    if v_first then
      perform public.alert_settlement_review(v_review);
    end if;
    return jsonb_build_object('outcome', 'refused', 'reason', v_reason, 'costs_added', 0);
  end if;

  v_answer := public.record_provider_payout_v1(
    p_workspace_id, p_provider, p_settlement_id, p_amount_cents, v_currency, p_arrival_date, p_status, '{}'::text[]);
  if v_payout.id is null then
    insert into public.provider_settlement_costs
      (workspace_id, provider, settlement_id, period, method, description, cost_count, amount_net_cents, currency)
    select p_workspace_id, p_provider, p_settlement_id, c ->> 'period', c ->> 'method', c ->> 'description',
           (c ->> 'cost_count')::int, (c ->> 'amount_net_cents')::bigint, c ->> 'currency'
      from jsonb_array_elements(v_costs) c;
    get diagnostics v_n = row_count;
    return v_answer || jsonb_build_object('outcome', 'new', 'costs_added', v_n);
  end if;
  return v_answer || jsonb_build_object('outcome', 'unchanged', 'costs_added', 0);
end;
$fn$;
revoke execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb) to service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(722);
