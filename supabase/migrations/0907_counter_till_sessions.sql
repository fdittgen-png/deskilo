-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (four tables, two columns, four settings, functions; the export function is restated whole)
--
-- #4367 (CS5, third file) -- the cash drawer across a day: a till is opened with its float, counted at the close, and the
-- day is closed with its report (the day close is 0909).
--
--   * `counter_tills`: the tills of a business (a name, an optional site). `counter_till_sessions`: one OPEN session per
--     till (a unique index: two opens at once give one), opened by a person who works the counter with the counted float
--     (a total, or by denomination when `counter.count_by_denomination` is on), closed with the counted amount, the
--     difference from the expected and its reason, an amount taken to the bank, and the card authorizations still unresolved
--     (listed, never counted as cash). A closed session is frozen; a correction goes to the next session as a counter-entry.
--   * `counter_cash_entries`: paid-in and paid-out entries of an open session, each with a reason from the business's list
--     (`counter.cash_reasons`); a paid-out above `counter.paid_out_limit_minor` needs the right to record outgoing payments;
--     a paid-out may name the purchase document it paid.
--   * The expected cash is DERIVED, never typed: the float, plus the cash tenders of the sales of the session, less its cash
--     refunds, plus paid-in, less paid-out. While a session is open and `counter.blind_count` is on, only someone who may see
--     the finances reads it; the counter counts first and sees the difference after.
--     The blind count is a counting discipline, not a secret: the server hides the DERIVED figure and refuses its read, and the
--     difference is shown when a count is submitted (that is what counting is for); the facts the counter itself recorded (the
--     float it counted, its entries, the sales it made) stay readable to it, so it is not an access barrier against a counter who
--     adds them up. What the server guarantees is that the expected cash is never typed, never taken from the client, and read
--     by the finances right alone while the session is open.
--   * Boundaries: a sale takes a share lock on its session and a close takes it for update, so a sale finalized at the moment
--     of the close lands in that session only if its transaction committed first (0908); a closed session refuses the sale.
--   * Rights are the ones the till already has (no new permission): working the counter is issueInvoices on a business with the
--     counter feature on; tills are managed with manageSites; the paid-out limit is lifted by recordOutgoingPayments; the
--     differences of every till are seen with viewFinances.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.blind_count', 'bool', 'true'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till sessions (#4367)', 'Whether a till is counted blind: while its session is open the counter does not see the expected cash, counts the drawer, and sees the difference after the close. Someone who may see the finances always sees the expected cash.'),
('counter.count_by_denomination', 'bool', 'false'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till sessions (#4367)', 'Whether the float and the counted drawer are given by denomination (how many of each note and coin) rather than as a total. By denomination, the counts must add up to the amount.'),
('counter.paid_out_limit_minor', 'int', '0'::jsonb, 0, 100000000, 'currency units', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till sessions (#4367)', 'The largest amount, in minor units of the business currency (cents), that a paid-out from the drawer may be without someone who may record outgoing payments. 0 means no limit.'),
('counter.cash_reasons', 'text', '"change,expense,other"'::jsonb, null, 200, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till sessions (#4367)', 'The reasons a person may give for money paid into or out of the drawer, separated by commas (for example change, expense, other).')
on conflict (key) do nothing;
-- END GENERATED SEED

create table public.counter_tills (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  site_id uuid references public.sites (id),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  active boolean not null default true,
  unique (workspace_id, name),
  unique (workspace_id, id)
);
select public.ensure_system_columns('counter_tills');

create table public.counter_till_sessions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  till_id uuid not null,
  state text not null default 'open' check (state in ('open', 'closed')),
  opened_by_member_id uuid,
  opened_at timestamptz not null default now(),
  float_minor bigint not null check (float_minor >= 0),
  float_denominations jsonb,
  closed_by_member_id uuid,
  closed_at timestamptz,
  counted_minor bigint check (counted_minor is null or counted_minor >= 0),
  counted_denominations jsonb,
  expected_minor bigint,
  difference_minor bigint,
  difference_reason text check (difference_reason is null or char_length(difference_reason) <= 200),
  banked_minor bigint check (banked_minor is null or banked_minor >= 0),
  unresolved_card_minor bigint check (unresolved_card_minor is null or unresolved_card_minor >= 0),
  day_close_id uuid,
  check ((state = 'closed') = (closed_at is not null and counted_minor is not null and expected_minor is not null and difference_minor is not null)),
  unique (workspace_id, id),
  foreign key (workspace_id, till_id) references public.counter_tills (workspace_id, id),
  foreign key (workspace_id, opened_by_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, closed_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_till_sessions');
create unique index counter_till_sessions_one_open on public.counter_till_sessions (till_id) where state = 'open';
create index counter_till_sessions_day on public.counter_till_sessions (workspace_id, closed_at) where state = 'closed';

create table public.counter_cash_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  session_id uuid not null,
  kind text not null check (kind in ('paid_in', 'paid_out')),
  amount_minor bigint not null check (amount_minor > 0),
  reason text not null check (char_length(btrim(reason)) between 1 and 60),
  purchase_document_id uuid references public.purchase_documents (id),
  recorded_by_member_id uuid,
  approved_by_member_id uuid,
  request_id uuid not null,
  check (purchase_document_id is null or kind = 'paid_out'),
  unique (workspace_id, id),
  foreign key (workspace_id, session_id) references public.counter_till_sessions (workspace_id, id),
  foreign key (workspace_id, recorded_by_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, approved_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_cash_entries');
create index counter_cash_entries_session on public.counter_cash_entries (session_id);

create table public.counter_day_closes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  site_key text not null default '',
  business_date date not null,
  number text not null,
  report jsonb not null,
  closed_by_member_id uuid,
  unique (workspace_id, site_key, business_date),
  unique (workspace_id, number),
  unique (workspace_id, id),
  foreign key (workspace_id, closed_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_day_closes');
alter table public.counter_till_sessions add constraint counter_till_sessions_day_fkey
  foreign key (workspace_id, day_close_id) references public.counter_day_closes (workspace_id, id);

-- the session a sale or a cash refund belongs to
-- audience: all row readers
alter table public.counter_receipts add column till_session_id uuid;
alter table public.counter_receipts add constraint counter_receipts_session_fkey
  foreign key (workspace_id, till_session_id) references public.counter_till_sessions (workspace_id, id);
create index counter_receipts_session on public.counter_receipts (till_session_id) where till_session_id is not null;
-- audience: all row readers
alter table public.counter_refunds add column till_session_id uuid;
alter table public.counter_refunds add constraint counter_refunds_session_fkey
  foreign key (workspace_id, till_session_id) references public.counter_till_sessions (workspace_id, id);

-- a closed session, a cash entry and a day close are never edited or deleted (the cascade of a business's own deletion passes)
create or replace function public.counter_till_frozen_guard()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_state text;
begin
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  if tg_table_name = 'counter_till_sessions' then
    if tg_op = 'DELETE' or old.state = 'closed' then
      -- the day close stamps a closed session once: nothing else changes
      if tg_op = 'UPDATE' and old.state = 'closed' and old.day_close_id is null and new.day_close_id is not null
         and (to_jsonb(new) - public.system_column_names() - 'day_close_id') = (to_jsonb(old) - public.system_column_names() - 'day_close_id') then
        return new;
      end if;
      raise exception 'a till session is never edited or deleted once opened' using errcode = 'DKL03';
    end if;
    return new;
  elsif tg_table_name = 'counter_cash_entries' then
    if tg_op = 'DELETE' then
      raise exception 'a cash entry is never deleted' using errcode = 'DKL03';
    end if;
    raise exception 'a cash entry is never edited' using errcode = 'DKL03';
  else
    raise exception 'a day close is never edited or deleted' using errcode = 'DKL03';
  end if;
end;
$fn$;
revoke execute on function public.counter_till_frozen_guard() from public, anon, authenticated;
create trigger counter_till_sessions_frozen before update or delete on public.counter_till_sessions
  for each row execute function public.counter_till_frozen_guard();
create trigger counter_cash_entries_frozen before update or delete on public.counter_cash_entries
  for each row execute function public.counter_till_frozen_guard();
create trigger counter_day_closes_frozen before update or delete on public.counter_day_closes
  for each row execute function public.counter_till_frozen_guard();

alter table public.counter_tills enable row level security;
alter table public.counter_till_sessions enable row level security;
alter table public.counter_cash_entries enable row level security;
alter table public.counter_day_closes enable row level security;
revoke all on public.counter_tills, public.counter_till_sessions, public.counter_cash_entries, public.counter_day_closes from public, anon, authenticated;
grant select on public.counter_tills, public.counter_till_sessions, public.counter_cash_entries, public.counter_day_closes to authenticated;
create policy counter_tills_select on public.counter_tills for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterTillSessions'));
-- a session carries what the count is compared with (expected cash, difference, banked): the finances read every session; the counter
-- reads only its own open session, which holds none of that yet, and the entries of it
create policy counter_till_sessions_select on public.counter_till_sessions for select to authenticated
  using (public.feature_effective(workspace_id, 'counterTillSessions')
         and (workspace_id in (select public.workspaces_permitting(array['viewFinances']))
              or (workspace_id in (select public.workspaces_permitting(array['issueInvoices']))
                  and state = 'open'
                  and opened_by_member_id in (select m.id from public.members m
                                               where m.workspace_id = counter_till_sessions.workspace_id and m.user_id = auth.uid() and m.status = 'active'))));
create policy counter_cash_entries_select on public.counter_cash_entries for select to authenticated
  using (public.feature_effective(workspace_id, 'counterTillSessions')
         and (workspace_id in (select public.workspaces_permitting(array['viewFinances']))
              or (workspace_id in (select public.workspaces_permitting(array['issueInvoices']))
                  and session_id in (select s.id from public.counter_till_sessions s))));
create policy counter_day_closes_select on public.counter_day_closes for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances']))
         and public.feature_effective(workspace_id, 'counterTillSessions'));
create policy mcp_delegated_deny on public.counter_tills as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.counter_till_sessions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.counter_cash_entries as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.counter_day_closes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- the member who works the till: the counter's actor, with the sessions feature on
create or replace function public.counter_till_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  v_me := public.counter_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'counterTillSessions') then
    raise exception 'till sessions are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.counter_till_actor(uuid) from public, anon, authenticated;

-- the member who sees the finances (the day close, another person's session): not the counter's actor, who needs issueInvoices first
create or replace function public.counter_finance_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the finances of the counter' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'not allowed to see the finances of the counter' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'counterTillSessions') then
    raise exception 'till sessions are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.counter_finance_actor(uuid) from public, anon, authenticated;

-- whoever works the counter, or else whoever sees the finances
create or replace function public.counter_till_or_finance_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
begin
  if public.has_permission(p_workspace_id, 'issueInvoices') then
    return public.counter_till_actor(p_workspace_id);
  end if;
  return public.counter_finance_actor(p_workspace_id);
end;
$fn$;
revoke execute on function public.counter_till_or_finance_actor(uuid) from public, anon, authenticated;

-- a counted amount by denomination: {"5000": 2, "100": 7}: minor units of each note or coin, and how many; adds to the total
create or replace function public.counter_denominations_total(p_denominations jsonb)
returns bigint language plpgsql immutable set search_path = public as $fn$
declare
  e record;
  v_total bigint := 0;
begin
  if coalesce(jsonb_typeof(p_denominations), '') <> 'object' then
    return null;
  end if;
  for e in select key, value from jsonb_each(p_denominations) loop
    if e.key !~ '^[1-9][0-9]{0,8}$' or jsonb_typeof(e.value) <> 'number' or (e.value #>> '{}') !~ '^[0-9]{1,6}$' then
      return null;
    end if;
    v_total := v_total + e.key::bigint * (e.value #>> '{}')::bigint;
  end loop;
  return v_total;
end;
$fn$;
revoke execute on function public.counter_denominations_total(jsonb) from public, anon, authenticated;

-- the cash a session should hold now, derived from what happened in it
create or replace function public.counter_session_cash(p_session_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'float_minor', s.float_minor,
    'cash_sales_minor', coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                                   where r.till_session_id = s.id and r.state = 'finalized' and r.kind = 'sale' and t.kind = 'cash' and t.state = 'accepted'), 0),
    'cash_refunds_minor', coalesce((select sum(f.amount_minor) from public.counter_refunds f where f.till_session_id = s.id and f.kind = 'cash'), 0),
    'paid_in_minor', coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_in'), 0),
    'paid_out_minor', coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_out'), 0),
    'unresolved_card_minor', coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                                        where r.till_session_id = s.id and t.kind = 'card' and t.state in ('requested', 'unknown')), 0))
         || jsonb_build_object('expected_minor',
              s.float_minor
              + coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                           where r.till_session_id = s.id and r.state = 'finalized' and r.kind = 'sale' and t.kind = 'cash' and t.state = 'accepted'), 0)
              - coalesce((select sum(f.amount_minor) from public.counter_refunds f where f.till_session_id = s.id and f.kind = 'cash'), 0)
              + coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_in'), 0)
              - coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_out'), 0))
    from public.counter_till_sessions s where s.id = p_session_id
$fn$;
revoke execute on function public.counter_session_cash(uuid) from public, anon, authenticated;

-- ── a till of the business ─────────────────────────────────────────────
create or replace function public.counter_till_save_v1(p_workspace_id uuid, p_request_id uuid, p_till_id uuid, p_name text, p_site_id uuid, p_active boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_till public.counter_tills;
  v_result jsonb;
begin
  v_me := public.counter_till_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageSites') then
    raise exception 'not allowed to manage the tills' using errcode = 'DKN01';
  end if;
  if p_request_id is null or char_length(btrim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'a till has a name' using errcode = '22023';
  end if;
  if p_site_id is not null and not exists (select 1 from public.sites s where s.id = p_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'not a site of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'site_unknown')::text;
  end if;
  v_digest := md5(coalesce(p_till_id::text, '') || '|' || btrim(p_name) || '|' || coalesce(p_site_id::text, '') || '|' || coalesce(p_active, true)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_till_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  begin
  if p_till_id is null then
    insert into public.counter_tills (workspace_id, site_id, name, active) values (p_workspace_id, p_site_id, btrim(p_name), coalesce(p_active, true)) returning * into v_till;
  else
    update public.counter_tills set name = btrim(p_name), site_id = p_site_id, active = coalesce(p_active, true)
     where id = p_till_id and workspace_id = p_workspace_id returning * into v_till;
    if v_till.id is null then
      raise exception 'not a till of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'till_unknown')::text;
    end if;
    if not v_till.active and exists (select 1 from public.counter_till_sessions s where s.till_id = v_till.id and s.state = 'open') then
      raise exception 'a till with an open session is closed before it is switched off' using errcode = 'DKL12',
        detail = jsonb_build_object('reason', 'already_open', 'till_id', v_till.id)::text;
    end if;
  end if;
  exception when unique_violation then
    raise exception 'a till of this business already has this name' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'name_taken')::text;
  end;
  v_result := jsonb_build_object('till_id', v_till.id, 'name', v_till.name, 'active', v_till.active, 'site_id', v_till.site_id, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_till_save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_till_save_v1(uuid, uuid, uuid, text, uuid, boolean) from public, anon;
grant execute on function public.counter_till_save_v1(uuid, uuid, uuid, text, uuid, boolean) to authenticated;

-- ── open a session with its float ──────────────────────────────────────
create or replace function public.counter_session_open_v1(p_workspace_id uuid, p_request_id uuid, p_till_id uuid, p_float_minor bigint, p_denominations jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_till public.counter_tills;
  v_by_denomination boolean;
  v_session public.counter_till_sessions;
  v_result jsonb;
begin
  v_me := public.counter_till_actor(p_workspace_id);
  if p_request_id is null or p_till_id is null or p_float_minor is null or p_float_minor < 0 then
    raise exception 'a session is opened with a request id, a till and its float' using errcode = '22023';
  end if;
  v_by_denomination := coalesce((public.setting_value(p_workspace_id, 'counter.count_by_denomination') #>> '{}')::boolean, false);
  if v_by_denomination and public.counter_denominations_total(p_denominations) is distinct from p_float_minor then
    raise exception 'the float is counted by denomination and adds up' using errcode = 'DKL13', detail = jsonb_build_object('reason', 'denominations')::text;
  end if;
  v_digest := md5(p_till_id::text || '|' || p_float_minor::text || '|' || coalesce(p_denominations::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_session_open', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_till from public.counter_tills t where t.id = p_till_id and t.workspace_id = p_workspace_id for update;
  if v_till.id is null or not v_till.active then
    raise exception 'not an active till of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'till_unknown')::text;
  end if;
  -- a day closed for the site (or for the business as a whole) takes no session: it could never be part of that close
  if exists (select 1 from public.counter_day_closes c where c.workspace_id = p_workspace_id and c.business_date = public.workspace_today(p_workspace_id)
                and c.site_key in ('', coalesce(v_till.site_id::text, ''))) then
    raise exception 'the day of this till is already closed' using errcode = 'DKL15', detail = jsonb_build_object('reason', 'day_closed', 'till_id', v_till.id)::text;
  end if;
  begin
    insert into public.counter_till_sessions (workspace_id, till_id, opened_by_member_id, float_minor, float_denominations)
    values (p_workspace_id, v_till.id, v_me, p_float_minor, case when v_by_denomination then p_denominations end)
    returning * into v_session;
  exception when unique_violation then
    raise exception 'this till is already open' using errcode = 'DKL12',
      detail = jsonb_build_object('reason', 'already_open', 'till_id', v_till.id,
                                  'session_id', (select s.id from public.counter_till_sessions s where s.till_id = v_till.id and s.state = 'open'))::text;
  end;
  v_result := jsonb_build_object('session_id', v_session.id, 'till_id', v_till.id, 'float_minor', p_float_minor::text, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_session_open', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_session_open_v1(uuid, uuid, uuid, bigint, jsonb) from public, anon;
grant execute on function public.counter_session_open_v1(uuid, uuid, uuid, bigint, jsonb) to authenticated;

-- ── paid in, paid out ──────────────────────────────────────────────────
create or replace function public.counter_cash_entry_v1(
  p_workspace_id uuid, p_request_id uuid, p_session_id uuid, p_kind text, p_amount_minor bigint, p_reason text, p_purchase_document_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_session public.counter_till_sessions;
  v_reasons text[];
  v_limit bigint;
  v_approved uuid;
  v_entry public.counter_cash_entries;
  v_result jsonb;
begin
  v_me := public.counter_till_actor(p_workspace_id);
  if p_request_id is null or p_session_id is null or p_kind is null or p_kind not in ('paid_in', 'paid_out') or p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'an entry is recorded with a request id, a session, a kind and an amount' using errcode = '22023';
  end if;
  v_reasons := array(select btrim(x) from unnest(string_to_array(coalesce(public.setting_value(p_workspace_id, 'counter.cash_reasons') #>> '{}', 'change,expense,other'), ',')) x where btrim(x) <> '');
  if btrim(coalesce(p_reason, '')) = '' or not (btrim(p_reason) = any (v_reasons)) then
    raise exception 'this reason is not on the business''s list' using errcode = 'DKL13', detail = jsonb_build_object('reason', 'reason_unknown')::text;
  end if;
  if p_purchase_document_id is not null and (p_kind <> 'paid_out' or not exists (select 1 from public.purchase_documents d where d.id = p_purchase_document_id and d.workspace_id = p_workspace_id)) then
    raise exception 'a paid-out names a purchase document of this business' using errcode = 'DKL13', detail = jsonb_build_object('reason', 'purchase_unknown')::text;
  end if;
  v_digest := md5(p_session_id::text || '|' || p_kind || '|' || p_amount_minor::text || '|' || btrim(p_reason) || '|' || coalesce(p_purchase_document_id::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_cash_entry', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_session from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id for update;
  if v_session.id is null or v_session.state <> 'open' then
    raise exception 'this session is not open' using errcode = 'DKL12', detail = jsonb_build_object('reason', case when v_session.id is null then 'session_unknown' else 'closed' end)::text;
  end if;
  v_limit := coalesce((public.setting_value(p_workspace_id, 'counter.paid_out_limit_minor') #>> '{}')::bigint, 0);
  if p_kind = 'paid_out' and v_limit > 0 and p_amount_minor > v_limit then
    if not public.has_permission(p_workspace_id, 'recordOutgoingPayments') then
      raise exception 'a paid-out above the limit is recorded by someone who may record outgoing payments' using errcode = 'DKL13',
        detail = jsonb_build_object('reason', 'above_limit', 'limit_minor', v_limit::text)::text;
    end if;
    v_approved := v_me;
  end if;
  insert into public.counter_cash_entries (workspace_id, session_id, kind, amount_minor, reason, purchase_document_id, recorded_by_member_id, approved_by_member_id, request_id)
  values (p_workspace_id, v_session.id, p_kind, p_amount_minor, btrim(p_reason), p_purchase_document_id, v_me, v_approved, p_request_id)
  returning * into v_entry;
  v_result := jsonb_build_object('entry_id', v_entry.id, 'session_id', v_session.id, 'kind', p_kind, 'amount_minor', p_amount_minor::text, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_cash_entry', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_cash_entry_v1(uuid, uuid, uuid, text, bigint, text, uuid) from public, anon;
grant execute on function public.counter_cash_entry_v1(uuid, uuid, uuid, text, bigint, text, uuid) to authenticated;

-- ── what a session should hold: hidden while it is open and counted blind, unless the finances may be seen ──
create or replace function public.counter_session_expected_v1(p_workspace_id uuid, p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_session public.counter_till_sessions;
begin
  perform public.counter_till_or_finance_actor(p_workspace_id);
  select * into v_session from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id;
  if v_session.id is null then
    raise exception 'not a session of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'session_unknown')::text;
  end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    -- the counter reads the expected cash of its own open session only, and never while the drawer is counted blind: the same
    -- boundary as the rows it may select; a closed session's figures are the finances'
    if v_session.state <> 'open'
       or v_session.opened_by_member_id is distinct from (select m.id from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active') then
      raise exception 'the expected cash of this session is not for the counter' using errcode = 'DKN01';
    end if;
    if coalesce((public.setting_value(p_workspace_id, 'counter.blind_count') #>> '{}')::boolean, true) then
      raise exception 'the drawer is counted blind' using errcode = 'DKN01';
    end if;
  end if;
  return public.counter_session_cash(v_session.id) || jsonb_build_object('session_id', v_session.id, 'state', v_session.state);
end;
$fn$;
revoke execute on function public.counter_session_expected_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_session_expected_v1(uuid, uuid) to authenticated;

-- ── close: the drawer counted, the difference and its reason, what goes to the bank ──
create or replace function public.counter_session_close_v1(
  p_workspace_id uuid, p_request_id uuid, p_session_id uuid, p_counted_minor bigint, p_denominations jsonb, p_difference_reason text, p_banked_minor bigint)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_session public.counter_till_sessions;
  v_cash jsonb;
  v_diff bigint;
  v_by_denomination boolean;
  v_result jsonb;
begin
  v_me := public.counter_till_or_finance_actor(p_workspace_id);
  if p_request_id is null or p_session_id is null or p_counted_minor is null or p_counted_minor < 0
     or coalesce(p_banked_minor, 0) < 0 or coalesce(p_banked_minor, 0) > p_counted_minor then
    raise exception 'a session is closed with a request id, its counted amount and what is banked' using errcode = '22023';
  end if;
  v_by_denomination := coalesce((public.setting_value(p_workspace_id, 'counter.count_by_denomination') #>> '{}')::boolean, false);
  if v_by_denomination and public.counter_denominations_total(p_denominations) is distinct from p_counted_minor then
    raise exception 'the drawer is counted by denomination and adds up' using errcode = 'DKL13', detail = jsonb_build_object('reason', 'denominations')::text;
  end if;
  v_digest := md5(p_session_id::text || '|' || p_counted_minor::text || '|' || coalesce(p_denominations::text, '') || '|' || coalesce(p_difference_reason, '') || '|' || coalesce(p_banked_minor, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_session_close', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  -- for update: a sale finalized in this session holds it for share, so it lands here only if it committed first
  select * into v_session from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id for update;
  if v_session.id is null or v_session.state <> 'open' then
    raise exception 'this session is not open' using errcode = 'DKL12', detail = jsonb_build_object('reason', case when v_session.id is null then 'session_unknown' else 'closed' end)::text;
  end if;
  if v_session.opened_by_member_id is distinct from v_me and not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'a session is closed by whoever opened it, or by someone who may see the finances' using errcode = 'DKN01';
  end if;
  v_cash := public.counter_session_cash(v_session.id);
  v_diff := p_counted_minor - (v_cash ->> 'expected_minor')::bigint;
  if v_diff <> 0 and btrim(coalesce(p_difference_reason, '')) = '' then
    raise exception 'a difference is closed with its reason' using errcode = 'DKL13', detail = jsonb_build_object('reason', 'difference_reason', 'difference_minor', v_diff::text)::text;
  end if;
  update public.counter_till_sessions set state = 'closed', closed_by_member_id = v_me, closed_at = now(), counted_minor = p_counted_minor,
         counted_denominations = case when v_by_denomination then p_denominations end, expected_minor = (v_cash ->> 'expected_minor')::bigint,
         difference_minor = v_diff, difference_reason = nullif(btrim(coalesce(p_difference_reason, '')), ''), banked_minor = coalesce(p_banked_minor, 0),
         unresolved_card_minor = (v_cash ->> 'unresolved_card_minor')::bigint
   where id = v_session.id;
  v_result := jsonb_build_object('session_id', v_session.id, 'expected_minor', v_cash ->> 'expected_minor', 'counted_minor', p_counted_minor::text,
    'difference_minor', v_diff::text, 'banked_minor', coalesce(p_banked_minor, 0)::text, 'unresolved_card_minor', v_cash ->> 'unresolved_card_minor', 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_session_close', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_session_close_v1(uuid, uuid, uuid, bigint, jsonb, text, bigint) from public, anon;
grant execute on function public.counter_session_close_v1(uuid, uuid, uuid, bigint, jsonb, text, bigint) to authenticated;

-- the workspace export carries the receipts, their tills, sessions, cash entries and day closes (#2860)
-- restates 0895
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
    -- #4367 the tills, their sessions, the cash entries and the day closes
    'counter_tills', 'counter_till_sessions', 'counter_cash_entries', 'counter_day_closes',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(907);
