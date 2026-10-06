-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0381 — a message may only carry a REFERENCE to something of a workspace
-- when every person in the conversation belongs to that workspace.
--
-- References are the tokens `[res:<id>|…]`, `[space:<kind>:<id>|…]` and
-- `[ref:<kind>:<id>|…]` (reservations, spaces, alerts, validations, invoices,
-- payments, refunds). They are the one way workspace information travels in
-- a message, so the rule is enforced where every message lands — a BEFORE
-- INSERT trigger on each message table — and so covers sending, forwarding
-- and every future path:
--   * a workspace conversation (direct or group): every participant is a
--     member of the conversation's workspace by construction; a reference to
--     ANOTHER workspace needs every participant to be an active member there;
--   * an account conversation (two people): the referenced workspace must
--     hold both as active members;
--   * a workspace broadcast note: only references to that same workspace;
--   * an inquiry (an outside person and a host): no references at all.
-- Quotes (`[quote:…]`) carry no workspace and are never restricted. A
-- reference to something that no longer exists leaks nothing and passes.

create or replace function public.message_ref_workspace(p_kind text, p_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $fn$
  select case p_kind
    when 'res' then (select workspace_id from public.reservations where id = p_id)
    when 'seat' then (select workspace_id from public.seats where id = p_id)
    when 'desk' then (select workspace_id from public.desks where id = p_id)
    when 'office' then (select workspace_id from public.offices where id = p_id)
    when 'level' then (select workspace_id from public.levels where id = p_id)
    when 'alert' then (select workspace_id from public.events where id = p_id)
    when 'validation' then (select workspace_id from public.events where id = p_id)
    when 'invoice' then (select workspace_id from public.invoices where id = p_id)
    when 'refund' then (select workspace_id from public.invoices where id = p_id)
    when 'payment' then (select workspace_id from public.ledger_entries where id = p_id)
  end;
$fn$;

-- The workspaces a body points at (empty for plain text and quotes).
create or replace function public.message_body_workspaces(p_body text)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  m text[];
  v_kind text;
  v_id uuid;
  v_ws uuid;
  v_out uuid[] := '{}';
begin
  if p_body is null then return v_out; end if;
  for m in
    select regexp_matches(p_body,
      '\[(res|space|ref):(?:([a-z]+):)?([0-9a-fA-F-]{36})\|', 'g')
  loop
    v_kind := case m[1] when 'res' then 'res' else m[2] end;
    begin
      v_id := m[3]::uuid;
    exception when others then
      continue;
    end;
    v_ws := public.message_ref_workspace(v_kind, v_id);
    if v_ws is not null and not (v_ws = any(v_out)) then
      v_out := v_out || v_ws;
    end if;
  end loop;
  return v_out;
end;
$fn$;

-- True when every user is an active member of every workspace the body names.
create or replace function public.message_refs_allowed(p_body text, p_users uuid[])
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_ws uuid;
begin
  for v_ws in select unnest(public.message_body_workspaces(p_body)) loop
    if exists (
      select 1 from unnest(p_users) u(uid)
       where uid is null
          or not exists (
            select 1 from public.members m
             where m.workspace_id = v_ws and m.user_id = uid and m.status = 'active')
    ) then
      return false;
    end if;
  end loop;
  return true;
end;
$fn$;

create or replace function public.member_notes_refs_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_users uuid[];
  v_ws uuid;
begin
  if new.body is null or position('[' in new.body) = 0 then return new; end if;
  if new.conversation_id is not null then
    select coalesce(array_agg(m.user_id), '{}') into v_users
      from public.conversation_participants p
      join public.members m on m.id = p.member_id
     where p.conversation_id = new.conversation_id and p.left_at is null;
  elsif new.to_member_id is not null then
    select coalesce(array_agg(m.user_id), '{}') into v_users
      from public.members m where m.id in (new.from_member_id, new.to_member_id);
  else
    -- a broadcast to the whole workspace: only that workspace's own things
    for v_ws in select unnest(public.message_body_workspaces(new.body)) loop
      if v_ws <> new.workspace_id then
        raise exception 'references are only shared with members of the same workspace';
      end if;
    end loop;
    return new;
  end if;
  if not public.message_refs_allowed(new.body, v_users) then
    raise exception 'references are only shared with members of the same workspace';
  end if;
  return new;
end;
$fn$;

create or replace function public.account_messages_refs_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_users uuid[];
begin
  if new.body is null or position('[' in new.body) = 0 then return new; end if;
  select array[c.user_a, c.user_b] into v_users
    from public.account_conversations c where c.id = new.conversation_id;
  if not public.message_refs_allowed(new.body, v_users) then
    raise exception 'references are only shared with members of the same workspace';
  end if;
  return new;
end;
$fn$;

create or replace function public.inquiry_messages_refs_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.body is not null
     and cardinality(public.message_body_workspaces(new.body)) > 0 then
    raise exception 'references are not shared in an inquiry';
  end if;
  return new;
end;
$fn$;

revoke execute on function public.message_ref_workspace(text, uuid) from public, anon;
revoke execute on function public.message_body_workspaces(text) from public, anon;
revoke execute on function public.message_refs_allowed(text, uuid[]) from public, anon;
revoke execute on function public.member_notes_refs_guard() from public, anon;
revoke execute on function public.account_messages_refs_guard() from public, anon;
revoke execute on function public.inquiry_messages_refs_guard() from public, anon;

drop trigger if exists member_notes_refs_guard on public.member_notes;
create trigger member_notes_refs_guard before insert on public.member_notes
  for each row execute function public.member_notes_refs_guard();
drop trigger if exists account_messages_refs_guard on public.account_messages;
create trigger account_messages_refs_guard before insert on public.account_messages
  for each row execute function public.account_messages_refs_guard();
drop trigger if exists inquiry_messages_refs_guard on public.space_inquiry_messages;
create trigger inquiry_messages_refs_guard before insert on public.space_inquiry_messages
  for each row execute function public.inquiry_messages_refs_guard();

-- Which workspaces I share with another person: where the references of a
-- conversation with them may point. Both active members, nothing else shown.
create or replace function public.shared_workspaces_with(p_user uuid)
returns table (id uuid, name text)
language sql
stable
security definer
set search_path = public
as $fn$
  select w.id, w.name
    from public.workspaces w
    join public.members a on a.workspace_id = w.id and a.user_id = auth.uid() and a.status = 'active'
    join public.members b on b.workspace_id = w.id and b.user_id = p_user and b.status = 'active'
   where auth.uid() is not null
   order by w.name;
$fn$;
revoke execute on function public.shared_workspaces_with(uuid) from public, anon;
grant execute on function public.shared_workspaces_with(uuid) to authenticated;

select public.set_deskilo_schema_version(381);
