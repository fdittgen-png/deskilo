-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0331 (#1913) — a reminder follows the invoice's maturity and what is
-- still collectible, not the invoice's age.
--
-- `sweep_payment_reminders` and `record_invoice_reminder` counted from
-- `issued_at`, excluded any invoice that had a match row at all (so a
-- half-paid invoice was never reminded) and announced the full invoice
-- total (so a reminder could claim 120 when 60 was owed). Automation
-- defaulted to on. From here on:
--
--   * `invoice_maturities` freezes, at issue, the date the invoice falls
--     due and on what basis: `document_term` (the workspace's explicit
--     payment term in force at issue — the term the document prints),
--     `default_term` (no explicit term: the app's 14-day default, which
--     nobody agreed to, so it needs review) or `unknown` (invoices issued
--     before this migration; no date is invented for them). Only a
--     `document_term` maturity allows automatic escalation.
--   * `invoice_dunning_state(invoice, at)` is the one eligibility answer
--     for the app, the manual action and the daily sweep: the collectible
--     remainder (total − confirmed payments − credit notes, zero after a
--     validated write-off), a pending payment as a hold that does not
--     make the balance disappear, an explicit dunning hold (dispute,
--     identity error, insolvency, other), a credit note in another
--     currency as a hold rather than a silent sum, whether the invoice is
--     still before its due date (a friendly pre-due notice) or overdue,
--     and the level that is due.
--   * Holds live in `invoice_dunning_holds`, placed and released only by
--     whoever may issue invoices in that workspace.
--   * Both reminder paths lock the invoice, then ask the state again, so
--     a payment or hold that arrived meanwhile wins; a reminder states
--     the collectible remainder, never the invoice total.
--   * A workspace whose rules never said `automatic` is no longer
--     automated: the key is written as false with `automatic_review` so
--     the owner decides. An explicit choice is kept.
--   * A reminder level creates no fee, interest or legal consequence.

-- ── the frozen maturity ──────────────────────────────────────────────
create table if not exists public.invoice_maturities (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null unique references public.invoices(id) on delete cascade,
  due_on date,
  basis text not null check (basis in ('document_term', 'default_term', 'unknown')),
  terms_days int check (terms_days between 0 and 365),
  evidence text not null,
  created_at timestamptz not null default now(),
  constraint invoice_maturities_dated check ((basis = 'unknown') = (due_on is null))
);
select public.ensure_system_columns('invoice_maturities');

alter table public.invoice_maturities enable row level security;
revoke all on table public.invoice_maturities from public, anon, authenticated;
grant select on table public.invoice_maturities to authenticated;
drop policy if exists mcp_delegated_deny on public.invoice_maturities;
create policy mcp_delegated_deny on public.invoice_maturities
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists invoice_maturities_select on public.invoice_maturities;
create policy invoice_maturities_select on public.invoice_maturities
  for select to authenticated
  using (public.has_permission(workspace_id, 'issueInvoices')
         or exists (select 1 from public.invoices i
                      join public.members m on m.id = i.member_id
                     where i.id = invoice_id and m.user_id = (select auth.uid())));

create or replace function public.invoice_maturity_freeze()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_rules jsonb;
  v_tz text;
  v_days int;
begin
  select coalesce(w.dunning_rules, '{}'::jsonb), coalesce(nullif(w.timezone, ''), 'UTC')
    into v_rules, v_tz
    from public.workspaces w where w.id = new.workspace_id;
  if v_rules ? 'first_after_days' then
    v_days := least(greatest((v_rules ->> 'first_after_days')::int, 0), 365);
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + v_days, 'document_term', v_days,
            format('the workspace payment term of %s days in force at issue', v_days));
  else
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + 14, 'default_term', 14,
            'no payment term configured; the app''s 14-day default needs review');
  end if;
  return new;
end $fn$;

revoke execute on function public.invoice_maturity_freeze() from public, anon, authenticated;

drop trigger if exists invoice_maturity_freeze on public.invoices;
create trigger invoice_maturity_freeze
  after insert on public.invoices
  for each row execute function public.invoice_maturity_freeze();

-- Invoices issued before today: no date is invented.
insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
select i.workspace_id, i.id, null, 'unknown', null,
       'issued before payment terms were recorded; review before any reminder escalates'
  from public.invoices i
 where not exists (select 1 from public.invoice_maturities m where m.invoice_id = i.id);

-- ── holds ────────────────────────────────────────────────────────────
create table if not exists public.invoice_dunning_holds (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  reason text not null check (reason in ('dispute', 'identity_error', 'insolvency', 'other')),
  note text not null default '' check (char_length(note) <= 500),
  placed_at timestamptz not null default now(),
  placed_by uuid references auth.users(id) on delete set null,
  released_at timestamptz,
  released_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('invoice_dunning_holds');
create unique index if not exists invoice_dunning_holds_one_active
  on public.invoice_dunning_holds (invoice_id) where released_at is null;

alter table public.invoice_dunning_holds enable row level security;
revoke all on table public.invoice_dunning_holds from public, anon, authenticated;
grant select on table public.invoice_dunning_holds to authenticated;
drop policy if exists mcp_delegated_deny on public.invoice_dunning_holds;
create policy mcp_delegated_deny on public.invoice_dunning_holds
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists invoice_dunning_holds_select on public.invoice_dunning_holds;
create policy invoice_dunning_holds_select on public.invoice_dunning_holds
  for select to authenticated
  using (public.has_permission(workspace_id, 'issueInvoices')
         or exists (select 1 from public.invoices i
                      join public.members m on m.id = i.member_id
                     where i.id = invoice_id and m.user_id = (select auth.uid())));

create or replace function public.place_dunning_hold(
  p_invoice_id uuid, p_reason text, p_note text default ''
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_id uuid;
begin
  select workspace_id into v_ws from public.invoices where id = p_invoice_id;
  if v_ws is null or auth.uid() is null or not public.has_permission(v_ws, 'issueInvoices') then
    raise exception 'only whoever issues the invoices of this space places a hold';
  end if;
  perform 1 from public.invoices where id = p_invoice_id for update;
  if exists (select 1 from public.invoice_dunning_holds
              where invoice_id = p_invoice_id and released_at is null) then
    raise exception 'this invoice is already on hold';
  end if;
  insert into public.invoice_dunning_holds (workspace_id, invoice_id, reason, note, placed_by)
  values (v_ws, p_invoice_id, p_reason, coalesce(btrim(p_note), ''), auth.uid())
  returning id into v_id;
  return v_id;
end $fn$;

revoke execute on function public.place_dunning_hold(uuid, text, text) from public, anon;
grant execute on function public.place_dunning_hold(uuid, text, text) to authenticated;

create or replace function public.release_dunning_hold(p_invoice_id uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
begin
  select workspace_id into v_ws from public.invoices where id = p_invoice_id;
  if v_ws is null or auth.uid() is null or not public.has_permission(v_ws, 'issueInvoices') then
    raise exception 'only whoever issues the invoices of this space releases a hold';
  end if;
  update public.invoice_dunning_holds
     set released_at = now(), released_by = auth.uid()
   where invoice_id = p_invoice_id and released_at is null;
  if not found then
    raise exception 'this invoice is not on hold';
  end if;
end $fn$;

revoke execute on function public.release_dunning_hold(uuid) from public, anon;
grant execute on function public.release_dunning_hold(uuid) to authenticated;

-- ── the one eligibility answer ──────────────────────────────────────
-- No permission check here: the callers check. Not callable by clients.
create or replace function public.invoice_dunning_state_core(
  p_invoice_id uuid, p_at timestamptz
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_mat public.invoice_maturities;
  v_match public.invoice_matches;
  v_rules jsonb;
  v_tz text;
  v_levels int;
  v_between int;
  v_today date;
  v_credits int;
  v_foreign int;
  v_confirmed int := 0;
  v_pending int := 0;
  v_written_off boolean := false;
  v_collectible int;
  v_count int;
  v_last timestamptz;
  v_hold text;
  v_level int;
  v_phase text;
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null then raise exception 'unknown invoice'; end if;
  select * into v_mat from public.invoice_maturities where invoice_id = p_invoice_id;
  select * into v_match from public.invoice_matches where invoice_id = p_invoice_id;
  select coalesce(w.dunning_rules, '{}'::jsonb), coalesce(nullif(w.timezone, ''), 'UTC')
    into v_rules, v_tz from public.workspaces w where w.id = v_inv.workspace_id;
  v_levels := least(greatest(coalesce((v_rules ->> 'levels')::int, 3), 1), 9);
  v_between := least(greatest(coalesce((v_rules ->> 'between_days')::int, 14), 1), 365);
  v_today := (p_at at time zone v_tz)::date;

  select coalesce(sum(-c.total_cents) filter (where c.currency = v_inv.currency), 0)::int,
         count(*) filter (where c.currency <> v_inv.currency)::int
    into v_credits, v_foreign
    from public.invoices c
   where c.replaces_invoice_id = v_inv.id and c.total_cents < 0 and c.voided_at is null;

  if v_match.id is not null then
    if v_match.status = 'confirmed' then
      v_confirmed := v_match.paid_cents;
      v_written_off := v_match.writeoff_at is not null;
    else
      v_pending := v_match.paid_cents;
    end if;
  end if;
  v_collectible := case
    when v_inv.voided_at is not null or v_inv.settled_by_invoice_id is not null or v_written_off then 0
    when v_match.resolution in ('exact', 'over_forced', 'over_credit_note', 'refunded')
         and v_match.status = 'confirmed' then 0
    else greatest(v_inv.total_cents - v_confirmed - v_credits, 0) end;

  select count(*), max(sent_at) into v_count, v_last
    from public.invoice_reminders r where r.invoice_id = p_invoice_id;

  select h.reason into v_hold from public.invoice_dunning_holds h
   where h.invoice_id = p_invoice_id and h.released_at is null;
  v_hold := coalesce(v_hold,
              case when v_foreign > 0 then 'mixed_currency'
                   when v_pending > 0 then 'pending_payment' end);

  v_phase := case
    when v_collectible = 0 then 'settled'
    when v_mat.due_on is null then 'unknown_maturity'
    when v_today < v_mat.due_on then 'pre_due'
    else 'overdue' end;

  v_level := case
    when v_phase <> 'overdue' or v_hold is not null or v_count >= v_levels then null
    when v_count = 0 then 1
    when v_today >= ((v_last at time zone v_tz)::date + v_between) then v_count + 1
    else null end;

  return jsonb_build_object(
    'invoice_id', v_inv.id,
    'currency', v_inv.currency,
    'total_cents', v_inv.total_cents,
    'confirmed_cents', v_confirmed,
    'credited_cents', v_credits,
    'pending_cents', v_pending,
    'written_off', v_written_off,
    'collectible_cents', v_collectible,
    'due_on', v_mat.due_on,
    'maturity_basis', coalesce(v_mat.basis, 'unknown'),
    'maturity_evidence', v_mat.evidence,
    'phase', v_phase,
    'hold', v_hold,
    'reminders_sent', v_count,
    'levels', v_levels,
    'level_due', v_level,
    'days_overdue', case when v_phase = 'overdue' then v_today - v_mat.due_on end,
    'automatic_allowed', v_level is not null and v_mat.basis = 'document_term');
end $fn$;

revoke execute on function public.invoice_dunning_state_core(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.invoice_dunning_state(
  p_invoice_id uuid, p_at timestamptz default now()
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_member uuid;
begin
  select workspace_id, member_id into v_ws, v_member from public.invoices where id = p_invoice_id;
  if v_ws is null or auth.uid() is null
     or not (public.has_permission(v_ws, 'issueInvoices')
             or exists (select 1 from public.members m
                         where m.id = v_member and m.user_id = auth.uid())) then
    raise exception 'not allowed to read the dunning state of this invoice';
  end if;
  return public.invoice_dunning_state_core(p_invoice_id, p_at);
end $fn$;

revoke execute on function public.invoice_dunning_state(uuid, timestamptz) from public, anon;
grant execute on function public.invoice_dunning_state(uuid, timestamptz) to authenticated;

-- ── the manual reminder asks the same question ──────────────────────
create or replace function public.record_invoice_reminder(p_invoice_id uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
  v_state jsonb;
  v_level int;
  v_event_id uuid;
  v_cfg public.push_config;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  -- #926: the invoice row lock makes state -> level -> insert atomic
  -- against a concurrent sweep or a second admin; the state is read
  -- AFTER the lock, so a payment or hold that arrived meanwhile wins.
  perform 1 from public.invoices where id = p_invoice_id for update;
  v_state := public.invoice_dunning_state_core(p_invoice_id, now());
  if (v_state ->> 'collectible_cents')::int = 0 then
    raise exception 'nothing is outstanding on this invoice';
  end if;
  if v_state ->> 'hold' in ('dispute', 'identity_error', 'insolvency', 'other', 'mixed_currency') then
    raise exception 'this invoice is on hold: %', v_state ->> 'hold';
  end if;
  v_level := least((v_state ->> 'reminders_sent')::int + 1, (v_state ->> 'levels')::int);
  insert into public.invoice_reminders
    (workspace_id, invoice_id, by_name, automatic, level)
  values (v_invoice.workspace_id, p_invoice_id, v_actor_name, false, v_level);
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values
    (v_invoice.workspace_id, 'invoice_reminder', 'created', v_actor.id,
     v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'level', v_level,
       'levels', (v_state ->> 'levels')::int,
       'amount_cents', (v_state ->> 'collectible_cents')::int,
       'currency', v_invoice.currency,
       'issued_at', v_invoice.issued_at,
       'due_on', v_state -> 'due_on',
       'phase', v_state ->> 'phase',
       'days_overdue', v_state -> 'days_overdue',
       'automatic', false),
     'applied')
  returning id into v_event_id;
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is not null then
    begin
      perform net.http_post(
        url := v_cfg.functions_url || '/send-push',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_cfg.anon_key,
          'Content-Type', 'application/json'),
        body := jsonb_build_object('event_id', v_event_id),
        timeout_milliseconds := 5000);
    exception when others then
      null;
    end;
  end if;
end;
$fn$;

revoke execute on function public.record_invoice_reminder(uuid) from public, anon;
grant execute on function public.record_invoice_reminder(uuid) to authenticated;

-- ── the sweep asks the same question ────────────────────────────────
create or replace function public.sweep_payment_reminders(p_workspace_id uuid default null)
returns integer
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws record;
  v_inv record;
  v_state jsonb;
  v_level int;
  v_owner uuid;
  v_event_id uuid;
  v_cfg public.push_config;
  v_total int := 0;
begin
  if auth.uid() is not null then
    if p_workspace_id is null then
      raise exception 'workspace required';
    end if;
    if not public.has_permission(p_workspace_id, 'issueInvoices') then
      raise exception 'not an admin of this workspace';
    end if;
  end if;

  for v_ws in
    select w.id
      from public.workspaces w
     where (p_workspace_id is null or w.id = p_workspace_id)
       and public.feature_effective_in(w.feature_flags, 'paymentReminders')
       -- #1913: automation is an explicit owner choice, never a default.
       and coalesce((w.dunning_rules ->> 'automatic')::boolean, false)
  loop
    select id into v_owner from public.members
      where workspace_id = v_ws.id and is_owner and status = 'active'
      limit 1;
    if v_owner is null then continue; end if;

    for v_inv in
      select i.id, i.number, i.member_id, i.issued_at, i.currency
        from public.invoices i
       where i.workspace_id = v_ws.id
         and i.voided_at is null
         and i.total_cents > 0
         and i.settled_by_invoice_id is null
    loop
      -- #926: same lock as the manual path, per invoice; the state is
      -- read after it, so a concurrent sweep sees the level just sent.
      perform 1 from public.invoices where id = v_inv.id for update;
      v_state := public.invoice_dunning_state_core(v_inv.id, now());
      if not coalesce((v_state ->> 'automatic_allowed')::boolean, false) then continue; end if;
      v_level := (v_state ->> 'level_due')::int;

      insert into public.invoice_reminders (workspace_id, invoice_id, by_name, automatic, level)
      values (v_ws.id, v_inv.id, '', true, v_level);

      insert into public.events
        (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
      values
        (v_ws.id, 'invoice_reminder', 'created', v_owner, v_inv.member_id,
         jsonb_build_object(
           'invoice_id', v_inv.id,
           'number', v_inv.number,
           'level', v_level,
           'levels', (v_state ->> 'levels')::int,
           'amount_cents', (v_state ->> 'collectible_cents')::int,
           'currency', v_inv.currency,
           'issued_at', v_inv.issued_at,
           'due_on', v_state -> 'due_on',
           'phase', v_state ->> 'phase',
           'days_overdue', v_state -> 'days_overdue',
           'automatic', true),
         'applied')
      returning id into v_event_id;

      select * into v_cfg from public.push_config where id;
      if v_cfg.functions_url is not null then
        begin
          perform net.http_post(
            url := v_cfg.functions_url || '/send-push',
            headers := jsonb_build_object(
              'Authorization', 'Bearer ' || v_cfg.anon_key,
              'Content-Type', 'application/json'),
            body := jsonb_build_object('event_id', v_event_id),
            timeout_milliseconds := 5000);
        exception when others then
          null;
        end;
      end if;
      v_total := v_total + 1;
    end loop;
  end loop;
  return v_total;
end;
$fn$;

revoke execute on function public.sweep_payment_reminders(uuid) from public, anon;
grant execute on function public.sweep_payment_reminders(uuid) to authenticated;

-- ── an automation nobody chose is off until somebody does ───────────
update public.workspaces
   set dunning_rules = coalesce(dunning_rules, '{}'::jsonb)
                       || '{"automatic": false, "automatic_review": true}'::jsonb
 where not (coalesce(dunning_rules, '{}'::jsonb) ? 'automatic');

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(331);
