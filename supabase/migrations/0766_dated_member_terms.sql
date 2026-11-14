-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0766 (#3858) -- a member's plan share and pause carry their dates.
--
--  * `member_term_changes` stores every change of a member's share and status:
--    the ones scheduled for a date, and the ones the existing commands write
--    at once (recorded by a trigger). Each row says when it was due, when it
--    took effect, and how it ended: applied, refused with its reason, or
--    cancelled. A pause from one date to another is two rows of one group.
--  * The terms of a period are read as of that period, from the store: the
--    value of the last change in force on the period's first day. A
--    statement, both quota checks and the default tariff take the share in
--    force then; a month paused on its first day owes no subscription fee and
--    includes no half-days (no proration in this version). The invoice run
--    and an invoice decide by the member's state as of the invoiced period,
--    and the run issues a month a member was resumed for after it passed.
--  * The day this migration runs is recorded per member: periods that begin
--    before it read as they did before (no pause effect, today's status for
--    an invoice).
--  * A change takes effect from its date, unless the first period it affects
--    was invoiced before it was scheduled (or approved); then from the first
--    period not yet invoiced, and the row says both dates. An invoice that
--    already carries a change keeps it where it is, and such a change is no
--    longer cancelled. A change written at once takes effect the same way.
--  * The sweep applies the changes that are due, on each business's own day,
--    before the invoice run; in date order after a gap, each once, each on its
--    own: one that fails is kept as refused with the reason and the others go
--    on. A change applies only to a member in the state it starts from; a
--    member who leaves has their waiting changes cancelled.
--  * Scheduling and cancelling need the right that changes a member's plan
--    and status today (manageMembers); a validation policy holds a scheduled
--    change as it holds an immediate one, and its approval releases it. A
--    request id answers its own change again, and only that one.
--  * The rows are the member's own data: readable by the member and by
--    whoever manages members, carried by the member's export, and cancelled
--    with a reason when the member erases their membership.

-- ── the store ─────────────────────────────────────────────────────────────
create table if not exists public.member_term_changes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  kind text not null check (kind in ('share', 'status')),
  to_pct integer check (to_pct between 0 and 100),
  to_status text,
  from_pct integer,
  from_status text,
  due_on date not null,
  effective_on date,
  state text not null default 'scheduled'
    check (state in ('pending', 'scheduled', 'applied', 'refused', 'cancelled')),
  reason text not null default '',
  -- baseline: the member's status on the day this store began (#3858)
  source text not null check (source in ('scheduled', 'immediate', 'baseline')),
  group_id uuid,
  request_id uuid,
  event_id uuid references public.events(id) on delete set null,
  requested_by uuid references public.members(id) on delete set null,
  -- when it was released to apply: scheduled, or approved when it was held
  released_at timestamptz not null default now(),
  -- the order changes were made in, also within one transaction
  seq bigint generated always as identity,
  constraint member_term_changes_kind_value check (
    (kind = 'share' and to_pct is not null and to_status is null)
    or (kind = 'status' and to_status is not null and to_pct is null)),
  constraint member_term_changes_scheduled_status check (
    source <> 'scheduled' or kind = 'share' or to_status in ('active', 'paused')),
  constraint member_term_changes_applied_dated check (
    state <> 'applied' or effective_on is not null)
);
select public.ensure_system_columns('member_term_changes');
comment on table public.member_term_changes is
  '#3858 -- every dated change of a member''s plan share and status: scheduled, or written at once by the commands';
-- one request is one change (a pause: its start and its end)
create unique index if not exists member_term_changes_request_uq
  on public.member_term_changes (request_id, kind, coalesce(to_status, ''), coalesce(to_pct, -1))
  where request_id is not null;
create index if not exists member_term_changes_member_idx
  on public.member_term_changes (member_id, kind, state, effective_on);
create index if not exists member_term_changes_due_idx
  on public.member_term_changes (state, due_on) where state = 'scheduled';

alter table public.member_term_changes enable row level security;
drop policy if exists member_term_changes_select on public.member_term_changes;
create policy member_term_changes_select on public.member_term_changes
  for select using (
    workspace_id in (select public.workspaces_permitting(array['manageMembers']))
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = (select auth.uid())));
drop policy if exists mcp_delegated_deny on public.member_term_changes;
create policy mcp_delegated_deny on public.member_term_changes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke insert, update, delete on public.member_term_changes from anon, authenticated;

-- The business's own day, in its time zone.
create or replace function public.workspace_today(p_workspace_id uuid)
returns date language sql stable security definer set search_path = public as $fn$
  select (now() at time zone coalesce(nullif(w.timezone, ''), 'UTC'))::date
    from public.workspaces w where w.id = p_workspace_id
$fn$;
revoke execute on function public.workspace_today(uuid) from public, anon, authenticated;

-- ── the day the store began ───────────────────────────────────────────────
-- The day the store began for [p_member_id]: the day this migration ran, for
-- a member who existed then; null for one who joined later.
create or replace function public.member_terms_since(p_member_id uuid)
returns date language sql stable security definer set search_path = public as $fn$
  select min(c.effective_on) from public.member_term_changes c
   where c.member_id = p_member_id and c.source = 'baseline'
$fn$;
revoke execute on function public.member_terms_since(uuid) from public, anon, authenticated;

-- Records, once per member, the status each member has on the business's
-- day: the start of their dated terms.
create or replace function public.member_terms_cut_over(p_workspace_id uuid default null)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_n integer;
begin
  insert into public.member_term_changes (workspace_id, member_id, kind, to_status, from_status,
    due_on, effective_on, state, source, reason)
  select m.workspace_id, m.id, 'status', m.status, m.status,
         public.workspace_today(m.workspace_id), public.workspace_today(m.workspace_id),
         'applied', 'baseline', 'the status on the day dated terms began'
    from public.members m
   where (p_workspace_id is null or m.workspace_id = p_workspace_id)
     and not exists (select 1 from public.member_term_changes c
                      where c.member_id = m.id and c.source = 'baseline');
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;
revoke execute on function public.member_terms_cut_over(uuid) from public, anon, authenticated;

-- ── reading the terms as of a day ─────────────────────────────────────────
-- The share in force on [p_day]: the last change in force on that day (an
-- applied one by the day it took effect; for a day still to come, a waiting
-- one by its date); else the share before the first change after the day;
-- else the member's share now.
create or replace function public.member_share_as_of(p_member_id uuid, p_day date, p_current integer)
returns integer language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select x.v from (
       select c.to_pct v, c.effective_on d, c.seq from public.member_term_changes c
        where c.member_id = p_member_id and c.kind = 'share' and c.state = 'applied'
          and c.effective_on <= p_day
       union all
       select c.to_pct, c.due_on, c.seq from public.member_term_changes c
        where c.member_id = p_member_id and c.kind = 'share' and c.state = 'scheduled'
          and c.due_on <= p_day) x
      order by x.d desc, x.seq desc limit 1),
    (select c.from_pct from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'share' and c.state = 'applied'
        and c.effective_on > p_day
      order by c.effective_on, c.seq limit 1),
    p_current)
$fn$;
revoke execute on function public.member_share_as_of(uuid, date, integer) from public, anon, authenticated;

-- Whether the member was (or, for a day still to come, will be) paused on
-- [p_day], read the same way. Before the day the store began for the member,
-- never: those periods read as they did before.
create or replace function public.member_paused_on(p_member_id uuid, p_day date, p_current text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case when p_day < coalesce(public.member_terms_since(p_member_id), p_day) then false
  else coalesce(
    (select x.v from (
       select c.to_status v, c.effective_on d, c.seq from public.member_term_changes c
        where c.member_id = p_member_id and c.kind = 'status' and c.state = 'applied'
          and c.effective_on <= p_day
       union all
       select c.to_status, c.due_on, c.seq from public.member_term_changes c
        where c.member_id = p_member_id and c.kind = 'status' and c.state = 'scheduled'
          and c.due_on <= p_day) x
      order by x.d desc, x.seq desc limit 1),
    (select c.from_status from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'status' and c.state = 'applied'
        and c.effective_on > p_day
      order by c.effective_on, c.seq limit 1),
    p_current) = 'paused' end
$fn$;
revoke execute on function public.member_paused_on(uuid, date, text) from public, anon, authenticated;

-- Whether [p_period] ('YYYY-MM') of the member is invoiced: for a period
-- that began before the store did, as before (an active member); else a
-- member active or paused now who was active on the period's first day --
-- or, for use, resumed within it.
create or replace function public.member_billable_in(p_member_id uuid, p_period text, p_kind text)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_m public.members;
  v_first date;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then return false; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then return v_m.status = 'active'; end if;
  v_first := to_date(p_period || '-01', 'YYYY-MM-DD');
  if v_first < coalesce(public.member_terms_since(p_member_id), v_first) then
    return v_m.status = 'active';
  end if;
  if v_m.status not in ('active', 'paused') then return false; end if;
  if not public.member_paused_on(p_member_id, v_first, v_m.status) then return true; end if;
  return p_kind <> 'subscription' and exists (
    select 1 from public.member_term_changes c
     where c.member_id = p_member_id and c.kind = 'status' and c.state = 'applied'
       and c.to_status = 'active' and c.effective_on > v_first
       and c.effective_on < (v_first + interval '1 month')::date);
end;
$fn$;
revoke execute on function public.member_billable_in(uuid, text, text) from public, anon, authenticated;

-- ── when a change takes effect ────────────────────────────────────────────
-- The day a change due on [p_due], released at [p_since], takes effect: its
-- date, unless the first period it affects was invoiced before it was
-- released; then the first day of the first period not so invoiced. An
-- invoice issued after the release already carries the change.
create or replace function public.member_term_effective_on(p_member_id uuid, p_due date, p_since timestamptz)
returns date language plpgsql stable security definer set search_path = public as $fn$
declare
  v_first date := case when extract(day from p_due) = 1 then p_due
                       else (date_trunc('month', p_due) + interval '1 month')::date end;
  v_month date := v_first;
begin
  while exists (select 1 from public.invoices i
                 where i.member_id = p_member_id and i.voided_at is null
                   and i.period = to_char(v_month, 'YYYY-MM')
                   and i.issued_at <= p_since) loop
    v_month := (v_month + interval '1 month')::date;
  end loop;
  return case when v_month = v_first then p_due else v_month end;
end;
$fn$;
revoke execute on function public.member_term_effective_on(uuid, date, timestamptz) from public, anon, authenticated;

-- ── the changes the commands write at once ────────────────────────────────
-- A share written at once counts from the first period of this month on
-- that is not yet invoiced; a status from today, or from the first period
-- not yet invoiced. A member who leaves has their waiting changes cancelled.
create or replace function public.members_term_history()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_today date := public.workspace_today(new.workspace_id);
  v_month date := date_trunc('month', v_today)::date;
begin
  if new.status = 'exited' and old.status is distinct from 'exited' then
    update public.member_term_changes
       set state = 'cancelled', reason = 'the member left'
     where member_id = new.id and state in ('pending', 'scheduled');
  end if;
  -- the sweep and an erasure record (or leave out) the change themselves
  if coalesce(current_setting('deskilo.term_change_applying', true), '') = 'on' then
    return new;
  end if;
  if new.subscription_pct is distinct from old.subscription_pct then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct,
      due_on, effective_on, state, source)
    values (new.workspace_id, new.id, 'share', coalesce(new.subscription_pct, 100),
      coalesce(old.subscription_pct, 100), v_month,
      public.member_term_effective_on(new.id, v_month, now()), 'applied', 'immediate');
  end if;
  if new.status is distinct from old.status then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_status, from_status,
      due_on, effective_on, state, source)
    values (new.workspace_id, new.id, 'status', new.status, old.status, v_today,
      public.member_term_effective_on(new.id, v_today, now()), 'applied', 'immediate');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_term_history() from public, anon, authenticated;
-- Named to fire before members_rebalance_credits (triggers of one event run
-- in name order): the rebalance reads the share just recorded.
drop trigger if exists members_term_history on public.members;
drop trigger if exists members_dated_terms on public.members;
create trigger members_dated_terms
  after update of subscription_pct, status on public.members
  for each row execute function public.members_term_history();

-- ── applying a change ─────────────────────────────────────────────────────
-- Applies one due change, once: the member's row takes it (and refuses it when
-- its rules do), and the row says when it was due and when it took effect.
create or replace function public.apply_member_term_change(p_change_id uuid)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.member_term_changes;
  v_m public.members;
  v_effective date;
  v_refusal text;
begin
  select * into v_c from public.member_term_changes where id = p_change_id for update;
  if v_c.id is null or v_c.state <> 'scheduled'
     or v_c.due_on > public.workspace_today(v_c.workspace_id) then
    return coalesce(v_c.state, 'unknown');
  end if;
  select * into v_m from public.members where id = v_c.member_id for update;
  -- the rules of an immediate change hold on the change's day, and a change
  -- applies only to a member in the state it starts from
  v_refusal := case
    when v_m.status not in ('active', 'paused') then 'the membership has ended'
    when v_c.kind = 'status' and v_m.is_owner then 'an owner hands the workspace over first'
    when v_c.kind = 'status' and v_c.to_status = 'paused' and v_m.status <> 'active' then 'the member is not active'
    when v_c.kind = 'status' and v_c.to_status = 'active' and v_m.status <> 'paused' then 'the member is not paused'
  end;
  if v_refusal is not null then
    update public.member_term_changes set state = 'refused', reason = v_refusal where id = p_change_id;
    return 'refused';
  end if;
  v_effective := public.member_term_effective_on(v_c.member_id, v_c.due_on, v_c.released_at);
  -- recorded first: what the member's row triggers (the credit rebalance)
  -- reads the terms with this change in force
  update public.member_term_changes
     set state = 'applied', effective_on = v_effective,
         from_pct = case when kind = 'share' then coalesce(v_m.subscription_pct, 100) end,
         from_status = case when kind = 'status' then v_m.status end
   where id = p_change_id;
  begin
    perform set_config('deskilo.term_change_applying', 'on', true);
    if v_c.kind = 'share' then
      update public.members set subscription_pct = v_c.to_pct where id = v_c.member_id;
    else
      update public.members set status = v_c.to_status where id = v_c.member_id;
    end if;
    perform set_config('deskilo.term_change_applying', '', true);
  exception when others then
    perform set_config('deskilo.term_change_applying', '', true);
    update public.member_term_changes
       set state = 'refused', reason = left(sqlerrm, 300), effective_on = null
     where id = p_change_id;
    return 'refused';
  end;
  perform public.record_applied_event(v_c.workspace_id,
    case when v_c.kind = 'share' then 'subscription_change' else 'member_status_change' end,
    -- whoever scheduled it; the member, when that person is gone
    coalesce(v_c.requested_by, v_c.member_id), v_c.member_id,
    jsonb_build_object('member_id', v_c.member_id, 'change_id', v_c.id,
      'before', case when v_c.kind = 'share' then to_jsonb(coalesce(v_m.subscription_pct, 100))
                     else to_jsonb(v_m.status) end,
      'after', case when v_c.kind = 'share' then to_jsonb(v_c.to_pct) else to_jsonb(v_c.to_status) end,
      'due_on', v_c.due_on, 'effective_on', v_effective));
  return 'applied';
end;
$fn$;
revoke execute on function public.apply_member_term_change(uuid) from public, anon, authenticated;

-- The sweep: every change due up to each business's own today, in date order,
-- each once and each on its own: one that fails is kept as refused with the
-- reason, and the others go on. Runs before the invoice run (06:40 UTC).
create or replace function public.apply_due_member_term_changes()
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_state text;
  v_reason text;
  v_n integer := 0;
begin
  for v_id in
    select c.id from public.member_term_changes c
     where c.state = 'scheduled' and c.due_on <= public.workspace_today(c.workspace_id)
     order by c.due_on, c.seq
  loop
    begin
      v_state := public.apply_member_term_change(v_id);
    exception when others then
      v_reason := left(sqlerrm, 300);
      perform set_config('deskilo.term_change_applying', '', true);
      update public.member_term_changes set state = 'refused', reason = v_reason
       where id = v_id and state = 'scheduled';
      v_state := 'refused';
    end;
    if v_state in ('applied', 'refused') then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end;
$fn$;
revoke execute on function public.apply_due_member_term_changes() from public, anon, authenticated;

do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'deskilo-member-terms';
    perform cron.schedule('deskilo-member-terms', '30 6 * * *',
      'select public.apply_due_member_term_changes()');
  end if;
end
$cron$;

-- ── the commands ──────────────────────────────────────────────────────────
-- Schedules a share for [p_effective_on] (today or later). Held for approval
-- where a validation policy holds plan changes. A request id answers its own
-- change again; used with other values, it is refused.
create or replace function public.schedule_member_share_change(
  p_member_id uuid, p_pct integer, p_effective_on date, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_m public.members;
  v_actor public.members;
  v_prior public.member_term_changes;
  v_id uuid;
  v_event uuid;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change subscriptions' using errcode = 'DKN01';
  end if;
  if p_request_id is null then raise exception 'a request id is required' using errcode = '22023'; end if;
  select * into v_prior from public.member_term_changes where request_id = p_request_id limit 1;
  if v_prior.id is not null then
    if v_prior.member_id = p_member_id and v_prior.kind = 'share'
       and v_prior.to_pct = p_pct and v_prior.due_on = p_effective_on then
      return jsonb_build_object('change_id', v_prior.id, 'state', v_prior.state, 'replayed', true);
    end if;
    raise exception 'this request id belongs to another change' using errcode = '22023';
  end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if p_pct is null or p_pct < 0 or p_pct > 100 then
    raise exception 'pct out of range' using errcode = '22023';
  end if;
  if p_effective_on is null or p_effective_on < public.workspace_today(v_m.workspace_id) then
    raise exception 'a change is scheduled for today or later' using errcode = '22023';
  end if;
  if public.validation_requires(v_m.workspace_id, 'subscription_change', 0) then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state,
      source, request_id, requested_by)
    values (v_m.workspace_id, p_member_id, 'share', p_pct, p_effective_on, 'pending', 'scheduled',
      p_request_id, v_actor.id) returning id into v_id;
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'subscription_change', 'submitted', v_actor.id, p_member_id,
      jsonb_build_object('member_id', p_member_id, 'before', v_m.subscription_pct, 'after', p_pct,
        'change_id', v_id, 'effective_on', p_effective_on), 'pending')
    returning id into v_event;
    update public.member_term_changes set event_id = v_event where id = v_id;
    return jsonb_build_object('change_id', v_id, 'state', 'pending', 'event_id', v_event);
  end if;
  insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state,
    source, request_id, requested_by)
  values (v_m.workspace_id, p_member_id, 'share', p_pct, p_effective_on, 'scheduled', 'scheduled',
    p_request_id, v_actor.id) returning id into v_id;
  return jsonb_build_object('change_id', v_id, 'state', public.apply_member_term_change(v_id));
end;
$fn$;
revoke execute on function public.schedule_member_share_change(uuid, integer, date, uuid) from public, anon;
grant execute on function public.schedule_member_share_change(uuid, integer, date, uuid) to authenticated;

-- Schedules a pause from [p_from] (today or later) until [p_to] (the member is
-- active again that day; null: until resumed). Held for approval where a
-- validation policy holds status changes.
create or replace function public.schedule_member_pause(
  p_member_id uuid, p_from date, p_to date, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_m public.members;
  v_actor public.members;
  v_start public.member_term_changes;
  v_end_on date;
  v_group uuid := gen_random_uuid();
  v_state text := 'scheduled';
  v_event uuid;
  v_id uuid;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change memberships' using errcode = 'DKN01';
  end if;
  if p_request_id is null then raise exception 'a request id is required' using errcode = '22023'; end if;
  select * into v_start from public.member_term_changes
   where request_id = p_request_id order by due_on, seq limit 1;
  if v_start.id is not null then
    select c.due_on into v_end_on from public.member_term_changes c
     where c.request_id = p_request_id and c.id <> v_start.id;
    if v_start.member_id = p_member_id and v_start.kind = 'status' and v_start.to_status = 'paused'
       and v_start.due_on = p_from and v_end_on is not distinct from p_to then
      return jsonb_build_object('change_id', v_start.id, 'state', v_start.state, 'replayed', true);
    end if;
    raise exception 'this request id belongs to another change' using errcode = '22023';
  end if;
  -- as for an immediate status change (0181): an owner is not paused
  if v_m.is_owner then
    raise exception 'an owner hands the workspace over first' using errcode = 'DKN01';
  end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if p_from is null or p_from < public.workspace_today(v_m.workspace_id) then
    raise exception 'a change is scheduled for today or later' using errcode = '22023';
  end if;
  if p_to is not null and p_to <= p_from then
    raise exception 'a pause ends after it starts' using errcode = '22023';
  end if;
  if public.validation_requires(v_m.workspace_id, 'member_status_change', 0) then
    v_state := 'pending';
  end if;
  insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state,
    source, group_id, request_id, requested_by)
  values (v_m.workspace_id, p_member_id, 'status', 'paused', p_from, v_state, 'scheduled', v_group,
    p_request_id, v_actor.id) returning id into v_id;
  if p_to is not null then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state,
      source, group_id, request_id, requested_by)
    values (v_m.workspace_id, p_member_id, 'status', 'active', p_to, v_state, 'scheduled', v_group,
      p_request_id, v_actor.id);
  end if;
  if v_state = 'pending' then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'member_status_change', 'submitted', v_actor.id, p_member_id,
      jsonb_build_object('member_id', p_member_id, 'before', v_m.status, 'after', 'paused',
        'change_id', v_id, 'effective_on', p_from, 'until', p_to), 'pending')
    returning id into v_event;
    update public.member_term_changes set event_id = v_event where group_id = v_group;
    return jsonb_build_object('change_id', v_id, 'state', 'pending', 'event_id', v_event);
  end if;
  return jsonb_build_object('change_id', v_id, 'state', public.apply_member_term_change(v_id));
end;
$fn$;
revoke execute on function public.schedule_member_pause(uuid, date, date, uuid) from public, anon;
grant execute on function public.schedule_member_pause(uuid, date, date, uuid) to authenticated;

-- Cancels a change not yet applied (and the rest of its pause). An applied
-- change is history; a change already on an invoice -- or a pause the
-- invoice run has already left its first month out for -- stays: a new
-- change is scheduled instead.
create or replace function public.cancel_member_term_change(p_change_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.member_term_changes;
  v_advance integer;
  v_n integer;
begin
  select * into v_c from public.member_term_changes where id = p_change_id;
  if v_c.id is null then raise exception 'unknown change' using errcode = '22023'; end if;
  if not public.has_permission(v_c.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change memberships' using errcode = 'DKN01';
  end if;
  if v_c.state not in ('pending', 'scheduled') then
    raise exception 'only a change not yet applied is cancelled' using errcode = '55000';
  end if;
  select least(greatest(coalesce((w.billing_rules ->> 'subscription_advance_days')::int, 3), 0), 28)
    into v_advance from public.workspaces w where w.id = v_c.workspace_id;
  if exists (
    select 1 from public.member_term_changes c
     cross join lateral (select case when extract(day from c.due_on) = 1 then c.due_on
              else (date_trunc('month', c.due_on) + interval '1 month')::date end as first) f
     where c.state in ('pending', 'scheduled')
       and (c.id = p_change_id or (v_c.group_id is not null and c.group_id = v_c.group_id))
       and (exists (select 1 from public.invoices i
                     where i.member_id = c.member_id and i.voided_at is null
                       and i.period = to_char(f.first, 'YYYY-MM'))
            or (c.kind = 'status' and c.to_status = 'paused'
                and public.workspace_today(c.workspace_id) >= f.first - v_advance))) then
    raise exception 'this change is already on an invoice — schedule a new one' using errcode = '55000';
  end if;
  update public.member_term_changes
     set state = 'cancelled', reason = 'cancelled'
   where state in ('pending', 'scheduled')
     and (id = p_change_id or (v_c.group_id is not null and group_id = v_c.group_id));
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;
revoke execute on function public.cancel_member_term_change(uuid) from public, anon;
grant execute on function public.cancel_member_term_change(uuid) to authenticated;

-- ── the decision on a held change ─────────────────────────────────────────
-- An approved scheduled change is released (applied at once when its date
-- has come); a rejected one is refused, with the reason.
create or replace function public.member_term_changes_decided()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_change uuid := (new.payload ->> 'change_id')::uuid;
  v_group uuid;
  v_id uuid;
begin
  if new.status = old.status or v_change is null
     or new.type not in ('subscription_change', 'member_status_change') then
    return new;
  end if;
  select group_id into v_group from public.member_term_changes where id = v_change;
  if new.status = 'confirmed' then
    update public.member_term_changes set state = 'scheduled', released_at = now()
     where state = 'pending' and (id = v_change or (v_group is not null and group_id = v_group));
    for v_id in select id from public.member_term_changes
                 where (id = v_change or (v_group is not null and group_id = v_group))
                   and state = 'scheduled' order by due_on, seq loop
      perform public.apply_member_term_change(v_id);
    end loop;
  elsif new.status = 'rejected' then
    update public.member_term_changes set state = 'refused', reason = 'not approved'
     where state = 'pending' and (id = v_change or (v_group is not null and group_id = v_group));
  end if;
  return new;
end;
$fn$;
revoke execute on function public.member_term_changes_decided() from public, anon, authenticated;
drop trigger if exists events_member_term_changes_decided on public.events;
create trigger events_member_term_changes_decided
  after update on public.events
  for each row execute function public.member_term_changes_decided();

-- Every member there is today starts their dated terms today.
select public.member_terms_cut_over();

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_fn text;
begin
  -- 1. the approval of 0181 writes an immediate change into the member's
  -- row; a scheduled one (its payload names the change) is the store's
  v_def := pg_get_functiondef('public.apply_validated_decision_0181()'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$    when 'member_status_change' then update public.members set status = new.payload->>'after' where id = (new.payload->>'member_id')::uuid;$r$,
      $r$    when 'member_status_change' then
      -- #3858: a scheduled change is the store's to apply
      if not (new.payload ? 'change_id') then
        update public.members set status = new.payload->>'after' where id = (new.payload->>'member_id')::uuid;
      end if;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in apply_validated_decision_0181' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$    when 'subscription_change' then update public.members set subscription_pct = (new.payload->>'after')::int where id = (new.payload->>'member_id')::uuid;$r$,
      $r$    when 'subscription_change' then
      if not (new.payload ? 'change_id') then
        update public.members set subscription_pct = (new.payload->>'after')::int where id = (new.payload->>'member_id')::uuid;
      end if;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in apply_validated_decision_0181' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 2. the statement and both quota checks: the share in force on the
  -- period's first day; a month paused on its first day owes no subscription
  -- fee and includes no half-days
  foreach v_fn in array array['public.member_statement(uuid, text)',
                              'public.assert_member_quota(uuid, timestamp with time zone)',
                              'public.member_quota_shortfall(uuid, timestamp with time zone)'] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if position('#3858' in v_def) = 0 then
      v_def := pg_temp.anchor_replace(v_def,
        $r$  v_pct := coalesce(v_member.subscription_pct, 100);$r$,
        $r$  -- #3858: the share in force on the period's first day
  v_pct := public.member_share_as_of(v_member.id, v_month_first, coalesce(v_member.subscription_pct, 100));$r$);
      if v_def is null then raise exception 'an anchor of #3858 was not found in %', v_fn using errcode = 'P0001'; end if;
      v_def := pg_temp.anchor_replace(v_def,
        $r$  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;$r$,
        $r$  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;
  -- #3858: a month paused on its first day owes no fee and includes nothing
  if public.member_paused_on(v_member.id, v_month_first, v_member.status) then
    v_included := 0;
    $r$ || case when v_fn like 'public.member_statement%' then 'v_base := 0;' else 'null;' end || $r$
  end if;$r$);
      if v_def is null then raise exception 'an anchor of #3858 was not found in %', v_fn using errcode = 'P0001'; end if;
      execute v_def;
    end if;
  end loop;

  -- 3. an invoice is for a member active (or resumed, for use) in its period
  v_def := pg_get_functiondef('public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text, text)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;$r$,
      $r$    where id = p_member_id and workspace_id = p_workspace_id
      -- #3858: the member's state as of the invoiced period
      and public.member_billable_in(id, p_period, p_kind) and not is_kiosk;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in create_invoice' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 4. the invoice run: members active or paused now, each decided as of the
  -- invoiced period; a month a member was resumed for after the run passed it
  v_def := pg_get_functiondef('public.sweep_billing_invoices(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$       where m.workspace_id = v_ws.id and m.status = 'active' and not m.is_kiosk$r$,
      $r$       where m.workspace_id = v_ws.id and m.status in ('active', 'paused') and not m.is_kiosk -- #3858$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$      if coalesce((v_rules ->> 'usage_auto')::boolean, true)$r$,
      $r$      -- #3858: this month, for a member resumed for it after the run passed it
      if coalesce((v_rules ->> 'subscription_auto')::boolean, true)
         and public.feature_effective_in(v_flags, 'subscriptionInvoices')
         and exists (select 1 from public.member_term_changes c
                      where c.member_id = v_member.id and c.kind = 'status'
                        and c.to_status = 'active' and c.state = 'applied'
                        and c.effective_on > date_trunc('month', v_today)::date - (v_advance + 1)
                        and c.effective_on <= v_today)
      then
        begin
          perform public.create_invoice(
            v_ws.id, v_member.id, to_char(v_today, 'YYYY-MM'), null, false,
            'subscription', false);
          v_total := v_total + 1;
        exception when others then
          null;
        end;
      end if;

      if coalesce((v_rules ->> 'usage_auto')::boolean, true)$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 5. the member's own export carries their dated changes (its own object:
  -- the export's single call is at the argument limit)
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  return jsonb_build_object(
    'exported_at', now(),$r$,
      $r$  -- #3858: their dated plan changes and pauses
  return jsonb_build_object('term_changes',
    (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.member_term_changes t
      where t.member_id = v_me.id)) || jsonb_build_object(
    'exported_at', now(),$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in export_my_data' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 6. erasing a membership cancels what was scheduled for it, with the
  -- reason, and its own status change is not recorded as a term
  v_def := pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  update public.members set status = 'exited', is_admin = false
   where id = v_me.id;$r$,
      $r$  -- #3858: nothing scheduled for an erased membership fires
  update public.member_term_changes
     set state = 'cancelled', reason = 'the membership was erased'
   where member_id = v_me.id and state in ('pending', 'scheduled');
  perform set_config('deskilo.term_change_applying', 'on', true);
  update public.members set status = 'exited', is_admin = false
   where id = v_me.id;
  perform set_config('deskilo.term_change_applying', '', true);$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in erase_my_membership' using errcode = 'P0001'; end if;
    execute v_def;
  end if;
end
$migration$;

-- The default tariff (0210), restated whole: the share in force in the
-- current period.
create or replace function public.default_tariff_of(p_member_id uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $function$
  select coalesce((select jsonb_build_object('fee_cents', b.fee_cents, 'overage_fee_cents', b.overage_fee_cents)
       from public.members m
       cross join lateral (select public.member_share_as_of(m.id,
              date_trunc('month', public.workspace_today(m.workspace_id))::date,
              coalesce(m.subscription_pct, 100)) as pct) s
       join public.fee_bands b on b.workspace_id = m.workspace_id
        and b.from_pct < s.pct and s.pct <= b.to_pct
      where m.id = p_member_id
        and public.is_member_of(m.workspace_id)
      limit 1), jsonb_build_object('fee_cents', 0, 'overage_fee_cents', 0));
$function$;
revoke execute on function public.default_tariff_of(uuid) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(766);
