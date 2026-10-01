-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0326 (#1915) — a rights request is a record with a clock, not a button.
--
-- Export (`export_my_data`) and erasure (`erase_my_membership`) already
-- exist as self-service. What was missing is everything around them that
-- makes a request traceable: when it was received, which controller (the
-- workspace) answers it, when the answer is due, whether and why that
-- was extended, and what actually happened to each store.
--
--   * `rights_requests` holds one request per row. It is written only
--     through definers; a requester reads their own, the controller's
--     staff (owner or `viewPersonalData` in THAT workspace) read the
--     workspace's. No identity document is stored: `identity_check` says
--     HOW the person was identified, never with what.
--   * The clock is a calendar month (`rights_due_on`), not 30 days: the
--     same date in the following month, in the workspace's time zone, or
--     the last day of that month when it has no such date (31 January →
--     28/29 February). The extension adds two further months counted
--     from the receipt; it is allowed only on or before the original due
--     date, needs a reason, and never rewrites `received_at` or `due_on`
--     (a trigger refuses it). The rule is the software's reading of
--     GDPR Art. 12(3) and Regulation 1182/71 and needs legal review.
--   * Submitting needs a membership row in that workspace in ANY status,
--     so a person who left can still exercise their rights, and no
--     feature flag is consulted: a suspended feature or a declined
--     optional consent never closes this route. The controller can also
--     record a request received outside the app.
--   * A completed request carries an outcome manifest: removed,
--     corrected, restricted, retained (with basis and period),
--     pending_external, failed. `preview_my_erasure` says, before a
--     person erases, which stores go and which stay and why — accounting
--     evidence stays, unnecessary answers go — and that a UUID-linked
--     membership row is pseudonymous, not anonymous.
--   * `export_my_data` gains `coverage`: what this export covers (this
--     workspace on this installation) and what it cannot (other
--     installations, device caches, the operator's backups), so it never
--     reads as a complete answer it is not.

-- ── the clock ────────────────────────────────────────────────────────
create or replace function public.rights_due_on(
  p_received timestamptz, p_timezone text, p_months int
) returns date
language sql stable set search_path = public as $fn$
  -- `date + interval 'n months'` keeps the day of month and clamps to
  -- the last day when the target month is shorter.
  select ((p_received at time zone p_timezone)::date
          + make_interval(months => p_months))::date;
$fn$;

revoke execute on function public.rights_due_on(timestamptz, text, int) from public, anon;
grant execute on function public.rights_due_on(timestamptz, text, int) to authenticated;

-- ── who answers for the workspace ────────────────────────────────────
create or replace function public.rights_controller(p_workspace_id uuid)
returns boolean
language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null
     and (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'viewPersonalData'));
$fn$;

revoke execute on function public.rights_controller(uuid) from public, anon;
grant execute on function public.rights_controller(uuid) to authenticated;

-- ── the record ───────────────────────────────────────────────────────
create table if not exists public.rights_requests (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  requester_user_id uuid references auth.users(id) on delete set null,
  member_id uuid references public.members(id) on delete set null,
  kind text not null check (kind in ('access', 'portability', 'rectification',
                                     'restriction', 'objection', 'erasure')),
  details text not null default '' check (char_length(details) <= 2000),
  identity_check text not null
    check (identity_check in ('authenticated_session', 'controller_verified')),
  client_request_id uuid,
  received_at timestamptz not null default now(),
  timezone text not null,
  due_on date not null,
  extended_due_on date,
  extension_reason text,
  extension_noticed_at timestamptz,
  status text not null default 'received'
    check (status in ('received', 'extended', 'completed', 'refused')),
  outcome jsonb,
  refusal_reason text,
  decided_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint rights_requests_extension_whole check (
    (extended_due_on is null) = (extension_reason is null)
    and (extended_due_on is null) = (extension_noticed_at is null)),
  constraint rights_requests_closed_whole check (
    (status in ('completed', 'refused')) = (completed_at is not null))
);
select public.ensure_system_columns('rights_requests');
create unique index if not exists rights_requests_client_once
  on public.rights_requests (requester_user_id, client_request_id)
  where client_request_id is not null;
create index if not exists rights_requests_by_workspace
  on public.rights_requests (workspace_id, status, due_on);
create index if not exists rights_requests_by_requester
  on public.rights_requests (requester_user_id, received_at);

alter table public.rights_requests enable row level security;
revoke all on table public.rights_requests from public, anon, authenticated;
grant select on table public.rights_requests to authenticated;
drop policy if exists mcp_delegated_deny on public.rights_requests;
create policy mcp_delegated_deny on public.rights_requests
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
drop policy if exists rights_requests_select on public.rights_requests;
create policy rights_requests_select on public.rights_requests
  for select to authenticated
  using (requester_user_id = (select auth.uid())
         or public.rights_controller(workspace_id));

-- History is append-only where it matters: the receipt and the first
-- deadline never move, an extension is granted once, and a closed
-- request stays closed.
create or replace function public.rights_requests_guard()
returns trigger
language plpgsql set search_path = public as $fn$
begin
  if new.workspace_id is distinct from old.workspace_id
     or new.kind is distinct from old.kind
     or new.details is distinct from old.details
     or new.received_at is distinct from old.received_at
     or new.timezone is distinct from old.timezone
     or new.due_on is distinct from old.due_on then
    raise exception 'a rights request keeps its receipt and its first deadline';
  end if;
  if old.extended_due_on is not null
     and (new.extended_due_on is distinct from old.extended_due_on
          or new.extension_reason is distinct from old.extension_reason
          or new.extension_noticed_at is distinct from old.extension_noticed_at) then
    raise exception 'a rights request is extended once';
  end if;
  if old.status in ('completed', 'refused') then
    raise exception 'a closed rights request stays closed';
  end if;
  return new;
end $fn$;

drop trigger if exists rights_requests_guard on public.rights_requests;
create trigger rights_requests_guard
  before update on public.rights_requests
  for each row execute function public.rights_requests_guard();

-- ── the person asks ─────────────────────────────────────────────────
create or replace function public.submit_rights_request(
  p_workspace_id uuid, p_kind text, p_details text default '',
  p_client_request_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_tz text;
  v_row public.rights_requests;
begin
  if auth.uid() is null then
    raise exception 'sign in to make a rights request, or contact the space directly';
  end if;
  -- Any membership, active or not: leaving a space does not end your
  -- rights against it. No feature flag is read.
  select * into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid()
   order by (status = 'active') desc, joined_at desc
   limit 1;
  if v_member.id is null then
    raise exception 'you have no membership in this space; contact its controller directly';
  end if;
  if p_client_request_id is not null then
    select * into v_row from public.rights_requests
     where requester_user_id = auth.uid() and client_request_id = p_client_request_id;
    if v_row.id is not null then
      return to_jsonb(v_row);
    end if;
  end if;
  select coalesce(nullif(w.timezone, ''), 'UTC') into v_tz
    from public.workspaces w where w.id = p_workspace_id;
  insert into public.rights_requests
    (workspace_id, requester_user_id, member_id, kind, details, identity_check,
     client_request_id, received_at, timezone, due_on)
  values (p_workspace_id, auth.uid(), v_member.id, p_kind,
          coalesce(btrim(p_details), ''), 'authenticated_session',
          p_client_request_id, now(), v_tz, public.rights_due_on(now(), v_tz, 1))
  returning * into v_row;
  return to_jsonb(v_row);
end $fn$;

revoke execute on function public.submit_rights_request(uuid, text, text, uuid) from public, anon;
grant execute on function public.submit_rights_request(uuid, text, text, uuid) to authenticated;

create or replace function public.my_rights_requests()
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(to_jsonb(r) - 'decided_by' order by r.received_at desc), '[]'::jsonb)
    from public.rights_requests r
   where r.requester_user_id = auth.uid();
$fn$;

revoke execute on function public.my_rights_requests() from public, anon;
grant execute on function public.my_rights_requests() to authenticated;

-- ── the controller records one received elsewhere ───────────────────
create or replace function public.record_rights_request(
  p_workspace_id uuid, p_member_id uuid, p_kind text, p_details text,
  p_received_at timestamptz
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_tz text;
  v_row public.rights_requests;
begin
  if not public.rights_controller(p_workspace_id) then
    raise exception 'only the space''s controller records a rights request';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id;
  if v_member.id is null then
    raise exception 'that person is not a member of this space';
  end if;
  if p_received_at is null or p_received_at > now()
     or p_received_at < now() - interval '1 year' then
    raise exception 'a rights request is received in the past year, not in the future';
  end if;
  select coalesce(nullif(w.timezone, ''), 'UTC') into v_tz
    from public.workspaces w where w.id = p_workspace_id;
  insert into public.rights_requests
    (workspace_id, requester_user_id, member_id, kind, details, identity_check,
     received_at, timezone, due_on)
  values (p_workspace_id, v_member.user_id, v_member.id, p_kind,
          coalesce(btrim(p_details), ''), 'controller_verified',
          p_received_at, v_tz, public.rights_due_on(p_received_at, v_tz, 1))
  returning * into v_row;
  return to_jsonb(v_row);
end $fn$;

revoke execute on function public.record_rights_request(uuid, uuid, text, text, timestamptz) from public, anon;
grant execute on function public.record_rights_request(uuid, uuid, text, text, timestamptz) to authenticated;

-- ── the controller extends, once, in time, with a reason ────────────
create or replace function public.extend_rights_request(
  p_request_id uuid, p_reason text
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_row public.rights_requests;
begin
  select * into v_row from public.rights_requests where id = p_request_id;
  if v_row.id is null or not public.rights_controller(v_row.workspace_id) then
    raise exception 'only the space''s controller extends a rights request';
  end if;
  if v_row.status <> 'received' then
    raise exception 'only an open request that was never extended can be extended';
  end if;
  if (now() at time zone v_row.timezone)::date > v_row.due_on then
    raise exception 'an extension is notified within the first month, not after it';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 10 then
    raise exception 'an extension states its reason';
  end if;
  update public.rights_requests
     set extended_due_on = public.rights_due_on(received_at, timezone, 3),
         extension_reason = btrim(p_reason),
         extension_noticed_at = now(),
         status = 'extended'
   where id = p_request_id
  returning * into v_row;
  return to_jsonb(v_row);
end $fn$;

revoke execute on function public.extend_rights_request(uuid, text) from public, anon;
grant execute on function public.extend_rights_request(uuid, text) to authenticated;

-- ── the outcome says what happened to each store ────────────────────
create or replace function public.rights_outcome_valid(p_outcome jsonb)
returns boolean
language sql immutable set search_path = public as $fn$
  select jsonb_typeof(p_outcome) = 'object'
     and not exists (
       select 1 from jsonb_object_keys(p_outcome) k
        where k not in ('removed', 'corrected', 'restricted', 'retained',
                        'pending_external', 'failed'))
     and not exists (
       select 1 from jsonb_each(p_outcome) e
        where jsonb_typeof(e.value) <> 'array')
     and exists (
       select 1 from jsonb_each(p_outcome) e, jsonb_array_elements(e.value) i)
     and not exists (
       select 1 from jsonb_each(p_outcome) e, jsonb_array_elements(e.value) i
        where coalesce(btrim(i->>'store'), '') = '')
     -- Kept data says why and for how long.
     and not exists (
       select 1 from jsonb_array_elements(coalesce(p_outcome->'retained', '[]'::jsonb)) i
        where coalesce(btrim(i->>'basis'), '') = ''
           or coalesce(btrim(i->>'period'), '') = '');
$fn$;

revoke execute on function public.rights_outcome_valid(jsonb) from public, anon;
grant execute on function public.rights_outcome_valid(jsonb) to authenticated;
revoke execute on function public.rights_requests_guard() from public, anon, authenticated;

create or replace function public.complete_rights_request(
  p_request_id uuid, p_outcome jsonb, p_refusal_reason text default null
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_row public.rights_requests;
begin
  select * into v_row from public.rights_requests where id = p_request_id;
  if v_row.id is null or not public.rights_controller(v_row.workspace_id) then
    raise exception 'only the space''s controller decides a rights request';
  end if;
  if v_row.status in ('completed', 'refused') then
    raise exception 'a closed rights request stays closed';
  end if;
  if p_refusal_reason is not null then
    if char_length(btrim(p_refusal_reason)) < 10 then
      raise exception 'a refusal states its reason';
    end if;
  elsif p_outcome is null or not public.rights_outcome_valid(p_outcome) then
    raise exception 'an outcome names each store as removed, corrected, restricted, retained (with basis and period), pending_external or failed';
  end if;
  update public.rights_requests
     set status = case when p_refusal_reason is null then 'completed' else 'refused' end,
         outcome = p_outcome,
         refusal_reason = btrim(p_refusal_reason),
         decided_by = auth.uid(),
         completed_at = now()
   where id = p_request_id
  returning * into v_row;
  return to_jsonb(v_row);
end $fn$;

revoke execute on function public.complete_rights_request(uuid, jsonb, text) from public, anon;
grant execute on function public.complete_rights_request(uuid, jsonb, text) to authenticated;

-- ── before erasing: what goes, what stays, and why ──────────────────
-- Mirrors `erase_my_membership` (0323) store by store. Nothing here
-- deletes anything.
create or replace function public.preview_my_erasure(p_workspace_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members;
  v_country text;
  v_last boolean;
begin
  v_me := public.my_active_member(p_workspace_id);
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_last := not exists (select 1 from public.members
                         where user_id = v_me.user_id and status = 'active'
                           and id <> v_me.id);
  return jsonb_build_object(
    'removed', jsonb_build_array(
      jsonb_build_object('store', 'messages_sent', 'count',
        (select count(*) from public.member_notes where from_member_id = v_me.id)),
      jsonb_build_object('store', 'custom_answers', 'count',
        (select count(*) from public.workspace_field_values v
          where v.member_id = v_me.id and v.held_until is null
            and not exists (select 1 from public.workspace_field_retention_holds h
                             where h.definition_id = v.definition_id))),
      jsonb_build_object('store', 'profile', 'count', case when v_last then 1 else 0 end,
        'note', case when v_last then 'name, photo, WhatsApp, status, address and VAT id are cleared'
                     else 'kept while you are a member of another space' end)),
    'restricted', jsonb_build_array(
      jsonb_build_object('store', 'open_reservations', 'count',
        (select count(*) from public.reservations
          where member_id = v_me.id and status in ('reserved', 'checked_in')),
        'note', 'cancelled')),
    'retained', jsonb_build_array(
      jsonb_build_object('store', 'invoices', 'count',
        (select count(*) from public.invoices where member_id = v_me.id),
        'basis', 'accounting evidence the space must keep; issued documents are not rewritten',
        'period', 'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),
      jsonb_build_object('store', 'ledger_entries', 'count',
        (select count(*) from public.ledger_entries where member_id = v_me.id),
        'basis', 'the space''s accounts',
        'period', 'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),
      jsonb_build_object('store', 'past_reservations', 'count',
        (select count(*) from public.reservations
          where member_id = v_me.id and status not in ('reserved', 'checked_in')),
        'basis', 'the space''s occupancy record',
        'period', 'the workspace''s booking-history limit'),
      jsonb_build_object('store', 'membership_row', 'count', 1,
        'basis', 'links the retained records above; pseudonymous (a UUID), not anonymous',
        'period', 'the life of the space'),
      jsonb_build_object('store', 'custom_answers_under_hold', 'count',
        (select count(*) from public.workspace_field_values v
          join public.workspace_field_retention_holds h on h.definition_id = v.definition_id
          where v.member_id = v_me.id),
        'basis', 'a retention hold the owner documented for that question',
        'period', 'the hold''s own period, then deleted')),
    'pending_external', jsonb_build_array(
      jsonb_build_object('store', 'other_installations',
        'note', 'another DesKilo installation is a separate controller; ask it directly'),
      jsonb_build_object('store', 'device_caches',
        'note', 'cleared when you sign out of each device'),
      jsonb_build_object('store', 'operator_backups',
        'note', 'expire on the operator''s backup rotation'))
  );
end $fn$;

revoke execute on function public.preview_my_erasure(uuid) from public, anon;
grant execute on function public.preview_my_erasure(uuid) to authenticated;

-- ── the access export says what it covers ───────────────────────────
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0326: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'rights_requests', (select coalesce(jsonb_agg(to_jsonb(rr) - 'decided_by'), '[]'::jsonb) from public.rights_requests rr where rr.requester_user_id = auth.uid() and rr.workspace_id = p_workspace_id),
    'coverage', jsonb_build_object(
      'covers', 'this workspace on this installation',
      'portability', 'the data you provided and the records of your use are in machine-readable JSON; derived assessments are not',
      'not_covered', jsonb_build_array(
        jsonb_build_object('store', 'other_installations', 'note', 'a separate installation is a separate controller'),
        jsonb_build_object('store', 'device_caches', 'note', 'held on your own devices'),
        jsonb_build_object('store', 'operator_backups', 'note', 'restored only by the operator; ask the controller'))),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(326);
