-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table for the e-mail sends of payment reminders; one more channel in
--  an existing check; four new functions)
--
-- #3673 (second pull request) -- a payment reminder leaves by e-mail, from
-- the business's own sender (0724), through the `send-reminder-email`
-- function. The fence is the purchase order's (0683), applied to a reminder:
--
--  * `begin_reminder_email_v1`, with the CALLER's token, decides who may
--    send: a native session (never an assistant), issueInvoices, the
--    `reminderEmail` feature, an invoice that still owes something and is
--    not on hold, the level the business's rules give now, the sender
--    configured, and the contact e-mail of the customer's profile. It
--    opens the attempt and the reminder's intent. The same attempt id
--    replays it, for the same issuer rights only, and its answer says
--    whether the attempt may still be sent: by the call that opened it, or
--    by a replay younger than the bound a person decides after. An older
--    pending attempt is never sent again: the provider's idempotency
--    window is not a promise to rely on.
--  * ONCE: an invoice has at most one e-mail per reminder level that may
--    have left (pending, unconfirmed, accepted, delivered) -- a unique
--    index, not a client promise. A refused attempt left nothing, so the
--    level can be e-mailed again once the cause is fixed.
--  * `finish_reminder_email` (service role) records the provider's answer.
--    Accepted: the reminder is recorded at the attempt's level, exactly as
--    a shared one (0334), with the e-mail as its evidence -- unless a
--    reminder at that level was recorded after the attempt opened (a share
--    or the sweep while the e-mail had no outcome): one level served is
--    one reminder, so the e-mail then adds its evidence and nothing else. Refused: the
--    attempt failed, and no reminder is counted. Unconfirmed: nothing is
--    counted and the level stays fenced until a person decides it with
--    `resolve_reminder_email_v1`.
--  * The evidence sits beside the other reminder evidence: a
--    `reminder_attempts` row on channel 'email' says when, to which
--    address, with which provider id and with which outcome.
--
-- The server writes no words: the app composes the letter and the e-mail
-- in the customer's document language and sends the language with the
-- attempt, which records it.

create table public.reminder_email_sends (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  intent_id uuid not null references public.reminder_intents(id) on delete cascade,
  level int not null check (level between 1 and 9),
  state text not null default 'pending'
    check (state in ('pending', 'accepted', 'refused', 'unconfirmed', 'delivered', 'not_delivered')),
  recipient text not null check (char_length(recipient) <= 254),
  language text not null check (language in ('en', 'fr', 'de', 'es', 'it')),
  -- How many reminders this level already counted when the attempt opened
  -- (the last level repeats once the ladder is climbed).
  served_before int not null default 0 check (served_before >= 0),
  provider_id text not null default '' check (char_length(provider_id) <= 200),
  reason text not null default '' check (char_length(reason) <= 300),
  actor_member_id uuid not null,
  finished_at timestamptz,
  resolved_by_member_id uuid,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('reminder_email_sends');

comment on table public.reminder_email_sends is
  '#3673 -- the e-mail sends of payment reminders: one row per attempt, its recipient, language, provider answer and who decided an unconfirmed one.';

-- Once per invoice and level: at most one e-mail that may have left.
create unique index reminder_email_sends_once_per_level
  on public.reminder_email_sends (invoice_id, level)
  where state in ('pending', 'unconfirmed', 'accepted', 'delivered');
create index reminder_email_sends_invoice on public.reminder_email_sends (invoice_id);

alter table public.reminder_email_sends enable row level security;
revoke all on public.reminder_email_sends from public, anon, authenticated;
grant select on public.reminder_email_sends to authenticated;
create policy reminder_email_sends_select on public.reminder_email_sends for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices'])));
create policy mcp_delegated_deny on public.reminder_email_sends as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The e-mail is one more channel of the reminder evidence.
alter table public.reminder_attempts drop constraint reminder_attempts_channel_check;
alter table public.reminder_attempts add constraint reminder_attempts_channel_check
  check (channel in ('push', 'share', 'email'));

create or replace function public.reminder_email_send_json(p_send uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', s.id, 'invoice_id', s.invoice_id, 'level', s.level,
    'state', s.state, 'recipient', s.recipient, 'language', s.language,
    'provider_id', s.provider_id, 'reason', s.reason,
    'created_at', s.created_datetime, 'finished_at', s.finished_at)
    from public.reminder_email_sends s where s.id = p_send;
$fn$;
revoke execute on function public.reminder_email_send_json(uuid) from public, anon, authenticated;

-- The customer's address on file: the contact e-mail of the profile of the
-- member the invoice is addressed to (editable by its owner; not the
-- account's sign-in address). A member without a profile has none.
create or replace function public.invoice_customer_email(p_invoice_id uuid)
returns text language sql stable security definer set search_path = public as $fn$
  select nullif(btrim(p.email), '')
    from public.invoices i
    join public.members m on m.id = i.member_id
    join public.profiles p on p.id = m.user_id
   where i.id = p_invoice_id
     and p.email ~ '^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$'
     and p.email !~ '[\r\n]';
$fn$;
revoke execute on function public.invoice_customer_email(uuid) from public, anon, authenticated;

-- What the app needs to offer the channel for one invoice, before the
-- letter is built: whether e-mail is possible, to whom, and why not.
create or replace function public.reminder_email_target_v1(p_workspace_id uuid, p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_recipient text;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_invoice from public.invoices
   where id = p_invoice_id and workspace_id = p_workspace_id;
  if v_invoice.id is null then raise exception 'unknown invoice' using errcode = '22023'; end if;
  v_recipient := public.invoice_customer_email(p_invoice_id);
  return jsonb_build_object(
    'available', public.feature_effective(p_workspace_id, 'reminderEmail')
                 and v_recipient is not null
                 and exists (select 1 from public.purchase_order_mail_settings m
                              where m.workspace_id = p_workspace_id and m.has_api_key),
    'recipient', coalesce(v_recipient, ''),
    'reason', case
      when not public.feature_effective(p_workspace_id, 'reminderEmail') then 'feature_off'
      when v_recipient is null then 'no_address'
      when not exists (select 1 from public.purchase_order_mail_settings m
                        where m.workspace_id = p_workspace_id and m.has_api_key) then 'sender_not_configured'
      else '' end);
end;
$fn$;
revoke execute on function public.reminder_email_target_v1(uuid, uuid) from public, anon;
grant execute on function public.reminder_email_target_v1(uuid, uuid) to authenticated;

create or replace function public.begin_reminder_email_v1(
  p_workspace_id uuid, p_invoice_id uuid, p_level int, p_language text, p_attempt_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_invoice public.invoices;
  v_send public.reminder_email_sends;
  v_state jsonb;
  v_level int;
  v_recipient text;
  v_intent_id uuid;
  -- A technical bound, not a business value: far beyond any live attempt;
  -- resolve_reminder_email_v1 decides by hand after the same bound.
  c_stuck constant interval := interval '10 minutes';
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  begin
    v_actor := public.issuing_member(p_workspace_id);
  exception when others then
    raise exception 'not allowed' using errcode = '42501';
  end;
  if p_attempt_id is null then raise exception 'an attempt id is required' using errcode = '22023'; end if;
  select * into v_send from public.reminder_email_sends where id = p_attempt_id;
  if v_send.id is not null then
    if v_send.workspace_id <> p_workspace_id or v_send.invoice_id <> p_invoice_id then
      raise exception 'this attempt id was already used for another invoice' using errcode = '22023';
    end if;
    -- A replay: sendable only while it is pending and younger than the
    -- bound after which a person decides it.
    return public.reminder_email_send_json(v_send.id) || jsonb_build_object(
      'opened', false,
      'sendable', v_send.state = 'pending' and v_send.created_datetime >= now() - c_stuck);
  end if;
  if not public.feature_effective(p_workspace_id, 'reminderEmail') then
    raise exception 'reminders by e-mail are off in this space' using errcode = '42501';
  end if;
  if coalesce(p_language, '') not in ('en', 'fr', 'de', 'es', 'it') then
    raise exception 'the letter names no language' using errcode = '22023';
  end if;
  select * into v_invoice from public.invoices
   where id = p_invoice_id and workspace_id = p_workspace_id for update;
  if v_invoice.id is null then raise exception 'unknown invoice' using errcode = '22023'; end if;
  if v_invoice.voided_at is not null then raise exception 'invoice is voided' using errcode = '22023'; end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled' using errcode = '22023';
  end if;
  -- The state is read after the row lock, as the shared reminder does (#926).
  v_state := public.invoice_dunning_state_core(p_invoice_id, now());
  if (v_state ->> 'collectible_cents')::int = 0 then
    raise exception 'nothing is outstanding on this invoice' using errcode = '22023';
  end if;
  if v_state ->> 'hold' in ('dispute', 'identity_error', 'insolvency', 'other', 'mixed_currency') then
    raise exception 'this invoice is on hold: %', v_state ->> 'hold' using errcode = '22023';
  end if;
  v_level := least((v_state ->> 'reminders_sent')::int + 1, (v_state ->> 'levels')::int);
  if v_level <> coalesce(p_level, -1) then
    raise exception 'the reminder level changed' using errcode = '40001';
  end if;
  v_recipient := public.invoice_customer_email(p_invoice_id);
  if v_recipient is null then
    raise exception 'the customer has no e-mail address on file' using errcode = '22023';
  end if;
  if not exists (select 1 from public.purchase_order_mail_settings m
                  where m.workspace_id = p_workspace_id and m.has_api_key) then
    raise exception 'this business has not configured how it sends e-mail' using errcode = '22023';
  end if;
  if exists (select 1 from public.reminder_email_sends s
              where s.invoice_id = p_invoice_id and s.state in ('pending', 'unconfirmed')) then
    raise exception 'an earlier e-mail of this reminder has no confirmed outcome: check before sending again'
      using errcode = '55000';
  end if;
  if exists (select 1 from public.reminder_email_sends s
              where s.invoice_id = p_invoice_id and s.level = v_level
                and s.state in ('accepted', 'delivered')) then
    raise exception 'this reminder level was already e-mailed' using errcode = '55000';
  end if;
  insert into public.reminder_intents
    (workspace_id, invoice_id, level, origin, status, collectible_cents, currency)
  values (p_workspace_id, p_invoice_id, v_level, 'manual', 'prepared',
          (v_state ->> 'collectible_cents')::int, v_invoice.currency)
  returning id into v_intent_id;
  insert into public.reminder_email_sends
    (id, workspace_id, invoice_id, intent_id, level, recipient, language, served_before, actor_member_id)
  values (p_attempt_id, p_workspace_id, p_invoice_id, v_intent_id, v_level, v_recipient, p_language,
          (select count(*) from public.invoice_reminders r
            where r.invoice_id = p_invoice_id and r.level = v_level),
          v_actor.id)
  returning * into v_send;
  return public.reminder_email_send_json(v_send.id)
    || jsonb_build_object('opened', true, 'sendable', true);
end;
$fn$;
revoke execute on function public.begin_reminder_email_v1(uuid, uuid, int, text, uuid) from public, anon;
grant execute on function public.begin_reminder_email_v1(uuid, uuid, int, text, uuid) to authenticated;

-- A reminder e-mail that left is recorded as a reminder at its level, with
-- the same event and member push as a shared one (0334).
create or replace function public.reminder_email_record(p_send uuid, p_evidence text)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_send public.reminder_email_sends;
  v_invoice public.invoices;
  v_actor_name text;
  v_state jsonb;
  v_reminder_id uuid;
  v_event_id uuid;
begin
  select * into v_send from public.reminder_email_sends where id = p_send;
  select * into v_invoice from public.invoices where id = v_send.invoice_id;
  select coalesce(p.display_name, '') into v_actor_name
    from public.members m join public.profiles p on p.id = m.user_id
   where m.id = v_send.actor_member_id;
  -- One level served is one reminder: a share or the sweep that recorded
  -- this level after the attempt opened already counted it. The e-mail's
  -- own evidence row stays; no second reminder, event or push. (The
  -- intent's reminder_id stays empty: a reminder has one intent.)
  if (select count(*) from public.invoice_reminders r
       where r.invoice_id = v_send.invoice_id and r.level = v_send.level) > v_send.served_before then
    update public.reminder_intents set status = p_evidence where id = v_send.intent_id;
    return;
  end if;
  v_state := public.invoice_dunning_state_core(v_send.invoice_id, now());
  insert into public.invoice_reminders (workspace_id, invoice_id, by_name, automatic, level)
  values (v_send.workspace_id, v_send.invoice_id, coalesce(v_actor_name, ''), false, v_send.level)
  returning id into v_reminder_id;
  update public.reminder_intents set reminder_id = v_reminder_id, status = p_evidence
   where id = v_send.intent_id;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values
    (v_send.workspace_id, 'invoice_reminder', 'created', v_send.actor_member_id,
     v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'level', v_send.level,
       'levels', (v_state ->> 'levels')::int,
       'amount_cents', (v_state ->> 'collectible_cents')::int,
       'currency', v_invoice.currency,
       'issued_at', v_invoice.issued_at,
       'due_on', v_state -> 'due_on',
       'phase', v_state ->> 'phase',
       'days_overdue', v_state -> 'days_overdue',
       'intent_id', v_send.intent_id,
       'channel', 'email',
       'automatic', false),
     'applied')
  returning id into v_event_id;
  perform public.reminder_queue_push(v_send.intent_id, v_event_id);
  -- The e-mail's evidence is the stronger statement; a push outcome does
  -- not overwrite it.
  update public.reminder_intents set status = p_evidence where id = v_send.intent_id;
end;
$fn$;
revoke execute on function public.reminder_email_record(uuid, text) from public, anon, authenticated;

-- The provider's answer, recorded by the send function (service role).
create or replace function public.finish_reminder_email(
  p_attempt_id uuid, p_outcome text, p_provider_id text, p_reason text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_send public.reminder_email_sends;
  v_detail text;
begin
  if p_outcome not in ('accepted', 'refused', 'unconfirmed') then
    raise exception 'unknown outcome %', p_outcome using errcode = '22023';
  end if;
  select * into v_send from public.reminder_email_sends where id = p_attempt_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  -- The invoice row next, as the share and the sweep lock it: what this
  -- level already counts is read under the same lock (#926).
  perform 1 from public.invoices where id = v_send.invoice_id for update;
  -- An outcome is recorded once; a repeat of the same answer is a replay.
  if v_send.state <> 'pending' then
    if v_send.state = p_outcome then return public.reminder_email_send_json(v_send.id); end if;
    raise exception 'this attempt already has its outcome' using errcode = '55000';
  end if;
  update public.reminder_email_sends
     set state = p_outcome, provider_id = left(coalesce(p_provider_id, ''), 200),
         reason = left(coalesce(p_reason, ''), 300), finished_at = now()
   where id = v_send.id
  returning * into v_send;
  v_detail := left('e-mail to ' || v_send.recipient
    || case when v_send.provider_id <> '' then '; provider id ' || v_send.provider_id else '' end
    || case when v_send.reason <> '' then '; ' || v_send.reason else '' end, 300);
  insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
  values (v_send.workspace_id, v_send.intent_id, 'email',
          case p_outcome when 'accepted' then 'provider_accepted'
                         when 'refused' then 'failed' else 'unknown' end,
          v_detail);
  if p_outcome = 'accepted' then
    perform public.reminder_email_record(v_send.id, 'provider_accepted');
  else
    update public.reminder_intents
       set status = case p_outcome when 'refused' then 'failed' else 'unknown' end
     where id = v_send.intent_id;
  end if;
  return public.reminder_email_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.finish_reminder_email(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_reminder_email(uuid, text, text, text) to service_role;

-- A person decides an e-mail nobody could confirm.
create or replace function public.resolve_reminder_email_v1(
  p_workspace_id uuid, p_attempt_id uuid, p_delivered boolean
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  -- A technical bound, not a business value: far beyond any live attempt.
  c_stuck constant interval := interval '10 minutes';
  v_actor public.members;
  v_send public.reminder_email_sends;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  begin
    v_actor := public.issuing_member(p_workspace_id);
  exception when others then
    raise exception 'not allowed' using errcode = '42501';
  end;
  select * into v_send from public.reminder_email_sends
   where id = p_attempt_id and workspace_id = p_workspace_id for update;
  if v_send.id is null then raise exception 'unknown send attempt' using errcode = '22023'; end if;
  perform 1 from public.invoices where id = v_send.invoice_id for update;
  -- An attempt left pending past the bound (a crash leaves no finish) is
  -- decided the same way.
  if not (v_send.state = 'unconfirmed'
          or (v_send.state = 'pending' and v_send.created_datetime < now() - c_stuck)) then
    raise exception 'only an unconfirmed e-mail is decided by hand' using errcode = '22023';
  end if;
  update public.reminder_email_sends
     set state = case when p_delivered then 'delivered' else 'not_delivered' end,
         resolved_by_member_id = v_actor.id,
         finished_at = coalesce(finished_at, now())
   where id = v_send.id;
  insert into public.reminder_attempts (workspace_id, intent_id, channel, outcome, detail)
  values (v_send.workspace_id, v_send.intent_id, 'email',
          case when p_delivered then 'declared_delivered' else 'failed' end,
          left(case when p_delivered
                    then 'a person confirmed the e-mail to ' || v_send.recipient || ' arrived; not a receipt'
                    else 'a person said the e-mail to ' || v_send.recipient || ' did not arrive' end, 300));
  if p_delivered then
    perform public.reminder_email_record(v_send.id, 'declared_delivered');
  else
    update public.reminder_intents set status = 'failed' where id = v_send.intent_id;
  end if;
  return public.reminder_email_send_json(v_send.id);
end;
$fn$;
revoke execute on function public.resolve_reminder_email_v1(uuid, uuid, boolean) from public, anon;
grant execute on function public.resolve_reminder_email_v1(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(726);
