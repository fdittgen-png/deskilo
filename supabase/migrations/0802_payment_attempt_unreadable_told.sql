-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two event type constraints gain one type; event_type_view_permissions and
--  payment_reconciliation_finish_v1 are restated whole; calendar_items and
--  export_my_data are patched at asserted anchors; 0667's restrictive policy
--  on events becomes one rule for every type; helpers, a trigger and a unique
--  index are new)
--
-- #4136 -- a payment attempt the reconciliation (0798) cannot read at its
-- provider is told to those who read the business's finances (viewFinances):
-- one event `payment_attempt_unreadable` per attempt, naming the payment (its
-- reference, amount and provider), the member who pays it (`member_id` in
-- its payload, whose account the notice opens) and the reason word; since when is
-- the event's own time. A later run that still cannot read it names its
-- latest reason on the same notice, never a second one. The notice ends when
-- the attempt is read (`ended`: read), settled (settled) or ended otherwise
-- (ended), with the time; an attempt is told once, even if it becomes
-- unreadable again after a read: the same notice opens again. Only those who
-- read the finances read it:
-- the member it names does not, unless they hold that right themselves. The
-- owner is its actor and subject, never the member it names: what reads a
-- member's events as theirs (their export, an assistant's lists) never
-- reaches it, and the owner's own export leaves it out.
--
-- The calendar's events follow each event type's reading rule: what
-- calendar_items returns of an event, or of a decision on one, is what the
-- events table's own row rules would show the caller (event_readable). The
-- restrictive rule of each type lives in one function
-- (event_type_restriction_holds), read by the table's policy and by the
-- calendar alike.

-- ── the type ─────────────────────────────────────────────────────────────
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name using errcode = 'P0001';
    end if;
    if position('payment_attempt_unreadable' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'payment_attempt_unreadable'));
    end if;
  end loop;
end;
$constraints$;

-- ── who reads it ─────────────────────────────────────────────────────────
-- Restated whole from 0796: the new type is read with viewFinances.
create or replace function public.event_type_view_permissions(p_type text)
returns text[] language sql immutable set search_path = public as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_payment_reversed',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    when p_type = 'lease_change'
      then array['manageLease', 'viewFinances']
    when p_type = 'commitment_variance'
      then array['managePurchases', 'viewFinances']
    when p_type = 'badge_security_alert'
      then array['workspaceSettings']
    when p_type in ('payment_instructions_change', 'credential_change')
      then array['manageIntegrations']
    when p_type = 'privacy_incident'
      then array['managePrivacy']
    when p_type = 'invoice_issued'
      then array['viewFinances', 'issueInvoices']
    when p_type in ('settlement_review', 'payment_attempt_unreadable')
      then array['viewFinances']
    when p_type = 'kiosk_device'
      then array['workspaceSettings']
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public,anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- ── each type's reading rule, in one place ──────────────────────────────
-- What a type requires on top of events_select, whatever else lets a row in
-- (a validator's rule, the subject's own read): a privacy incident is read
-- with managePrivacy (0667), an attempt not checked with viewFinances.
-- Inlined into the policy: no search_path, every name qualified.
create or replace function public.event_type_restriction_holds(p_workspace_id uuid, p_type text)
returns boolean language sql stable as $fn$
  select case p_type
    when 'privacy_incident' then public.has_permission(p_workspace_id, 'managePrivacy')
    when 'payment_attempt_unreadable' then public.has_permission(p_workspace_id, 'viewFinances')
    else true
  end;
$fn$;
revoke execute on function public.event_type_restriction_holds(uuid, text) from public, anon;
grant execute on function public.event_type_restriction_holds(uuid, text) to authenticated;

drop policy if exists privacy_incident_holders_only on public.events;
drop policy if exists event_type_reading_rule on public.events;
create policy event_type_reading_rule on public.events
  as restrictive for select to authenticated
  using (public.event_type_restriction_holds(workspace_id, type));

-- Whether the caller may read an event of [p_type] in [p_workspace_id] whose
-- actor and subject are [p_actor] and [p_subject]: events_select's three ways
-- in (0216: the type's reading right, their own event, a validator's rule)
-- and the type's restrictive rule. For what reads events past the table's
-- rules (a definer function) and must show no more than they would.
create or replace function public.event_readable(p_workspace_id uuid, p_type text, p_actor uuid, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.event_type_restriction_holds(p_workspace_id, p_type)
     and ((p_workspace_id, p_type) in (select v.ws_id, v.event_type from public.event_types_in_view() v)
          or exists (select 1 from public.members m
                      where m.user_id = auth.uid() and m.id in (p_actor, p_subject))
          or public.may_validate_event_type(p_workspace_id, p_type));
$fn$;
revoke execute on function public.event_readable(uuid, text, uuid, uuid) from public, anon, authenticated;

-- ── the calendar shows what the table would ──────────────────────────────
-- Its events and its decisions on events, each at one asserted anchor of
-- its live definition.
do $patch$
declare
  v_def text := pg_get_functiondef('public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure);
  v_events constant text := $a$       and (v_admin or e.actor_member_id = v_me.id or e.subject_member_id = v_me.id);$a$;
  v_decisions constant text := $a$            or e.subject_member_id = v_me.id or d.member_id = v_me.id);$a$;
begin
  if (length(v_def) - length(replace(v_def, v_events, ''))) / length(v_events) <> 1
     or (length(v_def) - length(replace(v_def, v_decisions, ''))) / length(v_decisions) <> 1 then
    raise exception 'calendar_items: an anchor of its event reads is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_events, rtrim(v_events, ';')
    || E'\n       and public.event_readable(e.workspace_id, e.type, e.actor_member_id, e.subject_member_id);');
  v_def := replace(v_def, v_decisions, rtrim(v_decisions, ';')
    || E'\n       and public.event_readable(e.workspace_id, e.type, e.actor_member_id, e.subject_member_id);');
  execute v_def;
end;
$patch$;

-- ── the owner's own export ───────────────────────────────────────────────
-- A notice names another member's payment: it is not the owner's data.
do $patch$
declare
  v_def text := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_old constant text := $a$                where e.actor_member_id = v_me.id or e.subject_member_id = v_me.id),$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'export_my_data: the anchor of its events is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$                where (e.actor_member_id = v_me.id or e.subject_member_id = v_me.id)
                  and e.type <> 'payment_attempt_unreadable'),$a$);
end;
$patch$;

-- ── the notice ───────────────────────────────────────────────────────────
-- One notice per attempt, held by the database (0723's precedent); every
-- settlement looks its attempt's notice up by it.
create unique index if not exists events_payment_attempt_notice_once
  on public.events ((payload ->> 'intent'))
  where type = 'payment_attempt_unreadable';

-- [p_intent] of [p_workspace_id] could not be read for [p_reason]: its one
-- notice, raised the first time; later, its reason kept current, and opened
-- again if a read had ended it. Nothing for an attempt no longer open (a
-- notification settled it while the run asked its provider).
-- The owner is its actor and subject (the job has no member; the member it
-- names is in its payload only); without an active owner nobody is told.
-- Called under the run's lease only.
create or replace function public.payment_attempt_notice(p_workspace_id uuid, p_intent uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  v_intent public.payment_intents;
  v_notice uuid;
  v_actor uuid;
begin
  select * into v_intent from public.payment_intents
   where id = p_intent and workspace_id = p_workspace_id
   for share;
  if v_intent.id is null or v_intent.status <> 'created' then return; end if;
  select e.id into v_notice from public.events e
   where e.workspace_id = p_workspace_id and e.type = 'payment_attempt_unreadable'
     and e.payload ->> 'intent' = p_intent::text
   order by e.created_at, e.id limit 1;
  if v_notice is not null then
    update public.events
       set payload = (payload - 'ended' - 'ended_at') || jsonb_build_object('reason', p_reason)
     where id = v_notice
       and (payload ? 'ended' or payload ->> 'reason' is distinct from p_reason);
    return;
  end if;
  select m.id into v_actor from public.members m
   where m.workspace_id = p_workspace_id and m.is_owner and m.status = 'active'
   order by m.joined_at, m.id limit 1;
  if v_actor is null then return; end if;
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (p_workspace_id, 'payment_attempt_unreadable', 'created', v_actor, v_actor,
          jsonb_build_object('intent', v_intent.id, 'member_id', v_intent.member_id,
                             'reference', v_intent.reference,
                             'provider', v_intent.provider, 'amount_cents', v_intent.amount_cents,
                             'currency', v_intent.currency, 'reason', p_reason),
          'applied')
  on conflict ((payload ->> 'intent')) where type = 'payment_attempt_unreadable' do nothing;
end;
$fn$;
revoke execute on function public.payment_attempt_notice(uuid, uuid, text) from public, anon, authenticated;

-- The open notice of [p_intent] ends: read, settled or ended. A late capture
-- of an attempt that had failed turns its end into settled.
create or replace function public.payment_attempt_notice_end(p_intent uuid, p_how text)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if p_how not in ('read', 'settled', 'ended') then
    raise exception 'unknown end of a notice: %', p_how using errcode = '22023';
  end if;
  update public.events e
     set payload = e.payload || jsonb_build_object('ended', p_how, 'ended_at', now())
   where e.workspace_id = (select i.workspace_id from public.payment_intents i where i.id = p_intent)
     and e.type = 'payment_attempt_unreadable'
     and e.payload ->> 'intent' = p_intent::text
     and (not (e.payload ? 'ended')
          or (p_how = 'settled' and e.payload ->> 'ended' = 'ended'));
end;
$fn$;
revoke execute on function public.payment_attempt_notice_end(uuid, text) from public, anon, authenticated;

-- An attempt settled or ended by any path (a notification, the
-- reconciliation, a person) ends its notice. A notice is never a reason for
-- a payment not to settle: whatever fails while ending it is a warning, and
-- the status change stands. Only what passes on a retry is raised again, so
-- the whole settlement is retried: a transaction rollback (class 40), a lack
-- of resources (class 53), a lock not available (55P03) -- as #3556's claim
-- application does.
create or replace function public.payment_intent_ends_notice()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  begin
    perform public.payment_attempt_notice_end(new.id,
      case when new.status = 'captured' then 'settled' else 'ended' end);
  exception when others then
    if left(sqlstate, 2) in ('40', '53') or sqlstate = '55P03' then
      raise;
    end if;
    raise warning 'the notice of payment attempt % was not ended (%)', new.id, sqlstate;
  end;
  return new;
end;
$fn$;
revoke execute on function public.payment_intent_ends_notice() from public, anon, authenticated;

drop trigger if exists payment_intents_end_notice on public.payment_intents;
create trigger payment_intents_end_notice after update of status on public.payment_intents
  for each row when (old.status is distinct from new.status
                     and (old.status = 'created' or new.status = 'captured'))
  execute function public.payment_intent_ends_notice();

-- ── the run tells ────────────────────────────────────────────────────────
-- Restated whole from 0798; new: the notices, before the checks of attempts
-- no longer open are removed.
create or replace function public.payment_reconciliation_finish_v1(
  p_workspace_id uuid, p_lease_token uuid, p_result jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $fn$
declare
  v_state public.payment_reconciliation_state;
  v_result jsonb := case when jsonb_typeof(p_result) = 'object' then p_result else '{}'::jsonb end;
  v_counts jsonb := '{}'::jsonb;
  v_malformed text[] := '{}';
  v_key text;
  v_unreadable jsonb;
begin
  select * into v_state from public.payment_reconciliation_state
   where workspace_id = p_workspace_id
   for update;
  if not found or v_state.lease_token is distinct from p_lease_token then
    return false;
  end if;
  foreach v_key in array array['read', 'settled', 'ended', 'left', 'abandoned'] loop
    if v_result ? v_key and not (jsonb_typeof(v_result -> v_key) = 'number'
                                 and (v_result ->> v_key) ~ '^[0-9]{1,9}$') then
      v_malformed := v_malformed || v_key;
      v_counts := v_counts || jsonb_build_object(v_key, 0);
    else
      v_counts := v_counts || jsonb_build_object(v_key, coalesce((v_result ->> v_key)::integer, 0));
    end if;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('intent', i.id, 'reason', e ->> 'reason')
                            order by i.id), '[]'::jsonb)
    into v_unreadable
    from jsonb_array_elements(case when jsonb_typeof(v_result -> 'unreadable') = 'array'
                                   then v_result -> 'unreadable' else '[]'::jsonb end) e
    join public.payment_intents i
      on i.id::text = e ->> 'intent' and i.workspace_id = p_workspace_id
   where i.id = any (v_state.claimed)
     and e ->> 'reason' in ('unreachable', 'refused', 'not_configured', 'unknown_order', 'mismatch',
                            'unexpected_answer', 'record_failed', 'approved_not_captured');
  insert into public.payment_reconciliation_checks
    (intent_id, workspace_id, last_checked_at, checks, seen_state, seen_client)
  select i.id, p_workspace_id, now(),
         case when i.created_at < now() - public.payment_open_lifetime(i.provider) then 1 else 0 end,
         case when e ->> 'seen_state' ~ '^[A-Z_]{1,32}$' then e ->> 'seen_state' end,
         case when e ->> 'seen_client' ~ '^[0-9a-f]{16,64}$' then e ->> 'seen_client' end
    from jsonb_array_elements(case when jsonb_typeof(v_result -> 'read_items') = 'array'
                                   then v_result -> 'read_items' else '[]'::jsonb end) e
    join public.payment_intents i
      on i.id::text = e ->> 'intent' and i.workspace_id = p_workspace_id
   where i.id = any (v_state.claimed)
  on conflict (intent_id) do update
    set last_checked_at = excluded.last_checked_at,
        checks = public.payment_reconciliation_checks.checks + excluded.checks,
        seen_state = coalesce(excluded.seen_state, public.payment_reconciliation_checks.seen_state),
        seen_client = coalesce(excluded.seen_client, public.payment_reconciliation_checks.seen_client);
  -- #4136 -- those who read the finances are told once per attempt left
  -- unreadable; a later run names its latest reason; a read ends the notice.
  perform public.payment_attempt_notice(p_workspace_id, (u ->> 'intent')::uuid, u ->> 'reason')
     from jsonb_array_elements(v_unreadable) u;
  perform public.payment_attempt_notice_end(i.id, 'read')
     from public.payment_intents i
    where i.id = any (v_state.claimed) and i.workspace_id = p_workspace_id
      and i.id::text in (select e ->> 'intent'
                           from jsonb_array_elements(case when jsonb_typeof(v_result -> 'read_items') = 'array'
                                                          then v_result -> 'read_items' else '[]'::jsonb end) e)
      and not exists (select 1 from jsonb_array_elements(v_unreadable) u where u ->> 'intent' = i.id::text);
  delete from public.payment_reconciliation_checks c
   using public.payment_intents i
   where c.intent_id = i.id and c.workspace_id = p_workspace_id and i.status <> 'created';
  insert into public.payment_reconciliation_runs
    (workspace_id, started_at, read_count, settled_count, ended_count, left_count,
     abandoned_count, unreadable_count, unreadable, malformed)
  values (p_workspace_id,
          coalesce(v_state.last_attempt_at, now()),
          (v_counts ->> 'read')::integer, (v_counts ->> 'settled')::integer,
          (v_counts ->> 'ended')::integer, (v_counts ->> 'left')::integer,
          (v_counts ->> 'abandoned')::integer,
          jsonb_array_length(v_unreadable), v_unreadable, v_malformed);
  update public.payment_reconciliation_state
     set lease_token = null, lease_until = null, claimed = '{}',
         last_finish_at = now(),
         last_error = case when cardinality(v_malformed) > 0 then 'malformed counts' else null end
   where workspace_id = p_workspace_id;
  return true;
end;
$fn$;
revoke execute on function public.payment_reconciliation_finish_v1(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.payment_reconciliation_finish_v1(uuid, uuid, jsonb) to service_role;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(802);
