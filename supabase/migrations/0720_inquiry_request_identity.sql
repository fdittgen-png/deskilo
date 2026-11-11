-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two nullable columns and a partial unique index on space_inquiry_messages;
--  versioned start and reply; the older two delegate to them unchanged)
--
-- #3745 -- an inquiry or a reply sent twice after a lost answer arrives
-- once. start_space_inquiry and send_inquiry_message (0316) inserted a
-- message on every call, so a send repeated after a timeout or a dropped
-- connection reached the space twice.
--
--  * start_space_inquiry_v1(workspace, body, request_id) and
--    send_inquiry_message_v1(inquiry, body, request_id) take a request id
--    the app makes and keeps until it knows the outcome. The id is bound
--    to its author (the session's user, never sent) on this installation,
--    and to a digest of what it sends and where: the workspace for a start,
--    the inquiry for a reply, and the trimmed body.
--  * A repeat of the same id with the same content answers the first
--    outcome (the inquiry for a start, the message for a reply) and writes
--    nothing. It is answered before the rate limit and the feature switch,
--    since what it asks for already happened. The same id with other
--    content is refused. Different ids are different messages.
--  * Both are restated from the LIVE bodies (0316, with 0324's operation
--    classes: a new inquiry is accept_new, a reply service_existing).
--  * The older functions keep their meaning for an app that sends no id
--    (#3727): they call the new ones without one.

alter table public.space_inquiry_messages
  add column if not exists request_id uuid,
  add column if not exists request_digest text
    check (request_digest is null or char_length(request_digest) = 64);
create unique index if not exists space_inquiry_messages_request_once
  on public.space_inquiry_messages (author_user_id, request_id)
  where request_id is not null;

create or replace function public.inquiry_request_digest(p_kind text, p_target uuid, p_body text)
returns text language sql immutable set search_path = public as $fn$
  select encode(sha256(convert_to(jsonb_build_object(
    'kind', p_kind, 'target', p_target, 'body', btrim(coalesce(p_body, '')))::text, 'UTF8')), 'hex')
$fn$;
revoke execute on function public.inquiry_request_digest(text, uuid, text) from public, anon, authenticated;

-- The first outcome of this author's request id: the inquiry for a start,
-- the message for a reply; null when the id is new. The same id with other
-- content is refused. Holds the request's lock to the end of the
-- transaction, so two concurrent repeats write once.
create or replace function public.inquiry_request_outcome(p_kind text, p_request_id uuid, p_digest text)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare v_row public.space_inquiry_messages;
begin
  if p_request_id is null then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'inquiry_request:' || coalesce(auth.uid()::text, '') || ':' || p_request_id::text, 0));
  select * into v_row from public.space_inquiry_messages
   where author_user_id = auth.uid() and request_id = p_request_id;
  if v_row.id is null then return null; end if;
  if v_row.request_digest is distinct from p_digest then
    raise exception 'this request id was used for another message' using errcode = '22023';
  end if;
  return case when p_kind = 'start' then v_row.inquiry_id else v_row.id end;
end;
$fn$;
revoke execute on function public.inquiry_request_outcome(text, uuid, text) from public, anon, authenticated;

create or replace function public.start_space_inquiry_v1(
  p_workspace uuid, p_body text, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text := public.inquiry_request_digest('start', p_workspace, p_body);
  v_id uuid;
begin
  perform public.mcp_require_native();
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'invalid message';
  end if;
  v_id := public.inquiry_request_outcome('start', p_request_id, v_digest);
  if v_id is not null then return v_id; end if;
  if not exists (select 1 from public.public_workspace_cards where workspace_id = p_workspace)
     or not public.feature_operation_allowed(p_workspace, 'spaceInquiries', 'accept_new') then
    raise exception 'inquiries unavailable';
  end if;
  if public.inquiry_host(p_workspace, auth.uid()) then
    raise exception 'you host this space';
  end if;
  if (select count(*) from public.space_inquiry_messages
       where author_user_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_workspace::text || auth.uid()::text, 1824));
  select id into v_id from public.space_inquiries
   where workspace_id = p_workspace and requester_user_id = auth.uid() and closed_at is null;
  if v_id is null then
    insert into public.space_inquiries (workspace_id, requester_user_id)
    values (p_workspace, auth.uid()) returning id into v_id;
  end if;
  insert into public.space_inquiry_messages (inquiry_id, author_user_id, body, request_id, request_digest)
  values (v_id, auth.uid(), btrim(p_body), p_request_id,
          case when p_request_id is null then null else v_digest end);
  update public.space_inquiries set last_message_at = now() where id = v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.start_space_inquiry_v1(uuid, text, uuid) from public, anon;
grant execute on function public.start_space_inquiry_v1(uuid, text, uuid) to authenticated;

create or replace function public.send_inquiry_message_v1(
  p_inquiry uuid, p_body text, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_inquiry public.space_inquiries;
  v_digest text := public.inquiry_request_digest('reply', p_inquiry, p_body);
  v_id uuid;
begin
  perform public.mcp_require_native();
  select * into v_inquiry from public.space_inquiries where id = p_inquiry;
  if v_inquiry.id is null or public.inquiry_role(p_inquiry) is null then
    raise exception 'inquiry unavailable';
  end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'invalid message';
  end if;
  v_id := public.inquiry_request_outcome('reply', p_request_id, v_digest);
  if v_id is not null then return v_id; end if;
  if v_inquiry.closed_at is not null then raise exception 'inquiry closed'; end if;
  if not public.feature_operation_allowed(v_inquiry.workspace_id, 'spaceInquiries', 'service_existing') then
    raise exception 'inquiries unavailable';
  end if;
  if (select count(*) from public.space_inquiry_messages
       where author_user_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.space_inquiry_messages (inquiry_id, author_user_id, body, request_id, request_digest)
  values (p_inquiry, auth.uid(), btrim(p_body), p_request_id,
          case when p_request_id is null then null else v_digest end)
  returning id into v_id;
  update public.space_inquiries set last_message_at = now() where id = p_inquiry;
  return v_id;
end;
$fn$;
revoke execute on function public.send_inquiry_message_v1(uuid, text, uuid) from public, anon;
grant execute on function public.send_inquiry_message_v1(uuid, text, uuid) to authenticated;

-- The older two, for an app that sends no request id (#3727).
create or replace function public.start_space_inquiry(p_workspace uuid, p_body text)
returns uuid language sql security definer set search_path = public as $fn$
  select public.start_space_inquiry_v1(p_workspace, p_body, null)
$fn$;
revoke execute on function public.start_space_inquiry(uuid, text) from public, anon;
grant execute on function public.start_space_inquiry(uuid, text) to authenticated;
create or replace function public.send_inquiry_message(p_inquiry uuid, p_body text)
returns uuid language sql security definer set search_path = public as $fn$
  select public.send_inquiry_message_v1(p_inquiry, p_body, null)
$fn$;
revoke execute on function public.send_inquiry_message(uuid, text) from public, anon;
grant execute on function public.send_inquiry_message(uuid, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(720);
