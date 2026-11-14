-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0766 (#3858) -- a member's plan share and pause carry their dates.
--
-- The model:
--  * One clock. A change is applied on its date and is in force from that
--    date. `member_term_changes` stores every change of a member's share and
--    status -- scheduled for a date, or written at once by the commands --
--    with its date, the day it was applied, and how it ended: applied,
--    refused with its reason, or cancelled. A pause from one date to another
--    is two rows of one group.
--  * An invoice freezes its period. A subscription (or full) invoice stores
--    the terms it was computed with in `member_period_terms`: the share,
--    whether the member was paused on the period's first day, the fee and
--    the included half-days. The statement and both quota checks read those
--    terms for an invoiced period. A period invoiced before this migration
--    has none and reads the member's row, exactly as before. A period not
--    invoiced reads the terms as of its first day: the changes applied or
--    scheduled with a date on or before it (of one date, the last released),
--    else the member's row -- for a month before the current one that no
--    change covers, not paused, as before. A voided
--    invoice unfreezes its period; a replacement freezes what it recomputes,
--    which reads the terms as of the period's first day, so only a change
--    dated on or before that day enters it.
--  * A period not invoiced: paused on its first day, no subscription fee and
--    no included half-days; otherwise the full fee and quota of the share in
--    force that day. Nothing is prorated. Use is always invoiceable.
--  * A share change's date is a period's first day, after the last invoiced
--    period from that month on. An explicit date that is not one is refused
--    with the earliest it can take. The immediate share command has no date
--    of its own: it takes the first day of the current period when nothing
--    from it on is invoiced, else the first day after the last invoiced
--    period, and then waits for that day. An approval dates a held change
--    the same way as of the approval (a pause starts no earlier than that
--    day). The answer and the event say the date. The share and the status
--    change only through the commands: a direct write from the API is
--    refused, and an accepted deal goes through the immediate command.
--  * A pause is operational at once and never rewrites money: an invoiced
--    period stays due; the first period it frees is the first one not
--    invoiced whose first day the member is paused. The command answers
--    which months stay due and which is the first free.
--  * The nightly job applies the changes that are due, on each business's own
--    day, before the invoice run; in date order, each once, each on its own.
--    A change applies only to a member in the state it starts from; a
--    resumption only to a member paused by that same pause; a refused pause
--    takes its resumption with it; a member who leaves has their waiting
--    changes cancelled. A waiting change is cancelled until its day, unless
--    an invoice issued after it carries it. Every state a change takes
--    rebalances the member's carnets.
--  * The invoice run decides by the member's state on the invoiced period's
--    first day; it applies the changes due first, so a business without the
--    nightly job still has them in force. It issues this month, once ever,
--    only for a member resumed from a pause on its first day (or in the
--    advance window before it). A full invoice and a subscription or usage
--    invoice of one member and period exclude each other.
--  * The job, the commands and `create_invoice` take the business's advisory
--    lock before they read whether a period is invoiced, so an invoice and a
--    change never cross.
--  * Scheduling and cancelling need manageMembers; a validation policy holds
--    a scheduled change as it holds an immediate one. A request id answers
--    its own change again, and only that one.
--  * The rows are the member's own data: readable by the member and by
--    whoever manages members, carried by the member's export; an erasure
--    cancels what was scheduled and records no term.

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
  -- the date it is in force from
  due_on date not null,
  -- the business's day it was applied
  applied_on date,
  state text not null default 'scheduled'
    check (state in ('pending', 'scheduled', 'applied', 'refused', 'cancelled')),
  reason text not null default '',
  source text not null check (source in ('scheduled', 'immediate')),
  group_id uuid,
  request_id uuid,
  event_id uuid references public.events(id) on delete set null,
  requested_by uuid references public.members(id) on delete set null,
  -- when it was released to apply: made, or approved when it was held;
  -- among changes of one date the last released is in force
  released_at timestamptz not null default now(),
  -- the order changes were made in, also within one transaction
  seq bigint generated always as identity,
  constraint member_term_changes_kind_value check (
    (kind = 'share' and to_pct is not null and to_status is null)
    or (kind = 'status' and to_status is not null and to_pct is null)),
  constraint member_term_changes_scheduled_status check (
    source <> 'scheduled' or kind = 'share' or to_status in ('active', 'paused')),
  constraint member_term_changes_applied_dated check (
    state <> 'applied' or applied_on is not null)
);
select public.ensure_system_columns('member_term_changes');
comment on table public.member_term_changes is
  '#3858 -- every dated change of a member''s plan share and status: scheduled, or written at once by the commands';
-- one request is one change (a pause: its start and its end)
create unique index if not exists member_term_changes_request_uq
  on public.member_term_changes (request_id, kind, coalesce(to_status, ''), coalesce(to_pct, -1))
  where request_id is not null;
create index if not exists member_term_changes_member_idx
  on public.member_term_changes (member_id, kind, state, due_on);
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

-- ── the terms an invoice froze ────────────────────────────────────────────
create table if not exists public.member_period_terms (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  invoice_id uuid not null unique references public.invoices(id) on delete cascade,
  subscription_pct integer not null,
  paused boolean not null,
  fee_cents integer not null,
  included_half_days integer not null
);
select public.ensure_system_columns('member_period_terms');
comment on table public.member_period_terms is
  '#3858 -- the terms a subscription invoice was computed with: what its period reads while the invoice stands';
create index if not exists member_period_terms_member_idx
  on public.member_period_terms (member_id, period);

alter table public.member_period_terms enable row level security;
drop policy if exists member_period_terms_select on public.member_period_terms;
create policy member_period_terms_select on public.member_period_terms
  for select using (
    workspace_id in (select public.workspaces_permitting(array['manageMembers']))
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = (select auth.uid())));
drop policy if exists mcp_delegated_deny on public.member_period_terms;
create policy mcp_delegated_deny on public.member_period_terms as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke insert, update, delete on public.member_period_terms from anon, authenticated;

-- The business's own day, in its time zone.
create or replace function public.workspace_today(p_workspace_id uuid)
returns date language sql stable security definer set search_path = public as $fn$
  select (now() at time zone coalesce(nullif(w.timezone, ''), 'UTC'))::date
    from public.workspaces w where w.id = p_workspace_id
$fn$;
revoke execute on function public.workspace_today(uuid) from public, anon, authenticated;

-- ── is a period invoiced ──────────────────────────────────────────────────
-- Whether the period starting [p_first] has a subscription (or full)
-- invoice that stands. The invoice being replaced, and the one being
-- frozen, are not counted while `create_invoice` computes.
create or replace function public.member_period_invoiced(p_member_id uuid, p_first date)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.invoices i
     where i.member_id = p_member_id and i.period = to_char(p_first, 'YYYY-MM')
       and i.kind in ('subscription', 'full') and i.voided_at is null
       and position(i.id::text in coalesce(current_setting('deskilo.invoice_unseen', true), '')) = 0)
$fn$;
revoke execute on function public.member_period_invoiced(uuid, date) from public, anon, authenticated;

-- The terms the standing invoice of the period starting [p_first] froze.
create or replace function public.member_frozen_terms(p_member_id uuid, p_first date)
returns public.member_period_terms language sql stable security definer set search_path = public as $fn$
  select t.* from public.member_period_terms t
    join public.invoices i on i.id = t.invoice_id
   where t.member_id = p_member_id and t.period = to_char(p_first, 'YYYY-MM')
     and i.voided_at is null
     and position(i.id::text in coalesce(current_setting('deskilo.invoice_unseen', true), '')) = 0
   order by i.issued_at desc limit 1
$fn$;
revoke execute on function public.member_frozen_terms(uuid, date) from public, anon, authenticated;

-- The earliest first day a share change can take from [p_day]'s month:
-- the month itself, or the month after the last period from it on that is
-- invoiced (an invoiced period keeps its terms, and so does every one
-- before it).
create or replace function public.member_first_open_period(p_member_id uuid, p_day date)
returns date language sql stable security definer set search_path = public as $fn$
  select greatest(date_trunc('month', p_day)::date,
    coalesce((select (max(to_date(i.period || '-01', 'YYYY-MM-DD')) + interval '1 month')::date
                from public.invoices i
               where i.member_id = p_member_id and i.kind in ('subscription', 'full')
                 and i.voided_at is null
                 and position(i.id::text in coalesce(current_setting('deskilo.invoice_unseen', true), '')) = 0
                 and to_date(i.period || '-01', 'YYYY-MM-DD') >= date_trunc('month', p_day)::date),
             date_trunc('month', p_day)::date))
$fn$;
revoke execute on function public.member_first_open_period(uuid, date) from public, anon, authenticated;

-- ── reading the terms as of a day ─────────────────────────────────────────
-- The share in force on [p_day]: the last change dated on or before it,
-- applied or still waiting (of one date, the last released); else the share
-- before the first change after it; else the member's share now.
create or replace function public.member_share_as_of(p_member_id uuid, p_day date, p_current integer)
returns integer language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select c.to_pct from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'share'
        and c.state in ('applied', 'scheduled') and c.due_on <= p_day
      order by c.due_on desc, c.released_at desc, c.seq desc limit 1),
    (select c.from_pct from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'share' and c.state = 'applied'
        and c.due_on > p_day
      order by c.due_on, c.released_at, c.seq limit 1),
    p_current)
$fn$;
revoke execute on function public.member_share_as_of(uuid, date, integer) from public, anon, authenticated;

-- Whether the member is paused on [p_day], read the same way. A day before
-- the current month that no recorded change covers is read as before dated
-- terms: not paused.
create or replace function public.member_paused_on(p_member_id uuid, p_day date, p_current text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select c.to_status from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'status'
        and c.state in ('applied', 'scheduled') and c.due_on <= p_day
      order by c.due_on desc, c.released_at desc, c.seq desc limit 1),
    case when p_day < date_trunc('month', public.workspace_today(
                (select m.workspace_id from public.members m where m.id = p_member_id)))::date
         then 'active' end,
    (select c.from_status from public.member_term_changes c
      where c.member_id = p_member_id and c.kind = 'status' and c.state = 'applied'
        and c.due_on > p_day
      order by c.due_on, c.released_at, c.seq limit 1),
    p_current) = 'paused'
$fn$;
revoke execute on function public.member_paused_on(uuid, date, text) from public, anon, authenticated;

-- The share of the period starting [p_first]: what its invoice froze; the
-- member's row for one invoiced before the terms were frozen; else the
-- share in force on its first day.
create or replace function public.member_pct_in(p_member_id uuid, p_first date, p_current integer)
returns integer language sql stable security definer set search_path = public as $fn$
  select case
    when (public.member_frozen_terms(p_member_id, p_first)).id is not null
      then (public.member_frozen_terms(p_member_id, p_first)).subscription_pct
    when public.member_period_invoiced(p_member_id, p_first) then p_current
    else public.member_share_as_of(p_member_id, p_first, p_current) end
$fn$;
revoke execute on function public.member_pct_in(uuid, date, integer) from public, anon, authenticated;

-- Whether [p_period] of the member is invoiced in [p_kind]: use always, for
-- a member active or paused; the subscription (or a full invoice) when the
-- member is not paused on the period's first day.
create or replace function public.member_billable_in(p_member_id uuid, p_period text, p_kind text)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_m public.members;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null or v_m.status not in ('active', 'paused') then return false; end if;
  if p_kind = 'usage' then return true; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then return v_m.status = 'active'; end if;
  return not public.member_paused_on(p_member_id, to_date(p_period || '-01', 'YYYY-MM-DD'), v_m.status);
end;
$fn$;
revoke execute on function public.member_billable_in(uuid, text, text) from public, anon, authenticated;

-- What a pause from [p_from] until [p_to] (null: until resumed) costs: the
-- months that stay due (the month it starts in unless it starts on the 1st,
-- and every invoiced month it covers), and the first month it frees.
create or replace function public.member_pause_money(p_member_id uuid, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_due text[] := '{}';
  v_free text;
  v_month date := date_trunc('month', p_from)::date;
  v_stop date := (date_trunc('month', p_from) + interval '24 months')::date;
begin
  if extract(day from p_from) <> 1 then
    v_due := v_due || to_char(v_month, 'YYYY-MM');
    v_month := (v_month + interval '1 month')::date;
  end if;
  while (p_to is null or v_month < p_to) and v_month < v_stop loop
    if public.member_period_invoiced(p_member_id, v_month) then
      v_due := v_due || to_char(v_month, 'YYYY-MM');
    elsif v_free is null then
      v_free := to_char(v_month, 'YYYY-MM');
      exit when p_to is null;
    end if;
    v_month := (v_month + interval '1 month')::date;
  end loop;
  return jsonb_build_object('due', to_jsonb(v_due), 'first_free', v_free);
end;
$fn$;
revoke execute on function public.member_pause_money(uuid, date, date) from public, anon, authenticated;

-- ── the changes written at once ───────────────────────────────────────────
-- A share written into the row (only the commands do) counts from the first
-- day of this period, which is not invoiced; a status from today. A member
-- who leaves has their waiting changes cancelled.
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
  -- the job and an erasure record (or leave out) the change themselves
  if coalesce(current_setting('deskilo.term_change_applying', true), '') = 'on' then
    return new;
  end if;
  if new.subscription_pct is distinct from old.subscription_pct then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct,
      due_on, applied_on, state, source)
    values (new.workspace_id, new.id, 'share', coalesce(new.subscription_pct, 100),
      coalesce(old.subscription_pct, 100), public.member_first_open_period(new.id, v_today),
      v_today, 'applied', 'immediate');
  end if;
  if new.status is distinct from old.status then
    insert into public.member_term_changes (workspace_id, member_id, kind, to_status, from_status,
      due_on, applied_on, state, source)
    values (new.workspace_id, new.id, 'status', new.status, old.status, v_today, v_today,
      'applied', 'immediate');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_term_history() from public, anon, authenticated;
-- A share or a status changes through its command (the definer functions),
-- never by a direct write from the API.
-- It runs as the caller (security invoker): inside a command, the definer.
create or replace function public.members_terms_by_command()
returns trigger language plpgsql security invoker set search_path = public as $fn$
begin
  if current_user in ('authenticated', 'anon')
     and (new.subscription_pct is distinct from old.subscription_pct or new.status is distinct from old.status) then
    raise exception 'a share or a status changes through its command' using errcode = '42501';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_terms_by_command() from public, anon, authenticated;
drop trigger if exists members_terms_by_command on public.members;
create trigger members_terms_by_command
  before update of subscription_pct, status on public.members
  for each row execute function public.members_terms_by_command();

-- Named to fire before members_rebalance_credits (triggers of one event run
-- in name order): the rebalance reads the share just recorded.
drop trigger if exists members_term_history on public.members;
drop trigger if exists members_dated_terms on public.members;
create trigger members_dated_terms
  after update of subscription_pct, status on public.members
  for each row execute function public.members_term_history();

-- The immediate share command's date: the first day of this period when it
-- is not invoiced (the row takes the share now), else the first day of the
-- first period not invoiced (a change waiting for that day). [p_event] is
-- the approved event, when the change was held.
create or replace function public.member_share_at_once(
  p_member_id uuid, p_pct integer, p_actor uuid, p_event uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_m public.members;
  v_today date;
  v_on date;
  v_id uuid;
begin
  select * into v_m from public.members where id = p_member_id;
  perform pg_advisory_xact_lock(hashtext(v_m.workspace_id::text));
  v_today := public.workspace_today(v_m.workspace_id);
  v_on := public.member_first_open_period(p_member_id, v_today);
  if v_on = date_trunc('month', v_today)::date then
    update public.members set subscription_pct = p_pct where id = p_member_id;
    return jsonb_build_object('effective_on', v_on, 'state', 'applied');
  end if;
  insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state,
    source, requested_by, event_id)
  values (v_m.workspace_id, p_member_id, 'share', p_pct, v_on, 'scheduled', 'immediate',
    p_actor, p_event) returning id into v_id;
  return jsonb_build_object('effective_on', v_on, 'state', 'scheduled', 'change_id', v_id);
end;
$fn$;
revoke execute on function public.member_share_at_once(uuid, integer, uuid, uuid) from public, anon, authenticated;

-- The immediate share command (0181's, restated whole): held where a policy
-- holds plan changes; otherwise dated as above, and the answer and the
-- event say the date.
create or replace function public.request_subscription_change(p_member_id uuid, p_pct integer)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_m public.members; v_actor public.members; v_id uuid; v_payload jsonb; v_at jsonb;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if p_pct < 0 or p_pct > 100 then raise exception 'pct out of range' using errcode = '22023'; end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change subscriptions' using errcode = '42501';
  end if;
  v_payload := jsonb_build_object('member_id', p_member_id, 'before', v_m.subscription_pct, 'after', p_pct);
  if public.validation_requires(v_m.workspace_id, 'subscription_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'subscription_change', 'submitted', v_actor.id, p_member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  v_at := public.member_share_at_once(p_member_id, p_pct, v_actor.id);
  if v_at ->> 'state' = 'applied' then
    perform public.record_applied_event(v_m.workspace_id, 'subscription_change', v_actor.id, p_member_id,
      v_payload || jsonb_build_object('effective_on', v_at -> 'effective_on'));
  end if;
  return jsonb_build_object('pending', false) || v_at;
end $function$;
revoke execute on function public.request_subscription_change(uuid, integer) from public, anon;

-- ── applying a change ─────────────────────────────────────────────────────
-- Applies one due change, once, under the business's lock: the member's row
-- takes it (and refuses it when its rules do), and the row says the day it
-- was applied. A pause refused takes its resumption with it.
create or replace function public.apply_member_term_change(p_change_id uuid)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.member_term_changes;
  v_m public.members;
  v_last public.member_term_changes;
  v_today date;
  v_refusal text;
begin
  select * into v_c from public.member_term_changes where id = p_change_id;
  if v_c.id is null then return 'unknown'; end if;
  perform pg_advisory_xact_lock(hashtext(v_c.workspace_id::text));
  select * into v_c from public.member_term_changes where id = p_change_id for update;
  v_today := public.workspace_today(v_c.workspace_id);
  if v_c.state <> 'scheduled' or v_c.due_on > v_today then
    return v_c.state;
  end if;
  select * into v_m from public.members where id = v_c.member_id for update;
  select * into v_last from public.member_term_changes
   where member_id = v_c.member_id and kind = 'status' and state = 'applied'
   order by due_on desc, seq desc limit 1;
  -- the rules of an immediate change hold on the change's day, and a change
  -- applies only to a member in the state it starts from
  v_refusal := case
    when v_m.status in ('exited', 'tombstone') then 'the membership has ended'
    when v_c.kind = 'status' and v_m.is_owner then 'an owner hands the workspace over first'
    when v_c.kind = 'status' and v_c.to_status = 'paused' and v_m.status <> 'active' then 'the member is not active'
    when v_c.kind = 'status' and v_c.to_status = 'active' and v_m.status <> 'paused' then 'the member is not paused'
    when v_c.kind = 'status' and v_c.to_status = 'active'
         and (v_last.group_id is distinct from v_c.group_id or v_last.to_status <> 'paused')
      then 'the member was paused again since'
  end;
  if v_refusal is null then
    -- recorded first: what the member's row triggers (the credit rebalance)
    -- reads the terms with this change in force
    update public.member_term_changes
       set state = 'applied', applied_on = v_today,
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
      v_refusal := left(sqlerrm, 300);
    end;
  end if;
  if v_refusal is not null then
    update public.member_term_changes
       set state = 'refused', reason = v_refusal, applied_on = null
     where id = p_change_id;
    if v_c.kind = 'status' and v_c.to_status = 'paused' and v_c.group_id is not null then
      update public.member_term_changes
         set state = 'cancelled', reason = 'its pause was refused'
       where group_id = v_c.group_id and id <> p_change_id and state in ('pending', 'scheduled');
    end if;
    return 'refused';
  end if;
  -- an approved change's event already stands
  if v_c.event_id is null then
    perform public.record_applied_event(v_c.workspace_id,
      case when v_c.kind = 'share' then 'subscription_change' else 'member_status_change' end,
      -- whoever scheduled it; the member, when that person is gone
      coalesce(v_c.requested_by, v_c.member_id), v_c.member_id,
      jsonb_build_object('member_id', v_c.member_id, 'change_id', v_c.id,
        'before', case when v_c.kind = 'share' then to_jsonb(coalesce(v_m.subscription_pct, 100))
                       else to_jsonb(v_m.status) end,
        'after', case when v_c.kind = 'share' then to_jsonb(v_c.to_pct) else to_jsonb(v_c.to_status) end,
        'effective_on', v_c.due_on));
  end if;
  return 'applied';
end;
$fn$;
revoke execute on function public.apply_member_term_change(uuid) from public, anon, authenticated;

-- The nightly job: every change due up to each business's own today, by
-- business (the order the invoice run locks them in), then in date order;
-- each once and each on its own: one that fails is kept as refused with the
-- reason, and the others go on. Runs before the invoice run (06:40 UTC).
drop function if exists public.apply_due_member_term_changes();
create or replace function public.apply_due_member_term_changes(p_workspace_id uuid default null)
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
       and (p_workspace_id is null or c.workspace_id = p_workspace_id)
     order by c.workspace_id, c.due_on, c.released_at, c.seq
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
revoke execute on function public.apply_due_member_term_changes(uuid) from public, anon, authenticated;

-- Every state a change takes (made, approved, cancelled, refused, applied)
-- rebalances the member's carnets for the months they hold bookings in, as
-- a change of the member's row does (0237).
create or replace function public.member_term_changes_rebalance()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_at timestamptz;
begin
  if tg_op = 'UPDATE' and new.state is not distinct from old.state and new.due_on = old.due_on then
    return null;
  end if;
  for v_at in
    select min(r.starts_at)
      from public.member_credit_uses u
      join public.reservations r on r.id = u.reservation_id
     where r.member_id = new.member_id and u.released_at is null
     group by date_trunc('month', r.starts_at)
  loop
    perform public.rebalance_member_credits(new.member_id, v_at, null);
  end loop;
  return null;
end;
$fn$;
revoke execute on function public.member_term_changes_rebalance() from public, anon, authenticated;
drop trigger if exists member_term_changes_rebalance on public.member_term_changes;
create trigger member_term_changes_rebalance
  after insert or update of state, due_on on public.member_term_changes
  for each row execute function public.member_term_changes_rebalance();

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
-- Schedules a share for [p_effective_on]: a period's first day, today or
-- later, with no invoiced period from it on; else refused with the earliest
-- date it can take. Held for
-- approval where a validation policy holds plan changes. A request id
-- answers its own change again; used with other values, it is refused.
create or replace function public.schedule_member_share_change(
  p_member_id uuid, p_pct integer, p_effective_on date, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_m public.members;
  v_actor public.members;
  v_prior public.member_term_changes;
  v_earliest date;
  v_id uuid;
  v_event uuid;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change subscriptions' using errcode = 'DKN01';
  end if;
  if p_request_id is null then raise exception 'a request id is required' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtext(v_m.workspace_id::text));
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
  v_earliest := public.member_first_open_period(p_member_id, p_effective_on);
  if v_earliest > date_trunc('month', p_effective_on)::date then
    raise exception 'this period is already invoiced — the earliest is %', v_earliest
      using errcode = '22023', detail = v_earliest::text;
  end if;
  if extract(day from p_effective_on) <> 1 then
    v_earliest := public.member_first_open_period(p_member_id,
      (date_trunc('month', p_effective_on) + interval '1 month')::date);
    raise exception 'a share changes on the first day of a period — the earliest is %', v_earliest
      using errcode = '22023', detail = v_earliest::text;
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
    return jsonb_build_object('change_id', v_id, 'state', 'pending', 'event_id', v_event,
      'effective_on', p_effective_on);
  end if;
  insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state,
    source, request_id, requested_by)
  values (v_m.workspace_id, p_member_id, 'share', p_pct, p_effective_on, 'scheduled', 'scheduled',
    p_request_id, v_actor.id) returning id into v_id;
  return jsonb_build_object('change_id', v_id, 'state', public.apply_member_term_change(v_id),
    'effective_on', p_effective_on);
end;
$fn$;
revoke execute on function public.schedule_member_share_change(uuid, integer, date, uuid) from public, anon;
grant execute on function public.schedule_member_share_change(uuid, integer, date, uuid) to authenticated;

-- Schedules a pause from [p_from] (today or later) until [p_to] (the member is
-- active again that day; null: until resumed). Held for approval where a
-- validation policy holds status changes. The answer names the months that
-- stay due and the first month it frees.
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
  perform pg_advisory_xact_lock(hashtext(v_m.workspace_id::text));
  select * into v_start from public.member_term_changes
   where request_id = p_request_id order by due_on, seq limit 1;
  if v_start.id is not null then
    select c.due_on into v_end_on from public.member_term_changes c
     where c.request_id = p_request_id and c.id <> v_start.id;
    if v_start.member_id = p_member_id and v_start.kind = 'status' and v_start.to_status = 'paused'
       and v_start.due_on = p_from and v_end_on is not distinct from p_to then
      return jsonb_build_object('change_id', v_start.id, 'state', v_start.state, 'replayed', true)
        || public.member_pause_money(p_member_id, p_from, p_to);
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
    return jsonb_build_object('change_id', v_id, 'state', 'pending', 'event_id', v_event)
      || public.member_pause_money(p_member_id, p_from, p_to);
  end if;
  return jsonb_build_object('change_id', v_id, 'state', public.apply_member_term_change(v_id))
    || public.member_pause_money(p_member_id, p_from, p_to);
end;
$fn$;
revoke execute on function public.schedule_member_pause(uuid, date, date, uuid) from public, anon;
grant execute on function public.schedule_member_pause(uuid, date, date, uuid) to authenticated;

-- Cancels a waiting change (and the rest of its pause) until its day. An
-- applied change is history; a change an invoice already carries stays: a
-- new change is scheduled instead.
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
  perform pg_advisory_xact_lock(hashtext(v_c.workspace_id::text));
  if v_c.state not in ('pending', 'scheduled') then
    raise exception 'only a change not yet applied is cancelled' using errcode = '55000';
  end if;
  if v_c.state = 'scheduled' and v_c.due_on <= public.workspace_today(v_c.workspace_id) then
    raise exception 'this change applies today' using errcode = '55000';
  end if;
  -- an invoice carries a waiting change it was issued after: its period
  -- starts on or after the change's date
  if exists (
    select 1 from public.member_term_changes c
      join public.invoices i on i.member_id = c.member_id
     where c.state = 'scheduled'
       and (c.id = p_change_id or (v_c.group_id is not null and c.group_id = v_c.group_id))
       and i.kind in ('subscription', 'full') and i.voided_at is null
       and i.issued_at >= c.released_at
       and to_date(i.period || '-01', 'YYYY-MM-DD') >= c.due_on) then
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
-- An approved change is released as of the approval: a share takes the
-- later of its date and the earliest first day open then; a pause starts no
-- earlier than that day (and ends after it). The event says the dates, and
-- for a pause what it costs. A rejected change is refused, with the reason.
create or replace function public.member_term_changes_decided()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_change uuid := (new.payload ->> 'change_id')::uuid;
  v_c public.member_term_changes;
  v_today date;
  v_on date;
  v_end date;
  v_id uuid;
begin
  if new.status = old.status or v_change is null
     or new.type not in ('subscription_change', 'member_status_change') then
    return new;
  end if;
  select * into v_c from public.member_term_changes where id = v_change;
  if v_c.id is null then return new; end if;
  if new.status = 'confirmed' then
    perform pg_advisory_xact_lock(hashtext(v_c.workspace_id::text));
    v_today := public.workspace_today(v_c.workspace_id);
    if v_c.kind = 'share' then
      v_on := greatest(v_c.due_on, public.member_first_open_period(v_c.member_id, v_today));
      update public.member_term_changes set state = 'scheduled', due_on = v_on, released_at = now()
       where id = v_change and state = 'pending';
      update public.events set payload = payload || jsonb_build_object('effective_on', v_on) where id = new.id;
    else
      v_on := greatest(v_c.due_on, v_today);
      select greatest(c.due_on, v_on + 1) into v_end from public.member_term_changes c
       where c.group_id = v_c.group_id and c.id <> v_change and c.state = 'pending';
      update public.member_term_changes
         set state = 'scheduled', released_at = now(),
             due_on = case when id = v_change then v_on else v_end end
       where state = 'pending' and (id = v_change or (v_c.group_id is not null and group_id = v_c.group_id));
      update public.events set payload = payload
        || jsonb_build_object('effective_on', v_on, 'until', v_end)
        || public.member_pause_money(v_c.member_id, v_on, v_end)
       where id = new.id;
    end if;
    for v_id in select id from public.member_term_changes
                 where (id = v_change or (v_c.group_id is not null and group_id = v_c.group_id))
                   and state = 'scheduled' order by due_on, seq loop
      perform public.apply_member_term_change(v_id);
    end loop;
  elsif new.status = 'rejected' then
    update public.member_term_changes set state = 'refused', reason = 'not approved'
     where state = 'pending' and (id = v_change or (v_c.group_id is not null and group_id = v_c.group_id));
  end if;
  return new;
end;
$fn$;
revoke execute on function public.member_term_changes_decided() from public, anon, authenticated;
drop trigger if exists events_member_term_changes_decided on public.events;
create trigger events_member_term_changes_decided
  after update on public.events
  for each row execute function public.member_term_changes_decided();

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
  -- 1. the approval of 0181: a scheduled change (its payload names it) is
  -- the store's to apply; an approved immediate share takes its date as of
  -- the approval, and the event says it
  v_def := pg_get_functiondef('public.apply_validated_decision_0181()'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$declare v_inv uuid; v_perms text[];$r$,
      $r$declare v_inv uuid; v_perms text[]; v_term jsonb;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in apply_validated_decision_0181' using errcode = 'P0001'; end if;
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
        v_term := public.member_share_at_once((new.payload->>'member_id')::uuid,
          (new.payload->>'after')::int, new.actor_member_id, new.id);
        update public.events set payload = payload || jsonb_build_object('effective_on', v_term -> 'effective_on')
         where id = new.id;
      end if;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in apply_validated_decision_0181' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 2. the immediate status command answers what a pause costs
  v_def := pg_get_functiondef('public.request_member_status_change(uuid, text)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  update public.members set status = p_status where id = p_member_id;
  perform public.record_applied_event(v_m.workspace_id, 'member_status_change', v_actor.id, p_member_id, v_payload);
  return jsonb_build_object('pending', false);$r$,
      $r$  perform pg_advisory_xact_lock(hashtext(v_m.workspace_id::text));
  update public.members set status = p_status where id = p_member_id;
  perform public.record_applied_event(v_m.workspace_id, 'member_status_change', v_actor.id, p_member_id, v_payload);
  -- #3858: which months stay due and the first a pause frees
  return jsonb_build_object('pending', false)
    || case when p_status = 'paused'
            then public.member_pause_money(p_member_id, public.workspace_today(v_m.workspace_id), null)
            else '{}'::jsonb end;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in request_member_status_change' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 3. the statement and both quota checks: an invoiced period reads the
  -- terms its invoice froze (or, invoiced before they were frozen, the
  -- member's row); one not invoiced reads the share in force on its first
  -- day, and owes no fee and includes nothing when paused on it
  foreach v_fn in array array['public.member_statement(uuid, text)',
                              'public.assert_member_quota(uuid, timestamp with time zone)',
                              'public.member_quota_shortfall(uuid, timestamp with time zone)'] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if position('#3858' in v_def) = 0 then
      v_def := pg_temp.anchor_replace(v_def,
        $r$  v_pct := coalesce(v_member.subscription_pct, 100);$r$,
        $r$  -- #3858: the share of the period
  v_pct := public.member_pct_in(v_member.id, v_month_first, coalesce(v_member.subscription_pct, 100));$r$);
      if v_def is null then raise exception 'an anchor of #3858 was not found in %', v_fn using errcode = 'P0001'; end if;
      v_def := pg_temp.anchor_replace(v_def,
        $r$  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;$r$,
        $r$  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;
  -- #3858: the fee and the included half-days of the period
  if public.member_period_invoiced(v_member.id, v_month_first) then
    if (public.member_frozen_terms(v_member.id, v_month_first)).id is not null then
      v_included := (public.member_frozen_terms(v_member.id, v_month_first)).included_half_days;
      $r$ || case when v_fn like 'public.member_statement%'
                  then 'v_base := (public.member_frozen_terms(v_member.id, v_month_first)).fee_cents;'
                  else 'null;' end || $r$
    end if;
  elsif public.member_paused_on(v_member.id, v_month_first, v_member.status) then
    v_included := 0;
    $r$ || case when v_fn like 'public.member_statement%' then 'v_base := 0;' else 'null;' end || $r$
  end if;$r$);
      if v_def is null then raise exception 'an anchor of #3858 was not found in %', v_fn using errcode = 'P0001'; end if;
      execute v_def;
    end if;
  end loop;

  -- 4. an invoice: under the business's lock from the start; for a member
  -- billable in its period; a full invoice excludes the other kinds of its
  -- period; a subscription (or full) invoice freezes the terms it was
  -- computed with -- a replacement recomputes them, not reading the one it
  -- replaces
  v_def := pg_get_functiondef('public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text, text)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;$r$,
      $r$  -- #3858: the lock first, so a change and this invoice never cross
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  perform set_config('deskilo.invoice_unseen', coalesce(p_replaces::text, ''), true);
  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and public.member_billable_in(id, p_period, p_kind) and not is_kiosk;
  if p_kind <> 'full' and exists (
    select 1 from public.invoices i
     where i.member_id = p_member_id and i.period = p_period and i.kind = 'full'
       and i.voided_at is null and i.id is distinct from p_replaces) then
    raise exception 'this month has a full invoice — void and replace it to add later use' using errcode = 'DKI07';
  end if;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in create_invoice' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$      and i.kind = p_kind$r$,
      $r$      and (i.kind = p_kind or i.kind = 'full' or p_kind = 'full')$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in create_invoice' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$     p_kind, 7);
  return v_id;$r$,
      $r$     p_kind, 7);
  -- #3858: the terms this invoice freezes for its period
  if p_kind in ('subscription', 'full') then
    perform set_config('deskilo.invoice_unseen', concat_ws(',', p_replaces::text, v_id::text), true);
    insert into public.member_period_terms (workspace_id, member_id, period, invoice_id,
      subscription_pct, paused, fee_cents, included_half_days)
    select p_workspace_id, v_subject.id, p_period, v_id,
           (x.s ->> 'subscription_pct')::int,
           public.member_paused_on(v_subject.id, to_date(p_period || '-01', 'YYYY-MM-DD'), v_subject.status),
           (x.s ->> 'fee_cents')::int, (x.s ->> 'included_half_days')::int
      from (select public.member_statement(v_subject.id, p_period) as s) x;
  end if;
  perform set_config('deskilo.invoice_unseen', '', true);
  return v_id;$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in create_invoice' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 5. the invoice run: the due changes first (where no cron runs the job,
  -- the run still applies them); by business in one order (the job's); members
  -- active or paused now, each decided as of the invoiced period; this
  -- month only for a member resumed from a pause on its first day or in the
  -- advance window before it; a paused member's empty use is not invoiced
  v_def := pg_get_functiondef('public.sweep_billing_invoices(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  for v_ws in
    select w.id, w.billing_rules, w.timezone, w.feature_flags$r$,
      $r$  -- #3858: the changes due today are in force before anything is invoiced
  perform public.apply_due_member_term_changes(p_workspace_id);
  for v_ws in
    select w.id, w.billing_rules, w.timezone, w.feature_flags$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$       and public.feature_effective_in(w.feature_flags, 'invoicing')
  loop$r$,
      $r$       and public.feature_effective_in(w.feature_flags, 'invoicing')
     order by w.id -- #3858: the order the nightly job locks businesses in
  loop$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$      select m.id from public.members m
       where m.workspace_id = v_ws.id and m.status = 'active' and not m.is_kiosk$r$,
      $r$      select m.id, m.status from public.members m
       where m.workspace_id = v_ws.id and m.status in ('active', 'paused') and not m.is_kiosk -- #3858$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    v_def := pg_temp.anchor_replace(v_def,
      $r$      if coalesce((v_rules ->> 'usage_auto')::boolean, true)$r$,
      $r$      -- #3858: this month, for a member resumed from a pause on its first
      -- day or in the advance window before it
      if coalesce((v_rules ->> 'subscription_auto')::boolean, true)
         and public.feature_effective_in(v_flags, 'subscriptionInvoices')
         and exists (select 1 from public.member_term_changes c
                      where c.member_id = v_member.id and c.kind = 'status' and c.state = 'applied'
                        and c.from_status = 'paused' and c.to_status = 'active'
                        and c.due_on >= date_trunc('month', v_today)::date - v_advance
                        and c.due_on <= date_trunc('month', v_today)::date)
         -- at most once: never again after an invoice of any state, voided included
         and not exists (select 1 from public.invoices i
                           where i.member_id = v_member.id and i.period = to_char(v_today, 'YYYY-MM')
                             and i.kind in ('subscription', 'full'))
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
    v_def := pg_temp.anchor_replace(v_def,
      $r$            coalesce((v_rules ->> 'usage_when_zero')::boolean, false));$r$,
      $r$            coalesce((v_rules ->> 'usage_when_zero')::boolean, false) and v_member.status = 'active');$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in sweep_billing_invoices' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 6. the member's own export carries their dated changes and the terms of
  -- their invoiced periods (its own object: the export's single call is at
  -- the argument limit)
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position('#3858' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $r$  return jsonb_build_object(
    'exported_at', now(),$r$,
      $r$  -- #3858: their dated plan changes and the terms of their invoiced periods
  return jsonb_build_object('term_changes',
    (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.member_term_changes t
      where t.member_id = v_me.id),
    'period_terms',
    (select coalesce(jsonb_agg(to_jsonb(p)), '[]') from public.member_period_terms p
      where p.member_id = v_me.id)) || jsonb_build_object(
    'exported_at', now(),$r$);
    if v_def is null then raise exception 'an anchor of #3858 was not found in export_my_data' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- 7. erasing a membership cancels what was scheduled for it, with the
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

-- An accepted deal (0138), restated whole: its share goes through the
-- immediate command, dated the first day of the first period it can take.
create or replace function public.apply_negotiation_on_decision()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_deal public.price_negotiations;
begin
  if new.type <> 'price_negotiation' or new.status = old.status then return new; end if;
  if new.status = 'confirmed' then
    update public.price_negotiations set status = 'superseded', decided_at = now()
     where member_id = new.subject_member_id and status = 'active';
    update public.price_negotiations set status = 'active', decided_at = now()
     where event_id = new.id and status = 'pending'
     returning * into v_deal;
    -- #744 — the occupation is part of the deal: applied on validation,
    -- the previous value kept for the comparison.
    if v_deal.id is not null and v_deal.subscription_pct is not null then
      update public.price_negotiations
         set previous_subscription_pct = (select subscription_pct from public.members where id = v_deal.member_id)
       where id = v_deal.id;
      perform public.member_share_at_once(v_deal.member_id, v_deal.subscription_pct, new.actor_member_id, new.id);
    end if;
  elsif new.status in ('rejected', 'expired') then
    update public.price_negotiations set status = 'rejected', decided_at = now()
     where event_id = new.id and status = 'pending';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.apply_negotiation_on_decision() from public, anon, authenticated;

-- The default tariff (0210), restated whole: the share of the current
-- period.
create or replace function public.default_tariff_of(p_member_id uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $function$
  select coalesce((select jsonb_build_object('fee_cents', b.fee_cents, 'overage_fee_cents', b.overage_fee_cents)
       from public.members m
       cross join lateral (select public.member_pct_in(m.id,
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
