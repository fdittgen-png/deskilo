-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0316 (#1824) -- every message belongs to a context, and the context
-- decides who reads it.
--
--   space conversation  -- its participants (0313)
--   account conversation -- the two people (0305)
--   inquiry             -- the person who asked, and the space's HOSTS:
--                          active owners, plus active administrators who
--                          opted in as public contacts (0305's
--                          member_public_contact) -- exactly the roster the
--                          published page shows before anyone writes.
--
-- What this adds:
--   * forwarding. A copy is inserted into a context the forwarder takes
--     part in, carrying `forwarded_from` (origin kind, context, author,
--     time). The source records a `forwarded` event and its conversation
--     gets a NOTICE: who forwarded it, and where. A forward never widens
--     who reads the original. An author may lock a message
--     (`no_forward`); a space whose `messageForwarding` is off refuses
--     forwards OUT of it. Account messages always allow it.
--   * notices. A notice is an ordinary row in the context's own table,
--     authored by the actor, whose `notice` jsonb says what happened
--     (`forwarded` | `captured`). The body is a plain fallback sentence
--     for clients that predate it; a notice cannot be forwarded.
--   * history. `message_history` answers, for a message the caller can
--     read, what happened to it: sent, read, forwarded (by whom, where),
--     and -- for a forward -- its provenance. Nobody reading a forward
--     learns anything about the original's own history.
--   * inquiries, account read receipts, deleting one's own account
--     message, and one inbox across every context on this server.
--
-- `message_events` has no client access at all: it is read only through
-- `message_history`, which re-checks that the caller can read the
-- message.

-- ── columns ─────────────────────────────────────────────────────────

alter table public.member_notes
  add column no_forward boolean not null default false,
  add column forwarded_from jsonb,
  add column notice jsonb;

alter table public.account_messages
  add column no_forward boolean not null default false,
  add column forwarded_from jsonb,
  add column notice jsonb,
  add column read_at timestamptz;

-- ── events ──────────────────────────────────────────────────────────

create table public.message_events (
  id uuid primary key default gen_random_uuid(),
  message_kind text not null check (message_kind in
    ('member_note', 'account_message', 'inquiry_message')),
  message_id uuid not null,
  event text not null check (event in
    ('sent', 'read', 'forwarded', 'deleted', 'captured')),
  actor_user_id uuid references auth.users(id) on delete set null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('message_events');
alter table public.message_events enable row level security;
revoke all on public.message_events from public, anon, authenticated;
create policy mcp_delegated_deny on public.message_events as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index message_events_message_idx
  on public.message_events (message_kind, message_id, created_at);
create index message_events_actor_idx
  on public.message_events (actor_user_id, event, created_at);

-- ── inquiries ───────────────────────────────────────────────────────

create table public.space_inquiries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  requester_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  last_message_at timestamptz not null default now()
);
select public.ensure_system_columns('space_inquiries');
alter table public.space_inquiries enable row level security;
revoke all on public.space_inquiries from public, anon, authenticated;
create policy mcp_delegated_deny on public.space_inquiries as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create unique index space_inquiries_one_open
  on public.space_inquiries (workspace_id, requester_user_id)
  where closed_at is null;
create index space_inquiries_requester_idx
  on public.space_inquiries (requester_user_id, last_message_at);
create index space_inquiries_workspace_idx
  on public.space_inquiries (workspace_id, last_message_at);

create table public.space_inquiry_messages (
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null references public.space_inquiries(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  body text not null check (length(btrim(body)) between 1 and 4000),
  no_forward boolean not null default false,
  forwarded_from jsonb,
  notice jsonb,
  read_by_requester_at timestamptz,
  read_by_hosts_at timestamptz,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('space_inquiry_messages');
alter table public.space_inquiry_messages enable row level security;
revoke all on public.space_inquiry_messages from public, anon, authenticated;
create policy mcp_delegated_deny on public.space_inquiry_messages as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index space_inquiry_messages_thread_idx
  on public.space_inquiry_messages (inquiry_id, created_at, id);
create index space_inquiry_messages_author_idx
  on public.space_inquiry_messages (author_user_id, created_at);

-- ── internal helpers (never granted to a client) ─────────────────────

create or replace function public.account_display_name(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select nullif(p.display_name, '') from public.profiles p where p.id = p_user), '');
$$;
revoke execute on function public.account_display_name(uuid) from public, anon, authenticated;

-- A host answers inquiries: an active owner, or an active administrator
-- who opted in as a public contact. The same roster the page shows.
create or replace function public.inquiry_host(p_workspace uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
      left join public.member_public_contact c on c.member_id = m.id
     where m.workspace_id = p_workspace and m.user_id = p_user
       and m.status = 'active'
       and (m.is_owner or (m.is_admin and coalesce(c.visible, false))));
$$;
revoke execute on function public.inquiry_host(uuid, uuid) from public, anon, authenticated;

-- The caller's part in an inquiry: 'requester', 'host' or null.
create or replace function public.inquiry_role(p_inquiry uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when i.requester_user_id = auth.uid() then 'requester'
    when public.inquiry_host(i.workspace_id, auth.uid()) then 'host'
  end
  from public.space_inquiries i where i.id = p_inquiry;
$$;
revoke execute on function public.inquiry_role(uuid) from public, anon, authenticated;

-- A message the CALLER can read, as one jsonb; null when they cannot.
create or replace function public.message_source(p_kind text, p_message_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if p_kind = 'member_note' then
    select jsonb_build_object(
             'workspace_id', n.workspace_id,
             'author_user_id', m.user_id,
             'author_name', coalesce(nullif(p.display_name, ''), m.managed_name, ''),
             'body', n.body, 'sent_at', n.created_at,
             'no_forward', n.no_forward, 'is_notice', n.notice is not null,
             'forwarded_from', n.forwarded_from,
             'context_kind', 'conversation', 'family', 'space',
             'context_id', n.conversation_id,
             'context_label', w.name || coalesce(' · ' || c.title, ''),
             'from_member_id', n.from_member_id, 'to_member_id', n.to_member_id,
             'read_at', n.read_at)
      into v
      from public.member_notes n
      join public.workspaces w on w.id = n.workspace_id
      join public.members m on m.id = n.from_member_id
      left join public.profiles p on p.id = m.user_id
      left join public.conversations c on c.id = n.conversation_id
     where n.id = p_message_id
       and public.can_read_member_note(n.workspace_id, n.from_member_id, n.to_member_id,
                                       n.conversation_id, n.created_at);
  elsif p_kind = 'account_message' then
    select jsonb_build_object(
             'workspace_id', null,
             'author_user_id', a.author_id,
             'author_name', public.account_display_name(a.author_id),
             'body', a.body, 'sent_at', a.created_at,
             'no_forward', a.no_forward, 'is_notice', a.notice is not null,
             'forwarded_from', a.forwarded_from,
             'context_kind', 'account_conversation', 'family', 'account',
             'context_id', a.conversation_id, 'context_label', '',
             'peer_user_id', case when c.user_a = auth.uid() then c.user_b else c.user_a end,
             'read_at', a.read_at)
      into v
      from public.account_messages a
      join public.account_conversations c on c.id = a.conversation_id
     where a.id = p_message_id and auth.uid() in (c.user_a, c.user_b);
  elsif p_kind = 'inquiry_message' then
    select jsonb_build_object(
             'workspace_id', i.workspace_id,
             'author_user_id', q.author_user_id,
             'author_name', public.account_display_name(q.author_user_id),
             'body', q.body, 'sent_at', q.created_at,
             'no_forward', q.no_forward, 'is_notice', q.notice is not null,
             'forwarded_from', q.forwarded_from,
             'context_kind', 'inquiry', 'family', 'inquiry',
             'context_id', q.inquiry_id, 'context_label', w.name,
             'requester_user_id', i.requester_user_id,
             'from_requester', q.author_user_id is not distinct from i.requester_user_id,
             'read_by_requester_at', q.read_by_requester_at,
             'read_by_hosts_at', q.read_by_hosts_at)
      into v
      from public.space_inquiry_messages q
      join public.space_inquiries i on i.id = q.inquiry_id
      join public.workspaces w on w.id = i.workspace_id
     where q.id = p_message_id and public.inquiry_role(i.id) is not null;
  end if;
  return v;
end;
$$;
revoke execute on function public.message_source(text, uuid) from public, anon, authenticated;

-- Posts a notice into a context as the caller; returns its id, or null
-- when the caller has no row to speak from there.
create or replace function public.post_context_notice(
  p_context_kind text, p_context_id uuid, p_notice jsonb, p_body text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_conv public.conversations;
  v_me uuid;
  v_other uuid;
begin
  if p_context_kind = 'conversation' then
    select * into v_conv from public.conversations where id = p_context_id;
    select p.member_id into v_me
      from public.conversation_participants p
      join public.members m on m.id = p.member_id
     where p.conversation_id = p_context_id
       and m.user_id = auth.uid() and m.status = 'active';
    if v_conv.id is null or v_me is null then return null; end if;
    if v_conv.kind = 'direct' then
      select member_id into v_other from public.conversation_participants
       where conversation_id = p_context_id and member_id <> v_me limit 1;
    end if;
    insert into public.member_notes
      (workspace_id, from_member_id, to_member_id, body, conversation_id, notice)
    values (v_conv.workspace_id, v_me, v_other, p_body, p_context_id, p_notice)
    returning id into v_id;
  elsif p_context_kind = 'account_conversation' then
    if not exists (select 1 from public.account_conversations c
                    where c.id = p_context_id and auth.uid() in (c.user_a, c.user_b)) then
      return null;
    end if;
    insert into public.account_messages (conversation_id, author_id, body, notice)
    values (p_context_id, auth.uid(), p_body, p_notice)
    returning id into v_id;
    update public.account_conversations set updated_at = now() where id = p_context_id;
  elsif p_context_kind = 'inquiry' then
    if public.inquiry_role(p_context_id) is null then return null; end if;
    insert into public.space_inquiry_messages (inquiry_id, author_user_id, body, notice)
    values (p_context_id, auth.uid(), p_body, p_notice)
    returning id into v_id;
    update public.space_inquiries set last_message_at = now() where id = p_context_id;
  end if;
  return v_id;
end;
$$;
revoke execute on function public.post_context_notice(text, uuid, jsonb, text)
  from public, anon, authenticated;

-- ── inquiries ───────────────────────────────────────────────────────

create or replace function public.space_host_roster(p_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null
     or not exists (select 1 from public.public_workspace_cards where workspace_id = p_workspace) then
    raise exception 'workspace not published';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'name', coalesce(nullif(p.display_name, ''), m.managed_name, ''),
             'role', case when m.is_owner then 'owner' else 'admin' end)
           order by m.is_owner desc, coalesce(p.display_name, ''), m.id)
      from public.members m
      left join public.profiles p on p.id = m.user_id
     where m.workspace_id = p_workspace and m.user_id is not null
       and public.inquiry_host(p_workspace, m.user_id)), '[]'::jsonb);
end;
$$;
revoke execute on function public.space_host_roster(uuid) from public, anon;
grant execute on function public.space_host_roster(uuid) to authenticated;

create or replace function public.start_space_inquiry(p_workspace uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.mcp_require_native();
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'invalid message';
  end if;
  if not exists (select 1 from public.public_workspace_cards where workspace_id = p_workspace)
     or not public.feature_effective(p_workspace, 'spaceInquiries') then
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
  insert into public.space_inquiry_messages (inquiry_id, author_user_id, body)
  values (v_id, auth.uid(), btrim(p_body));
  update public.space_inquiries set last_message_at = now() where id = v_id;
  return v_id;
end;
$$;
revoke execute on function public.start_space_inquiry(uuid, text) from public, anon;
grant execute on function public.start_space_inquiry(uuid, text) to authenticated;

create or replace function public.send_inquiry_message(p_inquiry uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inquiry public.space_inquiries;
  v_id uuid;
begin
  perform public.mcp_require_native();
  select * into v_inquiry from public.space_inquiries where id = p_inquiry;
  if v_inquiry.id is null or public.inquiry_role(p_inquiry) is null then
    raise exception 'inquiry unavailable';
  end if;
  if v_inquiry.closed_at is not null then raise exception 'inquiry closed'; end if;
  if not public.feature_effective(v_inquiry.workspace_id, 'spaceInquiries') then
    raise exception 'inquiries unavailable';
  end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'invalid message';
  end if;
  if (select count(*) from public.space_inquiry_messages
       where author_user_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.space_inquiry_messages (inquiry_id, author_user_id, body)
  values (p_inquiry, auth.uid(), btrim(p_body)) returning id into v_id;
  update public.space_inquiries set last_message_at = now() where id = p_inquiry;
  return v_id;
end;
$$;
revoke execute on function public.send_inquiry_message(uuid, text) from public, anon;
grant execute on function public.send_inquiry_message(uuid, text) to authenticated;

create or replace function public.my_inquiries()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  return coalesce((select jsonb_agg(x order by x.last_at desc, x.id desc) from (
    select i.id, i.workspace_id, w.name as workspace_name, i.closed_at,
           coalesce(last.body, '') as last_body,
           coalesce(last.created_at, i.last_message_at) as last_at,
           (select count(*)::int from public.space_inquiry_messages q
             where q.inquiry_id = i.id
               and q.author_user_id is distinct from auth.uid()
               and q.read_by_requester_at is null) as unread
      from public.space_inquiries i
      join public.workspaces w on w.id = i.workspace_id
      left join lateral (
        select q.body, q.created_at from public.space_inquiry_messages q
         where q.inquiry_id = i.id order by q.created_at desc, q.id desc limit 1) last on true
     where i.requester_user_id = auth.uid()
     order by i.last_message_at desc limit 200) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_inquiries() from public, anon;
grant execute on function public.my_inquiries() to authenticated;

create or replace function public.workspace_inquiries(p_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if not public.inquiry_host(p_workspace, auth.uid()) then
    raise exception 'hosts only';
  end if;
  return coalesce((select jsonb_agg(x order by x.last_at desc, x.id desc) from (
    select i.id, i.workspace_id, w.name as workspace_name, i.closed_at,
           i.requester_user_id,
           public.account_display_name(i.requester_user_id) as requester_name,
           coalesce(last.body, '') as last_body,
           coalesce(last.created_at, i.last_message_at) as last_at,
           (select count(*)::int from public.space_inquiry_messages q
             where q.inquiry_id = i.id
               and q.author_user_id is not distinct from i.requester_user_id
               and q.read_by_hosts_at is null) as unread
      from public.space_inquiries i
      join public.workspaces w on w.id = i.workspace_id
      left join lateral (
        select q.body, q.created_at from public.space_inquiry_messages q
         where q.inquiry_id = i.id order by q.created_at desc, q.id desc limit 1) last on true
     where i.workspace_id = p_workspace
     order by i.last_message_at desc limit 200) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.workspace_inquiries(uuid) from public, anon;
grant execute on function public.workspace_inquiries(uuid) to authenticated;

create or replace function public.inquiry_messages(
  p_inquiry uuid, p_before_at timestamptz default null, p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if public.inquiry_role(p_inquiry) is null then raise exception 'inquiry unavailable'; end if;
  if (p_before_at is null) <> (p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(x order by x.created_at desc, x.id desc) from (
    select q.id, q.body, q.created_at,
           q.author_user_id = auth.uid() as is_mine,
           public.account_display_name(q.author_user_id) as author_name,
           q.author_user_id is not distinct from i.requester_user_id as from_requester,
           case when q.author_user_id is not distinct from i.requester_user_id
                then q.read_by_hosts_at else q.read_by_requester_at end as read_at,
           q.no_forward, q.forwarded_from, q.notice
      from public.space_inquiry_messages q
      join public.space_inquiries i on i.id = q.inquiry_id
     where q.inquiry_id = p_inquiry
       and (p_before_at is null or (q.created_at, q.id) < (p_before_at, p_before_id))
     order by q.created_at desc, q.id desc limit 50) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.inquiry_messages(uuid, timestamptz, uuid) from public, anon;
grant execute on function public.inquiry_messages(uuid, timestamptz, uuid) to authenticated;

create or replace function public.mark_inquiry_read(p_inquiry uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_role text; v_requester uuid;
begin
  perform public.mcp_require_native();
  v_role := public.inquiry_role(p_inquiry);
  if v_role is null then raise exception 'inquiry unavailable'; end if;
  select requester_user_id into v_requester from public.space_inquiries where id = p_inquiry;
  if v_role = 'requester' then
    update public.space_inquiry_messages set read_by_requester_at = now()
     where inquiry_id = p_inquiry and read_by_requester_at is null
       and author_user_id is distinct from v_requester;
  else
    update public.space_inquiry_messages set read_by_hosts_at = now()
     where inquiry_id = p_inquiry and read_by_hosts_at is null
       and author_user_id is not distinct from v_requester;
  end if;
end;
$$;
revoke execute on function public.mark_inquiry_read(uuid) from public, anon;
grant execute on function public.mark_inquiry_read(uuid) to authenticated;

create or replace function public.close_space_inquiry(p_inquiry uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if public.inquiry_role(p_inquiry) is null then raise exception 'inquiry unavailable'; end if;
  update public.space_inquiries set closed_at = coalesce(closed_at, now()) where id = p_inquiry;
end;
$$;
revoke execute on function public.close_space_inquiry(uuid) from public, anon;
grant execute on function public.close_space_inquiry(uuid) to authenticated;

-- ── forwarding, lock, history, capture ──────────────────────────────

create or replace function public.forward_message(
  p_kind text, p_message_id uuid, p_target_kind text, p_target_id uuid,
  p_expected_account uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_src jsonb;
  v_from jsonb;
  v_new uuid;
  v_label text;
  v_actor text;
  v_conv public.conversations;
  v_inquiry public.space_inquiries;
  v_me uuid;
  v_other uuid;
begin
  perform public.mcp_require_native();
  if p_expected_account is not null and p_expected_account is distinct from auth.uid() then
    raise exception 'account changed';
  end if;
  v_src := public.message_source(p_kind, p_message_id);
  if v_src is null then raise exception 'message unavailable'; end if;
  if (v_src->>'is_notice')::boolean then raise exception 'a notice cannot be forwarded'; end if;
  if (v_src->>'no_forward')::boolean then raise exception 'the author locked this message'; end if;
  if v_src->>'workspace_id' is not null
     and not public.feature_effective((v_src->>'workspace_id')::uuid, 'messageForwarding') then
    raise exception 'forwarding is off in this space';
  end if;
  if p_target_kind = v_src->>'context_kind'
     and p_target_id::text = v_src->>'context_id' then
    raise exception 'already in this conversation';
  end if;
  if (select count(*) from public.message_events
       where actor_user_id = auth.uid() and event = 'forwarded'
         and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  v_from := jsonb_build_object(
    'kind', p_kind, 'message_id', p_message_id,
    'context_kind', v_src->>'family', 'context_label', v_src->>'context_label',
    'author_name', v_src->>'author_name', 'sent_at', v_src->'sent_at');

  if p_target_kind = 'conversation' then
    select * into v_conv from public.conversations where id = p_target_id;
    select p.member_id into v_me
      from public.conversation_participants p
      join public.members m on m.id = p.member_id
     where p.conversation_id = p_target_id and p.left_at is null
       and m.user_id = auth.uid() and m.status = 'active';
    if v_conv.id is null or v_me is null then raise exception 'not in this conversation'; end if;
    if length(v_src->>'body') > 500 then
      raise exception 'message too long for this conversation';
    end if;
    if v_conv.kind = 'direct' then
      select member_id into v_other from public.conversation_participants
       where conversation_id = p_target_id and member_id <> v_me limit 1;
    end if;
    insert into public.member_notes
      (workspace_id, from_member_id, to_member_id, body, conversation_id, forwarded_from)
    values (v_conv.workspace_id, v_me, v_other, v_src->>'body', p_target_id, v_from)
    returning id into v_new;
    select w.name || coalesce(' · ' || v_conv.title, '') into v_label
      from public.workspaces w where w.id = v_conv.workspace_id;
  elsif p_target_kind = 'account_conversation' then
    if not exists (select 1 from public.account_conversations c
                    where c.id = p_target_id and auth.uid() in (c.user_a, c.user_b)) then
      raise exception 'conversation unavailable';
    end if;
    insert into public.account_messages (conversation_id, author_id, body, forwarded_from)
    values (p_target_id, auth.uid(), v_src->>'body', v_from)
    returning id into v_new;
    update public.account_conversations set updated_at = now() where id = p_target_id;
    -- A personal conversation is never named to the source.
    v_label := '';
  elsif p_target_kind = 'inquiry' then
    select * into v_inquiry from public.space_inquiries where id = p_target_id;
    if v_inquiry.id is null or public.inquiry_role(p_target_id) is null then
      raise exception 'inquiry unavailable';
    end if;
    if v_inquiry.closed_at is not null then raise exception 'inquiry closed'; end if;
    if not public.feature_effective(v_inquiry.workspace_id, 'spaceInquiries') then
      raise exception 'inquiries unavailable';
    end if;
    insert into public.space_inquiry_messages (inquiry_id, author_user_id, body, forwarded_from)
    values (p_target_id, auth.uid(), v_src->>'body', v_from)
    returning id into v_new;
    update public.space_inquiries set last_message_at = now() where id = p_target_id;
    select w.name into v_label from public.workspaces w where w.id = v_inquiry.workspace_id;
  else
    raise exception 'unknown target';
  end if;

  v_actor := public.account_display_name(auth.uid());
  insert into public.message_events (message_kind, message_id, event, actor_user_id, detail)
  values (p_kind, p_message_id, 'forwarded', auth.uid(),
          jsonb_build_object('target_kind', p_target_kind, 'target_label', v_label,
                             'actor_name', v_actor));
  if v_src->>'context_id' is not null then
    perform public.post_context_notice(v_src->>'context_kind', (v_src->>'context_id')::uuid,
      jsonb_build_object('kind', 'forwarded', 'actor_name', v_actor,
                         'target_kind', p_target_kind, 'target_label', v_label,
                         'message_id', p_message_id, 'at', now()),
      'Forwarded a message');
  end if;
  return v_new;
end;
$$;
revoke execute on function public.forward_message(text, uuid, text, uuid, uuid) from public, anon;
grant execute on function public.forward_message(text, uuid, text, uuid, uuid) to authenticated;

create or replace function public.set_message_forward_lock(
  p_kind text, p_message_id uuid, p_locked boolean
) returns void language plpgsql security definer set search_path = public as $$
declare v_src jsonb;
begin
  perform public.mcp_require_native();
  v_src := public.message_source(p_kind, p_message_id);
  if v_src is null or p_locked is null
     or v_src->>'author_user_id' is distinct from auth.uid()::text then
    raise exception 'only the author can lock a message';
  end if;
  if p_kind = 'member_note' then
    update public.member_notes set no_forward = p_locked where id = p_message_id;
  elsif p_kind = 'account_message' then
    update public.account_messages set no_forward = p_locked where id = p_message_id;
  else
    update public.space_inquiry_messages set no_forward = p_locked where id = p_message_id;
  end if;
end;
$$;
revoke execute on function public.set_message_forward_lock(text, uuid, boolean) from public, anon;
grant execute on function public.set_message_forward_lock(text, uuid, boolean) to authenticated;

-- What happened to a message the caller can read. A forward shows its
-- own story plus where it came from -- never the original's history.
create or replace function public.message_history(p_kind text, p_message_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_src jsonb;
  v_rows jsonb := '[]'::jsonb;
begin
  perform public.mcp_require_native();
  v_src := public.message_source(p_kind, p_message_id);
  if v_src is null then raise exception 'message unavailable'; end if;

  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'event', 'sent', 'at', v_src->'sent_at', 'actor_name', v_src->>'author_name',
    'detail', '{}'::jsonb));
  if jsonb_typeof(v_src->'forwarded_from') = 'object' then
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'event', 'forwarded_from', 'at', v_src->'forwarded_from'->'sent_at',
      'actor_name', v_src->'forwarded_from'->>'author_name',
      'detail', v_src->'forwarded_from'));
  end if;

  if p_kind = 'member_note' then
    if v_src->>'to_member_id' is not null then
      if v_src->>'read_at' is not null then
        v_rows := v_rows || jsonb_build_array(jsonb_build_object(
          'event', 'read', 'at', v_src->'read_at',
          'actor_name', (select coalesce(nullif(p.display_name, ''), m.managed_name, '')
                           from public.members m left join public.profiles p on p.id = m.user_id
                          where m.id = (v_src->>'to_member_id')::uuid),
          'detail', '{}'::jsonb));
      end if;
    elsif v_src->>'context_id' is not null then
      -- A group keeps one read watermark per participant (0125).
      v_rows := v_rows || coalesce((select jsonb_agg(jsonb_build_object(
          'event', 'read', 'at', cp.last_read_at,
          'actor_name', coalesce(nullif(p.display_name, ''), m.managed_name, ''),
          'detail', jsonb_build_object('watermark', true)))
          from public.conversation_participants cp
          join public.members m on m.id = cp.member_id
          left join public.profiles p on p.id = m.user_id
         where cp.conversation_id = (v_src->>'context_id')::uuid
           and cp.member_id <> (v_src->>'from_member_id')::uuid
           and cp.last_read_at >= (v_src->>'sent_at')::timestamptz), '[]'::jsonb);
    end if;
  elsif p_kind = 'account_message' then
    if v_src->>'read_at' is not null then
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'event', 'read', 'at', v_src->'read_at',
        'actor_name', case when v_src->>'author_user_id' = auth.uid()::text
                           then public.account_display_name((v_src->>'peer_user_id')::uuid)
                           else public.account_display_name(auth.uid()) end,
        'detail', '{}'::jsonb));
    end if;
  else
    if (v_src->>'from_requester')::boolean and v_src->>'read_by_hosts_at' is not null then
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'event', 'read', 'at', v_src->'read_by_hosts_at',
        'actor_name', v_src->>'context_label',
        'detail', jsonb_build_object('by', 'hosts')));
    elsif not (v_src->>'from_requester')::boolean and v_src->>'read_by_requester_at' is not null then
      v_rows := v_rows || jsonb_build_array(jsonb_build_object(
        'event', 'read', 'at', v_src->'read_by_requester_at',
        'actor_name', public.account_display_name((v_src->>'requester_user_id')::uuid),
        'detail', jsonb_build_object('by', 'requester')));
    end if;
  end if;

  v_rows := v_rows || coalesce((select jsonb_agg(jsonb_build_object(
      'event', e.event, 'at', e.created_at,
      'actor_name', public.account_display_name(e.actor_user_id),
      'detail', e.detail) order by e.created_at)
      from public.message_events e
     where e.message_kind = p_kind and e.message_id = p_message_id), '[]'::jsonb);

  return (select jsonb_agg(r order by (r->>'at')::timestamptz nulls first)
            from jsonb_array_elements(v_rows) r);
end;
$$;
revoke execute on function public.message_history(text, uuid) from public, anon;
grant execute on function public.message_history(text, uuid) to authenticated;

create or replace function public.record_screen_capture(p_kind text, p_context_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_workspace uuid;
  v_notice uuid;
begin
  perform public.mcp_require_native();
  if p_kind = 'conversation' then
    select c.workspace_id into v_workspace
      from public.conversations c
      join public.conversation_participants p on p.conversation_id = c.id and p.left_at is null
      join public.members m on m.id = p.member_id
     where c.id = p_context_id and m.user_id = auth.uid() and m.status = 'active';
    if v_workspace is null then raise exception 'not in this conversation'; end if;
  elsif p_kind = 'account_conversation' then
    if not exists (select 1 from public.account_conversations c
                    where c.id = p_context_id and auth.uid() in (c.user_a, c.user_b)) then
      raise exception 'conversation unavailable';
    end if;
  elsif p_kind = 'inquiry' then
    if public.inquiry_role(p_context_id) is null then raise exception 'inquiry unavailable'; end if;
    select workspace_id into v_workspace from public.space_inquiries where id = p_context_id;
  else
    raise exception 'unknown context';
  end if;
  -- A space that switched the protection off is not told about captures.
  if v_workspace is not null
     and not public.feature_effective(v_workspace, 'captureProtection') then
    return;
  end if;
  -- One notice per person and context in ten seconds: a burst of
  -- screenshots is one fact.
  if exists (select 1 from public.message_events
              where actor_user_id = auth.uid() and event = 'captured'
                and detail->>'context_id' = p_context_id::text
                and created_at > now() - interval '10 seconds') then
    return;
  end if;
  v_notice := public.post_context_notice(p_kind, p_context_id,
    jsonb_build_object('kind', 'captured',
                       'actor_name', public.account_display_name(auth.uid()),
                       'at', now()),
    'Took a screenshot');
  insert into public.message_events (message_kind, message_id, event, actor_user_id, detail)
  values (case p_kind when 'conversation' then 'member_note'
                      when 'account_conversation' then 'account_message'
                      else 'inquiry_message' end,
          v_notice, 'captured', auth.uid(),
          jsonb_build_object('context_kind', p_kind, 'context_id', p_context_id));
end;
$$;
revoke execute on function public.record_screen_capture(text, uuid) from public, anon;
grant execute on function public.record_screen_capture(text, uuid) to authenticated;

-- ── account messages catch up ───────────────────────────────────────

create or replace function public.mark_account_conversation_read(p_conversation uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if not exists (select 1 from public.account_conversations c
                  where c.id = p_conversation and auth.uid() in (c.user_a, c.user_b)) then
    raise exception 'conversation unavailable';
  end if;
  update public.account_messages set read_at = now()
   where conversation_id = p_conversation and read_at is null
     and author_id is distinct from auth.uid();
end;
$$;
revoke execute on function public.mark_account_conversation_read(uuid) from public, anon;
grant execute on function public.mark_account_conversation_read(uuid) to authenticated;

create or replace function public.delete_account_message(p_message uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_conversation uuid;
begin
  perform public.mcp_require_native();
  select conversation_id into v_conversation from public.account_messages
   where id = p_message and author_id = auth.uid();
  if v_conversation is null then raise exception 'only the author can delete a message'; end if;
  delete from public.account_messages where id = p_message;
  insert into public.message_events (message_kind, message_id, event, actor_user_id, detail)
  values ('account_message', p_message, 'deleted', auth.uid(),
          jsonb_build_object('context_kind', 'account_conversation',
                             'context_id', v_conversation));
end;
$$;
revoke execute on function public.delete_account_message(uuid) from public, anon;
grant execute on function public.delete_account_message(uuid) to authenticated;

-- 0305's readers gain fields; nothing is renamed.
create or replace function public.my_account_conversations(p_before_at timestamptz default null, p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
  if (p_before_at is null) <> (p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(x order by x.updated_at desc, x.id desc) from (
    select c.id, c.updated_at,
           case when c.user_a = auth.uid() then c.user_b else c.user_a end as recipient,
           coalesce(p.display_name, '') as name,
           (select count(*)::int from public.account_messages m
             where m.conversation_id = c.id and m.read_at is null
               and m.author_id is distinct from auth.uid()) as unread
      from public.account_conversations c
      left join public.profiles p
        on p.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
     where auth.uid() in (c.user_a, c.user_b)
       and (p_before_at is null or (c.updated_at, c.id) < (p_before_at, p_before_id))
     order by c.updated_at desc, c.id desc limit 50) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_account_conversations(timestamptz, uuid) from public, anon;
grant execute on function public.my_account_conversations(timestamptz, uuid) to authenticated;

create or replace function public.my_account_messages(p_conversation uuid, p_before_at timestamptz default null, p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null or not exists (select 1 from public.account_conversations
                                        where id = p_conversation and auth.uid() in (user_a, user_b)) then
    raise exception 'conversation unavailable';
  end if;
  if (p_before_at is null) <> (p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(x order by x.created_at desc, x.id desc) from (
    select m.id, m.body, m.created_at, m.author_id = auth.uid() as is_mine,
           public.account_display_name(m.author_id) as author_name,
           m.read_at, m.no_forward, m.forwarded_from, m.notice
      from public.account_messages m
     where m.conversation_id = p_conversation
       and (p_before_at is null or (m.created_at, m.id) < (p_before_at, p_before_id))
     order by m.created_at desc, m.id desc limit 50) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_account_messages(uuid, timestamptz, uuid) from public, anon;
grant execute on function public.my_account_messages(uuid, timestamptz, uuid) to authenticated;

-- ── one inbox, every context on this server ─────────────────────────

create or replace function public.my_inbox()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  return coalesce((select jsonb_agg(x order by x.last_at desc nulls last) from (
    select * from (
      select 'space'::text as context_kind, c.id as context_id, c.workspace_id,
             w.name as workspace_name,
             case when c.kind = 'group' then coalesce(c.title, '')
                  else coalesce((select coalesce(nullif(p.display_name, ''), om.managed_name, '')
                                   from public.conversation_participants op
                                   join public.members om on om.id = op.member_id
                                   left join public.profiles p on p.id = om.user_id
                                  where op.conversation_id = c.id and op.member_id <> me.id
                                  limit 1), '') end as title,
             left(coalesce(last.body, ''), 64) as last_body,
             coalesce(last.created_at, c.last_message_at) as last_at,
             (select count(*)::int from public.member_notes n
               where n.conversation_id = c.id and n.from_member_id <> me.id
                 and n.created_at > coalesce(mine.last_read_at, '-infinity')) as unread,
             null::uuid as peer_id
        from public.members me
        join public.conversation_participants mine
          on mine.member_id = me.id and mine.left_at is null and mine.archived_at is null
        join public.conversations c on c.id = mine.conversation_id
        join public.workspaces w on w.id = c.workspace_id
        left join lateral (
          select n.body, n.created_at from public.member_notes n
           where n.conversation_id = c.id order by n.created_at desc limit 1) last on true
       where me.user_id = auth.uid() and me.status = 'active'
         and public.feature_effective(c.workspace_id, 'memberNotifications')
      union all
      select 'account', c.id, null::uuid, null::text,
             public.account_display_name(case when c.user_a = auth.uid() then c.user_b else c.user_a end),
             left(coalesce(last.body, ''), 64),
             coalesce(last.created_at, c.updated_at),
             (select count(*)::int from public.account_messages m
               where m.conversation_id = c.id and m.read_at is null
                 and m.author_id is distinct from auth.uid()),
             case when c.user_a = auth.uid() then c.user_b else c.user_a end
        from public.account_conversations c
        left join lateral (
          select m.body, m.created_at from public.account_messages m
           where m.conversation_id = c.id order by m.created_at desc, m.id desc limit 1) last on true
       where auth.uid() in (c.user_a, c.user_b)
      union all
      select 'inquiry_out', i.id, i.workspace_id, w.name, w.name,
             left(coalesce(last.body, ''), 64),
             coalesce(last.created_at, i.last_message_at),
             (select count(*)::int from public.space_inquiry_messages q
               where q.inquiry_id = i.id and q.read_by_requester_at is null
                 and q.author_user_id is distinct from auth.uid()),
             null::uuid
        from public.space_inquiries i
        join public.workspaces w on w.id = i.workspace_id
        left join lateral (
          select q.body, q.created_at from public.space_inquiry_messages q
           where q.inquiry_id = i.id order by q.created_at desc, q.id desc limit 1) last on true
       where i.requester_user_id = auth.uid()
      union all
      select 'inquiry_in', i.id, i.workspace_id, w.name,
             public.account_display_name(i.requester_user_id),
             left(coalesce(last.body, ''), 64),
             coalesce(last.created_at, i.last_message_at),
             (select count(*)::int from public.space_inquiry_messages q
               where q.inquiry_id = i.id and q.read_by_hosts_at is null
                 and q.author_user_id is not distinct from i.requester_user_id),
             null::uuid
        from public.space_inquiries i
        join public.workspaces w on w.id = i.workspace_id
        left join lateral (
          select q.body, q.created_at from public.space_inquiry_messages q
           where q.inquiry_id = i.id order by q.created_at desc, q.id desc limit 1) last on true
       where public.inquiry_host(i.workspace_id, auth.uid())
         and public.feature_effective(i.workspace_id, 'spaceInquiries')
    ) ctx
    order by last_at desc nulls last
    limit 300) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_inbox() from public, anon;
grant execute on function public.my_inbox() to authenticated;

-- ── the subject-access export carries inquiries and events ──────────
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0316: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'space_inquiries', (select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb) from public.space_inquiries i where i.requester_user_id = auth.uid()),
    'space_inquiry_messages', (select coalesce(jsonb_agg(to_jsonb(q)), '[]'::jsonb) from public.space_inquiry_messages q where q.author_user_id = auth.uid()),
    'message_events', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) from public.message_events e where e.actor_user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(316);
