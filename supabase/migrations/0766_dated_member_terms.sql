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
--  * The terms of a period are read as of that period, from the store: a
--    statement, a quota check and the default tariff take the share in force
--    on the period's first day, and a month paused on its first day owes no
--    subscription fee (no proration in this version). A change applies to
--    every period whose first day is on or after its date -- the rule a
--    negotiation's `valid_from` already follows.
--  * The sweep applies the changes that are due, on each business's own day,
--    before the invoice run; it catches up in date order after a gap, applies
--    each change once, and revalidates it: a change the member's row refuses
--    on its day is kept as refused, with the reason. A change applied after
--    its first period was invoiced takes effect from the first period not yet
--    invoiced, and says both dates; an issued invoice is never rewritten.
--  * Scheduling and cancelling need the right that changes a member's plan
--    and status today (manageMembers); a validation policy holds a scheduled
--    change as it holds an immediate one, and its approval releases it.
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
  source text not null check (source in ('scheduled', 'immediate')),
  group_id uuid,
  request_id uuid,
  event_id uuid references public.events(id) on delete set null,
  requested_by uuid references public.members(id) on delete set null,
  -- the order changes were made in, also within one transaction
  seq bigint generated always as identity,
  constraint member_term_changes_kind_value check (
    (kind = 'share' and to_pct is not null and to_status is null)
    or (kind = 'status' and to_status is not null and to_pct is null)),
  constraint member_term_changes_scheduled_status check (
    source = 'immediate' or kind = 'share' or to_status in ('active', 'paused')),
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
                where m.id = member_id and m.user_id = auth.uid()));
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

-- ── reading the terms as of a day ─────────────────────────────────────────
-- The share in force on [p_day]: the share before the first change that took
-- effect after that day; else, for a day still to come, the last change
-- scheduled on or before it (the projection); else the member's share now.
create or replace function public.member_share_as_of(p_member_id uuid, p_day date, p_current integer)
returns integer language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select c.from_pct from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'share' and c.state = 'applied'
        and c.effective_on > p_day
      order by c.effective_on, c.seq limit 1),
    (select c.to_pct from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'share' and c.state = 'scheduled'
        and c.due_on <= p_day
      order by c.due_on desc, c.seq desc limit 1),
    p_current)
$fn$;
revoke execute on function public.member_share_as_of(uuid, date, integer) from public, anon, authenticated;

-- Whether the member was (or, for a day still to come, will be) paused on
-- [p_day], read the same way.
create or replace function public.member_paused_on(p_member_id uuid, p_day date, p_current text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select c.from_status from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'status' and c.state = 'applied'
        and c.effective_on > p_day
      order by c.effective_on, c.seq limit 1),
    (select c.to_status from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'status' and c.state = 'scheduled'
        and c.due_on <= p_day
      order by c.due_on desc, c.seq desc limit 1),
    p_current) = 'paused'
$fn$;
revoke execute on function public.member_paused_on(uuid, date, text) from public, anon, authenticated;

-- ── the changes the commands write at once ────────────────────────────────
-- A share written at once counts from the first day of the current period
-- (this month changes, as it always did; months before it keep their terms);
-- a status written at once counts from the business's today.
create or replace function public.members_term_history()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_today date := public.workspace_today(new.workspace_id);
begin
  -- the sweep records the change it applies itself
  if coalesce(current_setting('deskilo.term_change_applying', true), '') = 'on' then
    return new;
  end if;
  if new.subscription_pct is distinct from old.subscription_pct then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct,
      due_on, effective_on, state, source)
    values (new.workspace_id, new.id, 'share', coalesce(new.subscription_pct, 100),
      coalesce(old.subscription_pct, 100), date_trunc('month', v_today)::date,
      date_trunc('month', v_today)::date, 'applied', 'immediate');
  end if;
  if new.status is distinct from old.status then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_status, from_status,
      due_on, effective_on, state, source)
    values (new.workspace_id, new.id, 'status', new.status, old.status, v_today, v_today,
      'applied', 'immediate');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_term_history() from public, anon, authenticated;
drop trigger if exists members_term_history on public.members;
create trigger members_term_history
  after update of subscription_pct, status on public.members
  for each row execute function public.members_term_history();

-- ── applying a change ─────────────────────────────────────────────────────
-- The day a change due on [p_due] takes effect: its date, unless the first
-- period it affects is already invoiced; then the first day of the first
-- period not yet invoiced.
create or replace function public.member_term_effective_on(p_member_id uuid, p_due date)
returns date language plpgsql stable security definer set search_path = public as $fn$
declare
  v_first date := case when extract(day from p_due) = 1 then p_due
                       else (date_trunc('month', p_due) + interval '1 month')::date end;
  v_month date := v_first;
begin
  while exists (select 1 from public.invoices i
                 where i.member_id = p_member_id and i.voided_at is null
                   and i.period = to_char(v_month, 'YYYY-MM')) loop
    v_month := (v_month + interval '1 month')::date;
  end loop;
  return case when v_month = v_first then p_due else v_month end;
end;
$fn$;
revoke execute on function public.member_term_effective_on(uuid, date) from public, anon, authenticated;

-- Applies one due change, once: the member's row takes it (and refuses it when
-- its rules do), and the row says when it was due and when it took effect.
create or replace function public.apply_member_term_change(p_change_id uuid)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.member_term_changes;
  v_m public.members;
  v_effective date;
begin
  select * into v_c from public.member_term_changes where id = p_change_id for update;
  if v_c.id is null or v_c.state <> 'scheduled'
     or v_c.due_on > public.workspace_today(v_c.workspace_id) then
    return coalesce(v_c.state, 'unknown');
  end if;
  select * into v_m from public.members where id = v_c.member_id for update;
  v_effective := public.member_term_effective_on(v_c.member_id, v_c.due_on);
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
       set state = 'refused', reason = left(sqlerrm, 300)
     where id = p_change_id;
    return 'refused';
  end;
  update public.member_term_changes
     set state = 'applied', effective_on = v_effective,
         from_pct = case when kind = 'share' then coalesce(v_m.subscription_pct, 100) end,
         from_status = case when kind = 'status' then v_m.status end
   where id = p_change_id;
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
-- each once. Runs before the invoice run (0142, 06:40 UTC).
create or replace function public.apply_due_member_term_changes()
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_n integer := 0;
begin
  for v_id in
    select c.id from public.member_term_changes c
     where c.state = 'scheduled' and c.due_on <= public.workspace_today(c.workspace_id)
     order by c.due_on, c.seq
  loop
    if public.apply_member_term_change(v_id) in ('applied', 'refused') then v_n := v_n + 1; end if;
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
-- where a validation policy holds plan changes.
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
  select * into v_prior from public.member_term_changes
   where request_id = p_request_id and kind = 'share' limit 1;
  if v_prior.id is not null then
    return jsonb_build_object('change_id', v_prior.id, 'state', v_prior.state, 'replayed', true);
  end if;
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change subscriptions' using errcode = 'DKN01';
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
  v_prior public.member_term_changes;
  v_group uuid := gen_random_uuid();
  v_state text := 'scheduled';
  v_event uuid;
  v_start uuid;
begin
  select * into v_prior from public.member_term_changes
   where request_id = p_request_id and kind = 'status' order by due_on limit 1;
  if v_prior.id is not null then
    return jsonb_build_object('change_id', v_prior.id, 'state', v_prior.state, 'replayed', true);
  end if;
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change memberships' using errcode = 'DKN01';
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
    p_request_id, v_actor.id) returning id into v_start;
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
        'change_id', v_start, 'effective_on', p_from, 'until', p_to), 'pending')
    returning id into v_event;
    update public.member_term_changes set event_id = v_event where group_id = v_group;
    return jsonb_build_object('change_id', v_start, 'state', 'pending', 'event_id', v_event);
  end if;
  return jsonb_build_object('change_id', v_start, 'state', public.apply_member_term_change(v_start));
end;
$fn$;
revoke execute on function public.schedule_member_pause(uuid, date, date, uuid) from public, anon;
grant execute on function public.schedule_member_pause(uuid, date, date, uuid) to authenticated;

-- Cancels a change not yet applied (and the rest of its pause). An applied
-- change is history: it is not cancelled.
create or replace function public.cancel_member_term_change(p_change_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.member_term_changes;
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
-- An approved scheduled change is released to the sweep (applied at once when
-- its date has come); a rejected one is refused, with the reason.
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
    update public.member_term_changes set state = 'scheduled'
     where state = 'pending' and (id = v_change or (v_group is not null and group_id = v_group));
    for v_id in select id from public.member_term_changes
                 where (id = v_change or (v_group is not null and group_id = v_group))
                   and state = 'scheduled' order by due_on loop
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

-- The approval of 0181 writes an immediate change into the member's row; a
-- scheduled one (its payload names the change) is the store's to apply.
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
begin
  -- 1. the approval
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

  -- 2. the statement: the share as of the period, and a month paused on its
  -- first day owes no subscription fee
  v_def := pg_get_functiondef('public.member_statement(uuid, text)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  v_pct := coalesce(v_member.subscription_pct, 100);$r$,
      $r$  -- #3858: the share in force on the period's first day
  v_pct := public.member_share_as_of(p_member_id, v_month_first, coalesce(v_member.subscription_pct, 100));$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in member_statement' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$    v_discount := coalesce(v_neg.discount_percent, 0);
  end;$r$,
      $r$    v_discount := coalesce(v_neg.discount_percent, 0);
  end;
  -- #3858: a month paused on its first day owes no subscription fee
  if public.member_paused_on(p_member_id, v_month_first, v_member.status) then
    v_base := 0;
  end if;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in member_statement' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 3. the quota check: the share as of the booking's period
  v_def := pg_get_functiondef('public.assert_member_quota(uuid, timestamp with time zone)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  v_pct := coalesce(v_member.subscription_pct, 100);$r$,
      $r$  -- #3858: the share in force on the period's first day
  v_pct := public.member_share_as_of(p_member_id, to_date(v_period || '-01', 'YYYY-MM-DD'), coalesce(v_member.subscription_pct, 100));$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in assert_member_quota' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 4. the member's own export carries their dated changes (its own object:
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

  -- 5. erasing a membership cancels what was scheduled for it, with the reason
  v_def := pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  update public.members set status = 'exited', is_admin = false$r$,
      $r$  -- #3858: nothing scheduled for an erased membership fires
  update public.member_term_changes
     set state = 'cancelled', reason = 'the membership was erased'
   where member_id = v_me.id and state in ('pending', 'scheduled');
  update public.members set status = 'exited', is_admin = false$r$);
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

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(766);
