-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0334 (#1922) — a reminder row is an intent; what happened to it is
-- evidence, recorded as it happens and never rewritten.
--
-- `invoice_reminders` said "sent" the moment a row was written. The push
-- that followed was best effort and its failures were swallowed, so the
-- app could not tell a delivered reminder from one that never left. From
-- here on:
--
--   * every reminder has a `reminder_intents` row: which invoice, which
--     level, who prepared it (manual, automatic) and the collectible
--     amount it was prepared for (#1913's `invoice_dunning_state`);
--   * `reminder_attempts` is append-only (a trigger refuses update and
--     delete): `queued` (handed to the push queue, with its request id),
--     `provider_accepted` (the push service accepted it for at least one
--     device — NOT proof of receipt and NOT legal service), `failed`,
--     `unknown` (no answer within the hour: reconciled, never blindly
--     re-sent) and `declared_delivered` (the sender confirmed the share
--     sheet completed — the sender's statement, not a provider receipt);
--   * `reconcile_reminder_attempts` turns queued pushes into outcomes from
--     the queue's own responses, hourly, and is safe to run twice;
--   * reminders recorded before this migration keep their row and get an
--     intent whose status is `legacy_unknown`: nothing can prove what
--     happened to them, so nothing claims it did;
--   * evidence is read by whoever issues invoices in that space and by
--     the member the invoice is addressed to, through
--     `invoice_reminder_evidence`, and by nobody else. The push itself
--     stays generic (no number, no amount) — unchanged.
--
-- A transport success changes nothing about the invoice: it is not paid,
-- the debt is not "served", nothing is posted.

create table if not exists public.reminder_intents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  reminder_id uuid unique references public.invoice_reminders(id) on delete cascade,
  level int not null check (level between 1 and 9),
  origin text not null check (origin in ('manual', 'automatic', 'legacy')),
  status text not null default 'prepared'
    check (status in ('prepared', 'queued', 'provider_accepted', 'declared_delivered',
                      'failed', 'unknown', 'legacy_unknown')),
  collectible_cents int,
  currency text,
  prepared_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('reminder_intents');
create index if not exists reminder_intents_by_invoice
  on public.reminder_intents (invoice_id, level);

create table if not exists public.reminder_attempts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  intent_id uuid not null references public.reminder_intents(id) on delete cascade,
  channel text not null check (channel in ('push', 'share')),
  outcome text not null
    check (outcome in ('queued', 'provider_accepted', 'declared_delivered', 'failed', 'unknown')),
  net_request_id bigint,
  detail text not null default '' check (char_length(detail) <= 300),
  at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('reminder_attempts');
create index if not exists reminder_attempts_by_intent
  on public.reminder_attempts (intent_id, at);
create index if not exists reminder_attempts_queued
  on public.reminder_attempts (net_request_id) where outcome = 'queued';

-- Evidence is appended, never rewritten.
create or replace function public.reminder_attempts_append_only()
returns trigger
language plpgsql set search_path = public as $fn$
begin
  raise exception 'reminder evidence is appended, never rewritten';
end $fn$;
revoke execute on function public.reminder_attempts_append_only() from public, anon, authenticated;
drop trigger if exists reminder_attempts_append_only on public.reminder_attempts;
create trigger reminder_attempts_append_only
  before update or delete on public.reminder_attempts
  for each row execute function public.reminder_attempts_append_only();

alter table public.reminder_intents enable row level security;
revoke all on table public.reminder_intents from public, anon, authenticated;
grant select on table public.reminder_intents to authenticated;
drop policy if exists mcp_delegated_deny on public.reminder_intents;
create policy mcp_delegated_deny on public.reminder_intents
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.reminder_attempts enable row level security;
revoke all on table public.reminder_attempts from public, anon, authenticated;
grant select on table public.reminder_attempts to authenticated;
drop policy if exists mcp_delegated_deny on public.reminder_attempts;
create policy mcp_delegated_deny on public.reminder_attempts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

drop policy if exists reminder_intents_select on public.reminder_intents;
create policy reminder_intents_select on public.reminder_intents
  for select to authenticated
  using (public.has_permission(workspace_id, 'issueInvoices')
         or exists (select 1 from public.invoices i
                      join public.members m on m.id = i.member_id
                     where i.id = invoice_id and m.user_id = (select auth.uid())));
drop policy if exists reminder_attempts_select on public.reminder_attempts;
create policy reminder_attempts_select on public.reminder_attempts
  for select to authenticated
  using (exists (select 1 from public.reminder_intents ri where ri.id = intent_id));

-- ── legacy: the rows already written prove nothing more than a row ──
insert into public.reminder_intents
  (workspace_id, invoice_id, reminder_id, level, origin, status, prepared_at)
select r.workspace_id, r.invoice_id, r.id, least(greatest(r.level, 1), 9), 'legacy',
       'legacy_unknown', r.sent_at
  from public.invoice_reminders r
 where not exists (select 1 from public.reminder_intents ri where ri.reminder_id = r.id);

-- ── one helper: queue the generic push and record what happened ─────
-- Not callable by clients.
create or replace function public.reminder_queue_push(p_intent_id uuid, p_event_id uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_cfg public.push_config;
  v_ws uuid;
  v_request bigint;
begin
  select workspace_id into v_ws from public.reminder_intents where id = p_intent_id;
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is null then
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
    values (v_ws, p_intent_id, 'push', 'failed', 'push delivery is not configured on this installation');
    update public.reminder_intents set status = 'failed'
     where id = p_intent_id and status = 'prepared';
    return;
  end if;
  begin
    v_request := net.http_post(
      url := v_cfg.functions_url || '/send-push',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_cfg.anon_key,
        'Content-Type', 'application/json'),
      body := jsonb_build_object('event_id', p_event_id),
      timeout_milliseconds := 5000);
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, net_request_id)
    values (v_ws, p_intent_id, 'push', 'queued', v_request);
    update public.reminder_intents set status = 'queued'
     where id = p_intent_id and status = 'prepared';
  exception when others then
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
    values (v_ws, p_intent_id, 'push', 'failed', 'the push request could not be queued');
    update public.reminder_intents set status = 'failed'
     where id = p_intent_id and status = 'prepared';
  end;
end $fn$;

revoke execute on function public.reminder_queue_push(uuid, uuid) from public, anon, authenticated;

-- ── the manual path: the client calls it only after the share sheet
-- completed (#1532), so that is what it records — as the sender's
-- declaration, not as a receipt.
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
  v_reminder_id uuid;
  v_intent_id uuid;
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
  values (v_invoice.workspace_id, p_invoice_id, v_actor_name, false, v_level)
  returning id into v_reminder_id;
  insert into public.reminder_intents
    (workspace_id, invoice_id, reminder_id, level, origin, status, collectible_cents, currency)
  values (v_invoice.workspace_id, p_invoice_id, v_reminder_id, v_level, 'manual',
          'declared_delivered', (v_state ->> 'collectible_cents')::int, v_invoice.currency)
  returning id into v_intent_id;
  insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
  values (v_invoice.workspace_id, v_intent_id, 'share', 'declared_delivered',
          'the sender confirmed the share sheet completed; not a receipt');
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
       'intent_id', v_intent_id,
       'automatic', false),
     'applied')
  returning id into v_event_id;
  perform public.reminder_queue_push(v_intent_id, v_event_id);
  -- The share declaration is the stronger statement; a push outcome does
  -- not overwrite it.
  update public.reminder_intents set status = 'declared_delivered' where id = v_intent_id;
end;
$fn$;

revoke execute on function public.record_invoice_reminder(uuid) from public, anon;
grant execute on function public.record_invoice_reminder(uuid) to authenticated;

-- ── the automatic path ──────────────────────────────────────────────
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
  v_reminder_id uuid;
  v_intent_id uuid;
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
      values (v_ws.id, v_inv.id, '', true, v_level)
      returning id into v_reminder_id;
      insert into public.reminder_intents
        (workspace_id, invoice_id, reminder_id, level, origin, collectible_cents, currency)
      values (v_ws.id, v_inv.id, v_reminder_id, v_level, 'automatic',
              (v_state ->> 'collectible_cents')::int, v_inv.currency)
      returning id into v_intent_id;

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
           'intent_id', v_intent_id,
           'automatic', true),
         'applied')
      returning id into v_event_id;

      perform public.reminder_queue_push(v_intent_id, v_event_id);
      v_total := v_total + 1;
    end loop;
  end loop;
  return v_total;
end;
$fn$;

revoke execute on function public.sweep_payment_reminders(uuid) from public, anon;
grant execute on function public.sweep_payment_reminders(uuid) to authenticated;

-- ── reconciliation: the queue's answer becomes the outcome ──────────
create or replace function public.reconcile_reminder_attempts()
returns int
language plpgsql security definer set search_path = public as $fn$
declare
  v_a record;
  v_resp record;
  v_outcome text;
  v_detail text;
  v_count int := 0;
begin
  for v_a in
    select a.* from public.reminder_attempts a
     where a.outcome = 'queued'
       and not exists (select 1 from public.reminder_attempts b
                        where b.intent_id = a.intent_id and b.channel = a.channel
                          and b.outcome <> 'queued' and b.at >= a.at)
     order by a.at
     for update skip locked
  loop
    select r.status_code, r.timed_out, r.error_msg, r.content into v_resp
      from net._http_response r where r.id = v_a.net_request_id;
    if not found then
      if v_a.at > now() - interval '1 hour' then continue; end if;
      v_outcome := 'unknown';
      v_detail := 'the push queue gave no answer within an hour';
    elsif v_resp.status_code between 200 and 299
          and coalesce(v_resp.content, '') ~ '"sent"\s*:\s*[1-9]' then
      v_outcome := 'provider_accepted';
      v_detail := 'the push service accepted it for at least one device; not proof of receipt';
    elsif v_resp.status_code between 200 and 299 then
      v_outcome := 'failed';
      v_detail := 'no device could receive it';
    else
      v_outcome := 'failed';
      v_detail := 'the push request failed';
    end if;
    insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, net_request_id, detail)
    values (v_a.workspace_id, v_a.intent_id, v_a.channel, v_outcome, v_a.net_request_id, v_detail);
    update public.reminder_intents set status = v_outcome
     where id = v_a.intent_id and status in ('prepared', 'queued');
    v_count := v_count + 1;
  end loop;
  return v_count;
end $fn$;

revoke execute on function public.reconcile_reminder_attempts() from public, anon, authenticated;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-reminder-reconcile')
    where exists (select 1 from cron.job where jobname = 'deskilo-reminder-reconcile');
  perform cron.schedule('deskilo-reminder-reconcile', '17 * * * *',
    $job$select public.reconcile_reminder_attempts()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs reconcile_reminder_attempts() instead', sqlerrm;
end
$cron$;

-- ── who may read the evidence ───────────────────────────────────────
create or replace function public.invoice_reminder_evidence(p_invoice_id uuid)
returns jsonb
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
    raise exception 'not allowed to read the reminder evidence of this invoice';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
            'intent_id', ri.id, 'level', ri.level, 'origin', ri.origin, 'status', ri.status,
            'collectible_cents', ri.collectible_cents, 'currency', ri.currency,
            'prepared_at', ri.prepared_at,
            'attempts', (select coalesce(jsonb_agg(jsonb_build_object(
                            'channel', a.channel, 'outcome', a.outcome, 'detail', a.detail, 'at', a.at)
                            order by a.at, a.id), '[]'::jsonb)
                           from public.reminder_attempts a where a.intent_id = ri.id))
            order by ri.prepared_at, ri.id), '[]'::jsonb)
            from public.reminder_intents ri where ri.invoice_id = p_invoice_id);
end $fn$;

revoke execute on function public.invoice_reminder_evidence(uuid) from public, anon;
grant execute on function public.invoice_reminder_evidence(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(334);
