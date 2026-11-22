-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (events gains a type; event_type_view_permissions, event_type_waits_for_decision and export_my_data are
--  patched at asserted anchors; new functions, a trigger, a unique index and a job; the settings registry
--  gains one setting)
--
-- #4325: an e-invoice attempt that stopped half-way is picked up on a schedule and shown to the owner.
--
--   * `einvoice_sweep()` runs every five minutes for every business: a dispatch whose own deadline has
--     passed with no outcome becomes `uncertain` (what `expire_einvoice_dispatches_v1` does inside a later
--     request of the same business, now with no request), and every `uncertain` transmission, and every
--     `prepared` one that has waited longer than `einvoice.stuck_attempt_minutes`, is told to those who
--     may issue invoices: one inbox event `einvoice_outcome_unknown` per transmission while it is open (the
--     form `stock_low` and `payment_attempt_unreadable` set: the owner is its actor and subject, it is
--     nobody's decision, and the owner's own export leaves it out). The sweep sends nothing: it moves no
--     transmission to a state a claim could send from, and calls no provider.
--   * The notice ends, with the phase the transmission moved to, when that transmission changes phase:
--     a late outcome, a manual resolution, a claim of a prepared one.
--   * The window is a platform setting (`einvoice.stuck_attempt_minutes`, default 60, 5 minutes to 7
--     days), with its place in the settings screen and in the setup questionnaire.

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

-- ── the setting ──────────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('einvoice.stuck_attempt_minutes', 'duration', '60'::jsonb, 5, 10080, 'minutes', 'billing', array['platform'], 'manageBilling', null, true, null, 'einvoice_sweep (0863)', 'How long an e-invoice may stay prepared, with no dispatch claimed, before the owner is told that its attempt stopped half-way. A dispatch whose own deadline passed with no outcome is told as soon as the sweep runs.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the type ─────────────────────────────────────────────────────────────
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events', 'events_type_check', 'type'),
    ('validation_policies', 'validation_policies_event_type_check', 'event_type')
  ) as c(table_name, constraint_name, column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid = ('public.' || r.table_name)::regclass and conname = r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception '0863: the event type constraint % is not there', r.constraint_name using errcode = 'P0001';
    end if;
    if position('einvoice_outcome_unknown' in v_def) = 0 then
      execute format('alter table public.%I drop constraint %I', r.table_name, r.constraint_name);
      execute format('alter table public.%I add constraint %I ', r.table_name, r.constraint_name)
        || replace(v_def, 'CHECK (', format('CHECK (%I = %L OR ', r.column_name, 'einvoice_outcome_unknown'));
    end if;
  end loop;
end;
$constraints$;

do $patch$
declare
  v_def text;
  v_next text;
begin
  -- who reads it: those who may issue invoices
  v_def := pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$ else array['manageConfiguration']$o$,
    $n$ when p_type = 'einvoice_outcome_unknown' then array['issueInvoices'] else array['manageConfiguration']$n$);
  if v_next is null then raise exception '0863: the anchor of event_type_view_permissions is not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- a notice nobody decides
  v_def := pg_get_functiondef('public.event_type_waits_for_decision(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def, $o$'settlement_review', 'stock_low')$o$, $n$'settlement_review', 'stock_low', 'einvoice_outcome_unknown')$n$);
  if v_next is null then raise exception '0863: the anchor of event_type_waits_for_decision is not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- the owner is its actor and subject: it is not the owner's own data
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$and e.type not in ('payment_attempt_unreadable', 'stock_low')$o$,
    $n$and e.type not in ('payment_attempt_unreadable', 'stock_low', 'einvoice_outcome_unknown')$n$);
  if v_next is null then raise exception '0863: the anchor of export_my_data is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- one open notice per transmission, held by the database
create unique index if not exists events_einvoice_unknown_open_once on public.events ((payload ->> 'transmission'))
  where type = 'einvoice_outcome_unknown' and not (payload ? 'ended');

-- ── the notice ───────────────────────────────────────────────────────────
-- Opens [p_transmission]'s notice when it is uncertain, or prepared and past the window, and has none.
-- The owner is its actor and subject; without an active owner nobody is told. True when it opened one.
create or replace function public.einvoice_unknown_notice(p_transmission uuid)
returns boolean language plpgsql security definer set search_path = public as $fn$
declare
  t public.invoice_transmissions;
  v_actor uuid;
  v_n integer;
begin
  select * into t from public.invoice_transmissions where id = p_transmission for share;
  if t.id is null or t.phase not in ('prepared', 'uncertain') then return false; end if;
  select m.id into v_actor from public.members m
   where m.workspace_id = t.workspace_id and m.is_owner and m.status = 'active'
   order by m.joined_at, m.id limit 1;
  if v_actor is null then return false; end if;
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (t.workspace_id, 'einvoice_outcome_unknown', 'created', v_actor, v_actor,
          jsonb_build_object('transmission', t.id, 'invoice_id', t.invoice_id, 'phase', t.phase,
                             'provider', t.provider, 'destination', t.destination,
                             'environment', t.environment),
          'applied')
  on conflict ((payload ->> 'transmission')) where type = 'einvoice_outcome_unknown' and not (payload ? 'ended') do nothing;
  get diagnostics v_n = row_count;
  return v_n > 0;
end;
$fn$;
revoke execute on function public.einvoice_unknown_notice(uuid) from public, anon, authenticated;

-- The open notice of [p_transmission] ends, with the phase it moved to.
create or replace function public.einvoice_unknown_notice_end(p_transmission uuid, p_phase text)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  update public.events e
     set payload = e.payload || jsonb_build_object('ended', p_phase, 'ended_at', now())
   where e.type = 'einvoice_outcome_unknown'
     and e.payload ->> 'transmission' = p_transmission::text
     and not (e.payload ? 'ended');
end;
$fn$;
revoke execute on function public.einvoice_unknown_notice_end(uuid, text) from public, anon, authenticated;

-- A transmission that changes phase ends its notice. A notice is never a reason for an outcome not to be
-- recorded: whatever fails while ending it is a warning and the write stands, except what passes on a retry
-- (a rollback, a lack of resources, a lock not available), which is raised again.
create or replace function public.invoice_transmission_ends_notice()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  begin
    perform public.einvoice_unknown_notice_end(new.id, new.phase);
  exception when others then
    if left(sqlstate, 2) in ('40', '53') or sqlstate = '55P03' then
      raise;
    end if;
    raise warning 'the notice of e-invoice transmission % was not ended (%)', new.id, sqlstate;
  end;
  return new;
end;
$fn$;
revoke execute on function public.invoice_transmission_ends_notice() from public, anon, authenticated;

drop trigger if exists invoice_transmissions_end_notice on public.invoice_transmissions;
create trigger invoice_transmissions_end_notice after update of phase on public.invoice_transmissions
  for each row when (old.phase is distinct from new.phase and old.phase in ('prepared', 'uncertain'))
  execute function public.invoice_transmission_ends_notice();

-- ── the sweep ────────────────────────────────────────────────────────────
-- Every business, no request. Returns what it did: how many dispatches it expired and how many notices
-- it opened. It sends nothing and calls no provider.
create or replace function public.einvoice_sweep()
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_window interval := make_interval(mins => (public.setting_value(null, 'einvoice.stuck_attempt_minutes') #>> '{}')::int);
  v_expired integer;
  v_told integer := 0;
  r record;
begin
  update public.invoice_transmissions set phase = 'uncertain'
   where phase = 'sent' and deadline is not null and deadline < now();
  get diagnostics v_expired = row_count;
  for r in
    select t.id from public.invoice_transmissions t
     where t.phase = 'uncertain'
        or (t.phase = 'prepared' and t.modified_datetime < now() - v_window)
     order by t.workspace_id, t.id
  loop
    if public.einvoice_unknown_notice(r.id) then v_told := v_told + 1; end if;
  end loop;
  return jsonb_build_object('expired', v_expired, 'told', v_told);
end;
$fn$;
revoke execute on function public.einvoice_sweep() from public, anon, authenticated;
grant execute on function public.einvoice_sweep() to service_role;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-einvoice-sweep')
    where exists (select 1 from cron.job where jobname = 'deskilo-einvoice-sweep');
  perform cron.schedule('deskilo-einvoice-sweep', '*/5 * * * *', $job$select public.einvoice_sweep()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs einvoice_sweep() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(863);
