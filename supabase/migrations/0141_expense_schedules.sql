-- SPDX-License-Identifier: 0BSD
--
-- #767 — scheduled (recurring) expenses: internet, phone, electricity…
-- Any active member, whatever their role, SCHEDULES an expense: amount,
-- start date, a recurrence rule (every X days / weeks / months / years),
-- and how long it runs (X times, until a date, or both — whichever ends
-- first; neither = until cancelled). The SCHEDULE itself goes through
-- the validation rules (new domain 'expense_schedule'). Once active, a
-- sweep (pg_cron + any member opening Finances) materialises each due
-- occurrence and presents it to the member:
--   · confirmed at the validated amount  → the expense is born settled
--     (confirmed event + ledger credit, 0017 system idiom);
--   · confirmed at a DIFFERENT amount    → a mandatory explanation, and
--     the expense goes through the normal expense validation; a reject
--     hands it back to the member, who may change amount and/or note
--     and resend.

-- ---------------------------------------------------------------- schema
create table public.expense_schedules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '',
  amount_cents int not null check (amount_cents > 0),
  starts_on date not null,
  ends_on date,
  unit text not null check (unit in ('day', 'week', 'month', 'year')),
  every int not null default 1 check (every between 1 and 365),
  repeat_count int check (repeat_count between 1 and 500),
  status text not null default 'pending'
    check (status in ('pending', 'active', 'rejected', 'ended')),
  occurrences_done int not null default 0,
  next_due date,
  event_id uuid references public.events(id),
  created_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);
create index expense_schedules_ws on public.expense_schedules (workspace_id);
create index expense_schedules_due
  on public.expense_schedules (next_due) where status = 'active';

create table public.expense_occurrences (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.expense_schedules(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  due_on date not null,
  amount_cents int not null check (amount_cents > 0),
  note text not null default '',
  deviation_reason text not null default '',
  status text not null default 'awaiting_member'
    check (status in ('awaiting_member', 'pending_validation', 'added', 'rejected')),
  event_id uuid references public.events(id),
  created_at timestamptz not null default now(),
  unique (schedule_id, due_on)
);
create index expense_occurrences_member
  on public.expense_occurrences (member_id, status);

alter table public.expense_schedules enable row level security;
alter table public.expense_occurrences enable row level security;

-- The member sees their own; whoever may approve expenses or view the
-- finances sees the workspace's (validators decide on real data).
create policy expense_schedules_select on public.expense_schedules
  for select using (
    exists (select 1 from public.members m
             where m.id = member_id and m.user_id = auth.uid())
    or public.has_permission(workspace_id, 'approveExpenses')
    or public.has_permission(workspace_id, 'viewFinances'));
create policy expense_occurrences_select on public.expense_occurrences
  for select using (
    exists (select 1 from public.members m
             where m.id = member_id and m.user_id = auth.uid())
    or public.has_permission(workspace_id, 'approveExpenses')
    or public.has_permission(workspace_id, 'viewFinances'));

-- ---------------------------------------------------------------- event domain
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete','invoice_writeoff',
   'invoice_reminder','price_negotiation','expense_schedule'));
alter table public.validation_policies
  drop constraint validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check check (
    event_type is null or event_type in (
      'reservation','payment','expense','adjustment','service_charge',
      'quota','role_change','member_join','space_reservation',
      'invoice_payment','reservation_delete','invoice_writeoff',
      'price_negotiation','expense_schedule'));

-- ---------------------------------------------------------------- create
create or replace function public.create_expense_schedule(
  p_workspace_id uuid,
  p_title text,
  p_amount_cents int,
  p_starts_on date,
  p_unit text,
  p_every int default 1,
  p_repeat_count int default null,
  p_ends_on date default null,
  p_description text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_id uuid;
  v_event_id uuid;
begin
  if not coalesce((select w.feature_flags ->> 'scheduledExpenses'
                     from public.workspaces w where w.id = p_workspace_id)::boolean, true) then
    raise exception 'scheduled expenses are disabled in this workspace';
  end if;
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if char_length(trim(p_title)) not between 1 and 80 then
    raise exception 'title must be 1–80 characters';
  end if;
  if p_unit not in ('day','week','month','year') then raise exception 'unknown unit'; end if;
  if p_every is null or p_every not between 1 and 365 then
    raise exception 'interval must be between 1 and 365';
  end if;
  if p_repeat_count is not null and p_repeat_count not between 1 and 500 then
    raise exception 'repetitions must be between 1 and 500';
  end if;
  if p_ends_on is not null and p_ends_on < p_starts_on then
    raise exception 'the end date lies before the start';
  end if;

  insert into public.expense_schedules
    (workspace_id, member_id, title, description, amount_cents,
     starts_on, ends_on, unit, every, repeat_count)
  values (p_workspace_id, v_actor.id, trim(p_title), coalesce(p_description, ''),
          p_amount_cents, p_starts_on, p_ends_on, p_unit, p_every, p_repeat_count)
  returning id into v_id;

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (p_workspace_id, 'expense_schedule', 'submitted', v_actor.id, v_actor.id,
          jsonb_build_object(
            'schedule_id', v_id, 'title', trim(p_title),
            'amount_cents', p_amount_cents, 'note', coalesce(p_description, ''),
            'starts_on', p_starts_on, 'ends_on', p_ends_on,
            'unit', p_unit, 'every', p_every, 'repeat_count', p_repeat_count),
          'pending')
  returning id into v_event_id;
  update public.expense_schedules set event_id = v_event_id where id = v_id;
  return v_id;
end;
$$;
revoke execute on function public.create_expense_schedule(uuid, text, int, date, text, int, int, date, text) from public, anon;
grant execute on function public.create_expense_schedule(uuid, text, int, date, text, int, int, date, text) to authenticated;

-- ---------------------------------------------------------------- cancel
create or replace function public.cancel_expense_schedule(p_schedule_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_s public.expense_schedules;
begin
  select * into v_s from public.expense_schedules where id = p_schedule_id;
  if v_s.id is null then raise exception 'unknown schedule'; end if;
  if not (exists (select 1 from public.members m
                   where m.id = v_s.member_id and m.user_id = auth.uid())
          or public.has_permission(v_s.workspace_id, 'approveExpenses')) then
    raise exception 'not allowed';
  end if;
  update public.expense_schedules set status = 'ended' where id = p_schedule_id;
end;
$$;
revoke execute on function public.cancel_expense_schedule(uuid) from public, anon;
grant execute on function public.cancel_expense_schedule(uuid) to authenticated;

-- ---------------------------------------------------------------- apply on decision
-- The schedule follows its validation event: confirmed → active (the
-- sweep takes over), rejected → rejected.
create or replace function public.apply_expense_schedule_decision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type <> 'expense_schedule' or new.status = old.status then return new; end if;
  if new.status = 'confirmed' then
    update public.expense_schedules
       set status = 'active', next_due = starts_on
     where id = (new.payload ->> 'schedule_id')::uuid and status = 'pending';
  elsif new.status = 'rejected' then
    update public.expense_schedules
       set status = 'rejected'
     where id = (new.payload ->> 'schedule_id')::uuid and status = 'pending';
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_expense_schedule on public.events;
create trigger events_apply_expense_schedule
  after update on public.events
  for each row execute function public.apply_expense_schedule_decision();

-- A DEVIATED occurrence rides the normal 'expense' validation; its
-- occurrence row follows the event's fate.
create or replace function public.apply_expense_occurrence_decision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type <> 'expense' or new.status = old.status then return new; end if;
  if not (new.payload ? 'occurrence_id') then return new; end if;
  if new.status = 'confirmed' then
    update public.expense_occurrences
       set status = 'added' where id = (new.payload ->> 'occurrence_id')::uuid;
  elsif new.status = 'rejected' then
    update public.expense_occurrences
       set status = 'rejected' where id = (new.payload ->> 'occurrence_id')::uuid;
  end if;
  return new;
end;
$$;
drop trigger if exists events_apply_expense_occurrence on public.events;
create trigger events_apply_expense_occurrence
  after update on public.events
  for each row execute function public.apply_expense_occurrence_decision();

-- ---------------------------------------------------------------- sweep
-- Materialise every due occurrence of every ACTIVE schedule, up to
-- today. Any active member may sweep their own workspace (opening
-- Finances is the second clock); the scheduler (no auth.uid()) sweeps
-- all. Returns how many occurrences it created.
create or replace function public.sweep_expense_schedules(
  p_workspace_id uuid default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_s record;
  v_due date;
  v_done int;
  v_total int := 0;
  v_ended boolean;
begin
  if auth.uid() is not null then
    if p_workspace_id is null then raise exception 'workspace required'; end if;
    if not exists (select 1 from public.members m
                    where m.workspace_id = p_workspace_id
                      and m.user_id = auth.uid() and m.status = 'active') then
      raise exception 'not an active member';
    end if;
  end if;

  for v_s in
    select s.* from public.expense_schedules s
      join public.workspaces w on w.id = s.workspace_id
     where s.status = 'active'
       and s.next_due is not null and s.next_due <= current_date
       and (p_workspace_id is null or s.workspace_id = p_workspace_id)
       and coalesce((w.feature_flags ->> 'moneyTab')::boolean, true)
       and coalesce((w.feature_flags ->> 'scheduledExpenses')::boolean, true)
  loop
    v_due := v_s.next_due;
    v_done := v_s.occurrences_done;
    v_ended := false;
    while v_due <= current_date loop
      if (v_s.ends_on is not null and v_due > v_s.ends_on)
         or (v_s.repeat_count is not null and v_done >= v_s.repeat_count) then
        v_ended := true; exit;
      end if;
      insert into public.expense_occurrences
        (schedule_id, workspace_id, member_id, due_on, amount_cents, note)
      values (v_s.id, v_s.workspace_id, v_s.member_id, v_due,
              v_s.amount_cents, v_s.description)
      on conflict (schedule_id, due_on) do nothing;
      v_total := v_total + 1;
      v_done := v_done + 1;
      v_due := (v_due + (v_s.every || ' ' || v_s.unit)::interval)::date;
    end loop;
    -- Bounds may also close BETWEEN sweeps (a date-bound rule whose next
    -- occurrence lies past the end): settle the status now.
    if not v_ended then
      v_ended := (v_s.ends_on is not null and v_due > v_s.ends_on)
              or (v_s.repeat_count is not null and v_done >= v_s.repeat_count);
    end if;
    update public.expense_schedules
       set occurrences_done = v_done,
           next_due = case when v_ended then null else v_due end,
           status = case when v_ended then 'ended' else status end
     where id = v_s.id;
  end loop;
  return v_total;
end;
$$;
revoke execute on function public.sweep_expense_schedules(uuid) from public, anon;
grant execute on function public.sweep_expense_schedules(uuid) to authenticated;

-- ---------------------------------------------------------------- confirm / resend
-- The member answers a presented occurrence. At the validated amount →
-- born settled (confirmed event + ledger credit, the 0017 system
-- idiom). At a different amount → the explanation is mandatory and the
-- expense goes through the 'expense' validation rules. A rejected
-- occurrence comes back through the same door (amount and/or note
-- changed, resent).
create or replace function public.confirm_expense_occurrence(
  p_occurrence_id uuid,
  p_amount_cents int,
  p_reason text default '',
  p_note text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_o public.expense_occurrences;
  v_s public.expense_schedules;
  v_actor public.members;
  v_event_id uuid;
  v_note text;
begin
  select * into v_o from public.expense_occurrences where id = p_occurrence_id;
  if v_o.id is null then raise exception 'unknown occurrence'; end if;
  select * into v_s from public.expense_schedules where id = v_o.schedule_id;
  select * into v_actor from public.members
    where id = v_o.member_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'only the member who scheduled it'; end if;
  if v_o.status not in ('awaiting_member', 'rejected') then
    raise exception 'occurrence already handled';
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'amount must be positive';
  end if;
  v_note := coalesce(p_note, v_o.note);

  if p_amount_cents = v_s.amount_cents and v_o.status = 'awaiting_member' then
    -- Exactly what the validated schedule says: born settled.
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id,
       payload, status, decided_at)
    values (v_o.workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
            jsonb_build_object(
              'amount_cents', p_amount_cents,
              'category', 'scheduled',
              'note', v_s.title || case when v_note = '' then '' else ' — ' || v_note end,
              'schedule_id', v_s.id,
              'occurrence_id', v_o.id,
              'auto_validated', true),
            'confirmed', now())
    returning id into v_event_id;
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description,
       period, event_id, occurred_on)
    values (v_o.workspace_id, v_o.member_id, 'credit', 'expense',
            p_amount_cents,
            v_s.title || case when v_note = '' then '' else ' — ' || v_note end,
            to_char(v_o.due_on, 'YYYY-MM'), v_event_id, v_o.due_on);
    update public.expense_occurrences
       set status = 'added', amount_cents = p_amount_cents,
           note = v_note, event_id = v_event_id
     where id = v_o.id;
  else
    -- A different amount (or a resend after a reject): explain, then the
    -- expense validation rules decide.
    if char_length(trim(coalesce(p_reason, ''))) = 0 then
      raise exception 'a different amount needs an explanation';
    end if;
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_o.workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
            jsonb_build_object(
              'amount_cents', p_amount_cents,
              'category', 'scheduled',
              'note', v_s.title || case when v_note = '' then '' else ' — ' || v_note end,
              'schedule_id', v_s.id,
              'occurrence_id', v_o.id,
              'scheduled_amount_cents', v_s.amount_cents,
              'deviation_reason', trim(p_reason),
              'period', to_char(v_o.due_on, 'YYYY-MM'),
              'paid_on', v_o.due_on),
            'pending')
    returning id into v_event_id;
    update public.expense_occurrences
       set status = 'pending_validation', amount_cents = p_amount_cents,
           note = v_note, deviation_reason = trim(p_reason), event_id = v_event_id
     where id = v_o.id;
  end if;
end;
$$;
revoke execute on function public.confirm_expense_occurrence(uuid, int, text, text) from public, anon;
grant execute on function public.confirm_expense_occurrence(uuid, int, text, text) to authenticated;

-- ---------------------------------------------------------------- the morning clock
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-expense-schedules')
    from cron.job where jobname = 'deskilo-expense-schedules';
  perform cron.schedule('deskilo-expense-schedules', '20 6 * * *',
    $job$select public.sweep_expense_schedules()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): the client-side sweep stays the only clock', sqlerrm;
end $$;
