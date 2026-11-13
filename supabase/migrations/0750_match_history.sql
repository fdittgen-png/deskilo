-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0750 (#3838, L1 of #3787) -- a match history, so the customer statement
-- reads a past day as it stood.
--
-- Five functions change invoice_matches and invoice_match_payments in place
-- or delete them (match_invoice, respond_to_event, release_invoice_payment,
-- settle_credit_invoice, unmatch_bank_line_in_v1): a statement of a past
-- day read a match's approval as it stands now.
--
--   * invoice_match_history: append-only (no update, no delete while the
--     business exists), written by triggers on both tables -- every insert,
--     update and delete, with the row's image and the instant -- and on the
--     status of the events they point at (a payment's approval or
--     rejection). Each row names who acted (the member) and the function
--     called, when known. No direct read or write: the functions below read it.
--   * Backfill: each match and part at its creation, a confirmation at its
--     event's decision, a write-off at writeoff_at, the past unmatches from
--     bank_line_unmatches. Those rows are marked reconstructed; one row per
--     existing business records the instant the history starts.
--   * invoice_matches_at, invoice_match_payments_at and
--     invoice_match_event_status_at read the state at a cutoff;
--     customer_statement_v1 (0731, restated whole) reads them, and returns
--     history_from: before it, a statement is reconstructed from today's
--     records.

create table public.invoice_match_history (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  -- what the row is about: a match, a part, the event of either, or the
  -- start of the history of a business
  subject text not null check (subject in ('match', 'part', 'event', 'history')),
  subject_id uuid not null,
  invoice_id uuid,
  op text not null check (op in ('insert', 'update', 'delete', 'status', 'start')),
  image jsonb not null default '{}'::jsonb,
  at timestamptz not null default clock_timestamp(),
  actor_member_id uuid,
  actor_function text,
  reconstructed boolean not null default false
);
select public.ensure_system_columns('invoice_match_history');
create index invoice_match_history_subject on public.invoice_match_history (workspace_id, subject, subject_id, at desc, seq desc);
create index if not exists invoice_match_payments_event_idx on public.invoice_match_payments (event_id) where event_id is not null;
create index if not exists invoice_matches_event_idx on public.invoice_matches (event_id) where event_id is not null;

alter table public.invoice_match_history enable row level security;
revoke all on public.invoice_match_history from public, anon, authenticated;
create policy mcp_delegated_deny on public.invoice_match_history as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- An audit record of money: never edited; deleted only with its business.
create or replace function public.invoice_match_history_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'the match history is never edited or deleted' using errcode = '55000';
end;
$fn$;
revoke execute on function public.invoice_match_history_append_only() from public, anon, authenticated;
create trigger invoice_match_history_append_only before update or delete on public.invoice_match_history
  for each row execute function public.invoice_match_history_append_only();

-- Who acts: the member of the session, and the function the statement called.
create or replace function public.invoice_match_history_write(
  p_workspace_id uuid, p_subject text, p_subject_id uuid, p_invoice_id uuid, p_op text, p_image jsonb)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.invoice_match_history
    (workspace_id, subject, subject_id, invoice_id, op, image, actor_member_id, actor_function)
  values (p_workspace_id, p_subject, p_subject_id, p_invoice_id, p_op, coalesce(p_image, '{}'::jsonb),
          (select m.id from public.members m
            where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active'),
          substring(current_query() from 'public\.([a-z_0-9]+)\s*\('));
end;
$fn$;
revoke execute on function public.invoice_match_history_write(uuid, text, uuid, uuid, text, jsonb) from public, anon, authenticated;

-- A match or a part changed: its image. A new one also records its event's
-- status at that moment, which may already be decided.
create or replace function public.invoice_match_history_rows()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_subject text := case tg_table_name when 'invoice_matches' then 'match' else 'part' end;
  v_status text;
begin
  if tg_op = 'DELETE' then
    perform public.invoice_match_history_write(old.workspace_id, v_subject, old.id, old.invoice_id,
      'delete', to_jsonb(old));
    return null;
  end if;
  perform public.invoice_match_history_write(new.workspace_id, v_subject, new.id, new.invoice_id,
    lower(tg_op), to_jsonb(new));
  if tg_op = 'INSERT' and new.event_id is not null then
    select e.status into v_status from public.events e where e.id = new.event_id;
    if v_status is not null then
      perform public.invoice_match_history_write(new.workspace_id, 'event', new.event_id, new.invoice_id,
        'status', jsonb_build_object('status', v_status));
    end if;
  end if;
  return null;
end;
$fn$;
revoke execute on function public.invoice_match_history_rows() from public, anon, authenticated;
create trigger invoice_matches_history after insert or update or delete on public.invoice_matches
  for each row execute function public.invoice_match_history_rows();
create trigger invoice_match_payments_history after insert or update or delete on public.invoice_match_payments
  for each row execute function public.invoice_match_history_rows();

-- An event a match or a part points at was decided (or reopened).
create or replace function public.invoice_match_history_event()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_invoice uuid;
begin
  select coalesce(
           (select m.invoice_id from public.invoice_matches m where m.event_id = new.id limit 1),
           (select p.invoice_id from public.invoice_match_payments p where p.event_id = new.id limit 1))
    into v_invoice;
  if v_invoice is not null then
    perform public.invoice_match_history_write(new.workspace_id, 'event', new.id, v_invoice,
      'status', jsonb_build_object('status', new.status));
  end if;
  return null;
end;
$fn$;
revoke execute on function public.invoice_match_history_event() from public, anon, authenticated;
create trigger events_invoice_match_history after update of status on public.events
  for each row when (old.status is distinct from new.status)
  execute function public.invoice_match_history_event();

-- ── the backfill: what today's rows tell of their past ──────────────────
do $backfill$
declare
  r record;
  v_decided timestamptz;
  v_image jsonb;
begin
  insert into public.invoice_match_history (workspace_id, subject, subject_id, op, at, actor_function)
  select w.id, 'history', w.id, 'start', now(), '0750'
    from public.workspaces w;

  -- the events of today's matches and parts: pending when created, then
  -- their status at their decision
  for r in
    select distinct e.id, e.workspace_id, e.status, e.created_at,
           coalesce(m.invoice_id, p.invoice_id) as invoice_id,
           coalesce((select max(d.decided_at) from public.event_decisions d where d.event_id = e.id),
                    e.modified_datetime) as decided
      from public.events e
      left join public.invoice_matches m on m.event_id = e.id
      left join public.invoice_match_payments p on p.event_id = e.id
     where m.id is not null or p.id is not null
  loop
    insert into public.invoice_match_history
      (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
    values (r.workspace_id, 'event', r.id, r.invoice_id, 'status', '{"status": "pending"}', r.created_at, '0750', true);
    if r.status <> 'pending' then
      insert into public.invoice_match_history
        (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
      values (r.workspace_id, 'event', r.id, r.invoice_id, 'status', jsonb_build_object('status', r.status),
              greatest(r.decided, r.created_at), '0750', true);
    end if;
  end loop;

  -- today's matches: created pending (when an event decides them), then
  -- confirmed at their event's decision, then written off
  for r in
    select m.*, e.status as event_status, e.created_at as event_created,
           coalesce((select max(d.decided_at) from public.event_decisions d where d.event_id = e.id),
                    e.modified_datetime) as decided
      from public.invoice_matches m left join public.events e on e.id = m.event_id
  loop
    v_image := to_jsonb(r) - array['event_status', 'event_created', 'decided'];
    insert into public.invoice_match_history
      (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
    values (r.workspace_id, 'match', r.id, r.invoice_id, 'insert',
            v_image || jsonb_build_object('writeoff_at', null, 'writeoff_event_id', null)
                    || case when r.event_id is not null then '{"status": "pending"}'::jsonb else '{}'::jsonb end,
            r.created_datetime, '0750', true);
    v_decided := greatest(coalesce(r.decided, r.created_datetime), r.created_datetime);
    if r.event_id is not null and r.status <> 'pending' then
      insert into public.invoice_match_history
        (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
      values (r.workspace_id, 'match', r.id, r.invoice_id, 'update',
              v_image || jsonb_build_object('writeoff_at', null, 'writeoff_event_id', null),
              v_decided, '0750', true);
    end if;
    if r.writeoff_at is not null then
      insert into public.invoice_match_history
        (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
      values (r.workspace_id, 'match', r.id, r.invoice_id, 'update', v_image,
              greatest(r.writeoff_at, v_decided), '0750', true);
    end if;
  end loop;

  -- today's parts, at their creation
  insert into public.invoice_match_history
    (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
  select p.workspace_id, 'part', p.id, p.invoice_id, 'insert', to_jsonb(p), p.created_datetime, '0750', true
    from public.invoice_match_payments p;

  -- the bank matches undone before: matched, then undone
  for r in select u.*, gen_random_uuid() as match_key, gen_random_uuid() as part_key
             from public.bank_line_unmatches u where u.invoice_id is not null loop
    insert into public.invoice_match_history
      (workspace_id, subject, subject_id, invoice_id, op, image, at, actor_function, reconstructed)
    values
      (r.workspace_id, 'match', r.match_key, r.invoice_id, 'insert',
       jsonb_build_object('id', r.match_key, 'workspace_id', r.workspace_id, 'invoice_id', r.invoice_id,
         'paid_cents', r.amount_cents, 'resolution', r.resolution, 'status', 'confirmed',
         'payment_ledger_id', r.payment_ledger_id, 'matched_at', r.matched_at),
       r.matched_at, '0750', true),
      (r.workspace_id, 'part', r.part_key, r.invoice_id, 'insert',
       jsonb_build_object('id', r.part_key, 'workspace_id', r.workspace_id, 'invoice_id', r.invoice_id,
         'payment_ledger_id', r.payment_ledger_id, 'amount_cents', r.amount_cents,
         'resolution', r.resolution, 'matched_at', r.matched_at),
       r.matched_at, '0750', true),
      (r.workspace_id, 'match', r.match_key, r.invoice_id, 'delete', '{}', r.created_datetime, '0750', true),
      (r.workspace_id, 'part', r.part_key, r.invoice_id, 'delete', '{}', r.created_datetime, '0750', true);
  end loop;
end
$backfill$;

-- ── the state at a cutoff ───────────────────────────────────────────────
-- From when the history of a business is exact: before it, reconstructed
-- from the rows that existed then. A business created later is exact from
-- its creation.
create or replace function public.invoice_match_history_from(p_workspace_id uuid)
returns timestamptz language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select h.at from public.invoice_match_history h
      where h.workspace_id = p_workspace_id and h.subject = 'history' and h.op = 'start'),
    (select w.created_datetime from public.workspaces w where w.id = p_workspace_id));
$fn$;
revoke execute on function public.invoice_match_history_from(uuid) from public, anon, authenticated;

create or replace function public.invoice_matches_at(p_workspace_id uuid, p_cutoff timestamptz)
returns setof public.invoice_matches language sql stable security definer set search_path = public as $fn$
  select (jsonb_populate_record(null::public.invoice_matches, h.image)).*
    from (select distinct on (x.invoice_id) x.*
            from (select distinct on (s.subject_id) s.*
                    from public.invoice_match_history s
                   where s.workspace_id = p_workspace_id and s.subject = 'match' and s.at < p_cutoff
                   order by s.subject_id, s.at desc, s.seq desc) x
           where x.op <> 'delete'
           order by x.invoice_id, x.at desc, x.seq desc) h;
$fn$;
revoke execute on function public.invoice_matches_at(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.invoice_match_payments_at(p_workspace_id uuid, p_cutoff timestamptz)
returns setof public.invoice_match_payments language sql stable security definer set search_path = public as $fn$
  select (jsonb_populate_record(null::public.invoice_match_payments, h.image)).*
    from (select distinct on (s.subject_id) s.*
            from public.invoice_match_history s
           where s.workspace_id = p_workspace_id and s.subject = 'part' and s.at < p_cutoff
           order by s.subject_id, s.at desc, s.seq desc) h
   where h.op <> 'delete';
$fn$;
revoke execute on function public.invoice_match_payments_at(uuid, timestamptz) from public, anon, authenticated;

-- An event's status at a cutoff; null for no event. An event the history
-- has no row for before the cutoff had not been decided then.
create or replace function public.invoice_match_event_status_at(p_event_id uuid, p_cutoff timestamptz)
returns text language sql stable security definer set search_path = public as $fn$
  select case when p_event_id is null then null else coalesce(
    (select h.image ->> 'status' from public.invoice_match_history h
      where h.subject = 'event' and h.subject_id = p_event_id and h.at < p_cutoff
      order by h.at desc, h.seq desc limit 1),
    'pending') end;
$fn$;
revoke execute on function public.invoice_match_event_status_at(uuid, timestamptz) from public, anon, authenticated;

-- ── the statement reads the state at its cutoff ─────────────────────────
-- 0731, restated whole: the parts, their approval and the match are read as
-- they stood at the cutoff (which replaces 0731's filter on the rows'
-- creation); history_from says from when that is exact.
create or replace function public.customer_statement_v1(
  p_workspace_id uuid, p_member_id uuid, p_as_of date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_ws public.workspaces;
  v_cutoff timestamptz;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id;
  if v_member.id is null or not public.may_view_member_finances(p_member_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_as_of is null then
    raise exception 'a statement names its date' using errcode = '22023';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_cutoff := ((p_as_of + 1)::timestamp at time zone coalesce(nullif(v_ws.timezone, ''), 'UTC'));
  return (
    with docs as (
      select i.id, i.number, i.currency, i.issued_at, i.total_cents,
             (select mt.due_on from public.invoice_maturities mt where mt.invoice_id = i.id) as due_on,
             (i.voided_at is not null and i.voided_at < v_cutoff)
             or exists (select 1 from public.invoices s
                         where s.id = i.settled_by_invoice_id and s.issued_at < v_cutoff) as closed
        from public.invoices i
       where i.workspace_id = p_workspace_id and i.member_id = p_member_id
         and i.issued_at < v_cutoff and i.total_cents <> 0
    ),
    -- The parts allocated by the cutoff, and whether each awaits approval.
    parts as (
      select p.invoice_id, p.payment_ledger_id, p.amount_cents, p.matched_at,
             coalesce(public.invoice_match_event_status_at(p.event_id, v_cutoff) = 'pending', false) as waiting
        from public.invoice_match_payments_at(p_workspace_id, v_cutoff) p
    ),
    due as (
      select d.*,
             case
               when d.closed then 0
               when m.id is null then d.total_cents
               when m.status = 'pending' then d.total_cents
               when m.resolution = 'under_accepted'
                    and (m.writeoff_at is null or m.writeoff_at >= v_cutoff)
                 then d.total_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                                 where pt.invoice_id = d.id and not pt.waiting), 0)
               else 0
             end as still_due,
             case
               when d.total_cents < 0 then 'credit_note'
               when m.id is not null and m.status = 'pending'
                 then 'awaiting_approval'
               when m.id is not null then 'partly_paid'
               else 'open'
             end as state
        from docs d
        left join public.invoice_matches_at(p_workspace_id, v_cutoff) m on m.invoice_id = d.id
    ),
    credits as (
      select le.id, le.category, le.description, le.occurred_on, le.created_at,
             le.amount_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                          where pt.payment_ledger_id = le.id), 0) as left_cents
        from public.ledger_entries le
       where le.workspace_id = p_workspace_id and le.member_id = p_member_id
         and le.kind = 'credit' and le.category in ('payment', 'adjustment')
         and le.created_at < v_cutoff
         and not exists (select 1 from public.ledger_credit_moves cm
                          where (cm.from_credit_id = le.id or cm.reversal_ledger_id = le.id)
                            and cm.created_datetime < v_cutoff)
         and not exists (select 1 from public.invoices i
                          where i.workspace_id = p_workspace_id and i.member_id = p_member_id
                            and i.period = le.period and i.issued_at > le.created_at
                            and i.issued_at < v_cutoff
                            and (i.voided_at is null or i.voided_at >= v_cutoff))
    ),
    lines as (
      select d.currency, jsonb_build_object(
               'invoice_id', d.id, 'number', d.number, 'issued_at', d.issued_at,
               'due_on', d.due_on, 'total_cents', d.total_cents,
               'still_due_cents', d.still_due, 'state', d.state,
               'allocations', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'payment_id', pt.payment_ledger_id, 'on', pt.matched_at,
                          'amount_cents', pt.amount_cents, 'awaiting_approval', pt.waiting)
                          order by pt.matched_at, pt.payment_ledger_id)
                   from parts pt where pt.invoice_id = d.id), '[]'::jsonb)) as line,
             d.still_due, d.issued_at, d.number
        from due d where d.still_due <> 0
    ),
    open_credits as (
      select v_ws.currency_code as currency, jsonb_build_object(
               'ledger_id', c.id, 'category', c.category, 'description', c.description,
               'on', coalesce(c.occurred_on, c.created_at::date), 'left_cents', c.left_cents) as line,
             c.left_cents, c.created_at, c.id
        from credits c where c.left_cents > 0
    ),
    currencies as (
      select currency from lines union select currency from open_credits
    )
    select jsonb_build_object(
             'member_id', v_member.id,
             'as_of', p_as_of,
             'cutoff', v_cutoff,
             'history_from', public.invoice_match_history_from(p_workspace_id),
             'currencies', coalesce(jsonb_agg(jsonb_build_object(
               'currency', c.currency,
               'still_due_cents', coalesce((select sum(l.still_due) from lines l where l.currency = c.currency), 0),
               'unapplied_cents', coalesce((select sum(o.left_cents) from open_credits o where o.currency = c.currency), 0),
               'balance_cents', coalesce((select sum(l.still_due) from lines l where l.currency = c.currency), 0)
                                - coalesce((select sum(o.left_cents) from open_credits o where o.currency = c.currency), 0),
               'invoices', coalesce((select jsonb_agg(l.line order by l.issued_at, l.number)
                                       from lines l where l.currency = c.currency), '[]'::jsonb),
               'credits', coalesce((select jsonb_agg(o.line order by o.created_at, o.id)
                                      from open_credits o where o.currency = c.currency), '[]'::jsonb))
             order by c.currency), '[]'::jsonb))
      from currencies c
  );
end;
$fn$;
revoke execute on function public.customer_statement_v1(uuid, uuid, date) from public, anon;
grant execute on function public.customer_statement_v1(uuid, uuid, date) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(750);
