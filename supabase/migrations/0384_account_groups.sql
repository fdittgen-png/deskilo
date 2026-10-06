-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0384 — groups of PEOPLE, not of one workspace.
--
-- A workspace group (0125) lives inside one workspace and its members are
-- that workspace's. An ACCOUNT group is made of accounts: its members may
-- share one workspace, several, or none. Who may be put in one is each
-- person's own choice — an invitee must be reachable by the creator
-- (`account_field_visible_to(invitee, 'reachability', creator)`, the rule a
-- first message follows). What a group may CARRY follows who is in it (0381):
-- references only to a workspace every member belongs to; text, emoji,
-- quotes and forwarding always.
--
--   * `account_groups`: title, description, announcement-only;
--   * `account_group_members`: role, read watermark, `left_at`;
--   * `account_group_messages`: the words, `edited_at`, forward lock,
--     forwarded origin, system notices;
--   * functions only — no client access to any table;
--   * the shared message plumbing learns the new kind `group_message`
--     (source, forward, lock, reactions, stars, edits).

create table public.account_groups (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 60),
  description text not null default '' check (char_length(description) <= 500),
  announce_only boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
select public.ensure_system_columns('account_groups');
alter table public.account_groups enable row level security;
revoke all on public.account_groups from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_groups as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table public.account_group_members (
  group_id uuid not null references public.account_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_admin boolean not null default false,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_at timestamptz,
  added_by uuid references auth.users(id) on delete set null,
  primary key (group_id, user_id)
);
select public.ensure_system_columns('account_group_members');
alter table public.account_group_members enable row level security;
revoke all on public.account_group_members from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_group_members as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index account_group_members_user_idx on public.account_group_members (user_id) where left_at is null;

create table public.account_group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.account_groups(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  no_forward boolean not null default false,
  forwarded_from jsonb,
  notice jsonb
);
select public.ensure_system_columns('account_group_messages');
alter table public.account_group_messages enable row level security;
revoke all on public.account_group_messages from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_group_messages as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index account_group_messages_group_idx
  on public.account_group_messages (group_id, created_at desc, id desc);

-- The shared tables learn the new message kind.
alter table public.message_events drop constraint if exists message_events_message_kind_check;
alter table public.message_events add constraint message_events_message_kind_check
  check (message_kind in ('member_note', 'account_message', 'inquiry_message', 'group_message'));
alter table public.message_reactions drop constraint if exists message_reactions_message_kind_check;
alter table public.message_reactions add constraint message_reactions_message_kind_check
  check (message_kind in ('member_note', 'account_message', 'inquiry_message', 'group_message'));
alter table public.message_stars drop constraint if exists message_stars_message_kind_check;
alter table public.message_stars add constraint message_stars_message_kind_check
  check (message_kind in ('member_note', 'account_message', 'inquiry_message', 'group_message'));

-- ── helpers ─────────────────────────────────────────────────────────

create or replace function public.account_group_member(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (select 1 from public.account_group_members m
                  where m.group_id = p_group and m.user_id = auth.uid() and m.left_at is null);
$fn$;

create or replace function public.account_group_admin(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (select 1 from public.account_group_members m
                  where m.group_id = p_group and m.user_id = auth.uid()
                    and m.left_at is null and m.is_admin);
$fn$;

-- References a group carries must point at a workspace every member belongs to.
create or replace function public.account_group_messages_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_users uuid[];
begin
  if new.notice is null and new.author_id is not null
     and exists (select 1 from public.account_groups g where g.id = new.group_id and g.announce_only)
     and not exists (select 1 from public.account_group_members m
                      where m.group_id = new.group_id and m.user_id = new.author_id
                        and m.is_admin and m.left_at is null) then
    raise exception 'only admins post in this group';
  end if;
  if new.body is null or position('[' in new.body) = 0 then return new; end if;
  select coalesce(array_agg(user_id), '{}') into v_users
    from public.account_group_members where group_id = new.group_id and left_at is null;
  if not public.message_refs_allowed(new.body, v_users) then
    raise exception 'references are only shared with members of the same workspace';
  end if;
  return new;
end;
$fn$;
create trigger account_group_messages_guard before insert or update of body on public.account_group_messages
  for each row execute function public.account_group_messages_guard();

-- ── the group ───────────────────────────────────────────────────────

create or replace function public.create_account_group(
  p_title text, p_users uuid[], p_expected_account uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
  v_user uuid;
  v_users uuid[];
begin
  perform public.mcp_require_native();
  if auth.uid() is null or p_expected_account is distinct from auth.uid() then
    raise exception 'account changed';
  end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 60 then
    raise exception 'invalid group name';
  end if;
  select coalesce(array_agg(distinct u), '{}') into v_users
    from unnest(coalesce(p_users, '{}')) x(u) where u is not null and u <> auth.uid();
  if cardinality(v_users) < 1 or cardinality(v_users) > 49 then
    raise exception 'a group needs between 2 and 50 people';
  end if;
  foreach v_user in array v_users loop
    if not public.account_field_visible_to(v_user, 'reachability', auth.uid()) then
      raise exception 'recipient unavailable';
    end if;
  end loop;
  if (select count(*) from public.account_groups
       where created_by = auth.uid() and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'group limit reached';
  end if;
  insert into public.account_groups (title, created_by) values (btrim(p_title), auth.uid())
    returning id into v_id;
  insert into public.account_group_members (group_id, user_id, is_admin, added_by)
    values (v_id, auth.uid(), true, auth.uid());
  insert into public.account_group_members (group_id, user_id, added_by)
    select v_id, u, auth.uid() from unnest(v_users) x(u);
  return v_id;
end;
$fn$;

create or replace function public.account_group_details(p_group uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $fn$
  select jsonb_build_object(
           'id', g.id, 'title', g.title, 'description', g.description,
           'announce_only', g.announce_only,
           'member_count', (select count(*) from public.account_group_members m
                             where m.group_id = g.id and m.left_at is null),
           'i_am_admin', public.account_group_admin(g.id))
    from public.account_groups g
   where g.id = p_group and public.account_group_member(g.id);
$fn$;

create or replace function public.account_group_members_of(p_group uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_member(p_group) then raise exception 'group unavailable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
            'user_id', m.user_id, 'name', public.account_display_name(m.user_id),
            'is_admin', m.is_admin, 'joined_at', m.joined_at)
          order by m.is_admin desc, m.joined_at)
          from public.account_group_members m
         where m.group_id = p_group and m.left_at is null), '[]'::jsonb);
end;
$fn$;

create or replace function public.add_account_group_member(p_group uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_admin(p_group) then
    raise exception 'only a group admin can change the group';
  end if;
  if (select count(*) from public.account_group_members
       where group_id = p_group and left_at is null) >= 50 then
    raise exception 'a group holds at most 50 people';
  end if;
  if not public.account_field_visible_to(p_user, 'reachability', auth.uid()) then
    raise exception 'recipient unavailable';
  end if;
  insert into public.account_group_members (group_id, user_id, added_by)
  values (p_group, p_user, auth.uid())
  on conflict (group_id, user_id) do update
    set left_at = null, joined_at = now(), is_admin = false, added_by = auth.uid(), last_read_at = null;
end;
$fn$;

create or replace function public.remove_account_group_member(p_group uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_admin(p_group) then
    raise exception 'only a group admin can change the group';
  end if;
  if p_user = auth.uid() then raise exception 'use leave to leave a group'; end if;
  update public.account_group_members set left_at = now()
   where group_id = p_group and user_id = p_user and left_at is null;
end;
$fn$;

create or replace function public.leave_account_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_was_admin boolean;
begin
  perform public.mcp_require_native();
  select is_admin into v_was_admin from public.account_group_members
   where group_id = p_group and user_id = auth.uid() and left_at is null;
  if v_was_admin is null then raise exception 'not in this group'; end if;
  update public.account_group_members set left_at = now()
   where group_id = p_group and user_id = auth.uid();
  if v_was_admin and not exists (select 1 from public.account_group_members
                                  where group_id = p_group and left_at is null and is_admin) then
    update public.account_group_members set is_admin = true
     where group_id = p_group and user_id = (
       select user_id from public.account_group_members
        where group_id = p_group and left_at is null order by joined_at limit 1);
  end if;
end;
$fn$;

create or replace function public.set_account_group_meta(
  p_group uuid, p_title text, p_description text, p_announce_only boolean)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_admin(p_group) then
    raise exception 'only a group admin can change the group';
  end if;
  update public.account_groups
     set title = coalesce(nullif(btrim(coalesce(p_title, '')), ''), title),
         description = left(btrim(coalesce(p_description, description)), 500),
         announce_only = coalesce(p_announce_only, announce_only)
   where id = p_group;
end;
$fn$;

create or replace function public.set_account_group_admin(p_group uuid, p_user uuid, p_admin boolean)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_admin(p_group) then
    raise exception 'only a group admin can change the group';
  end if;
  if not exists (select 1 from public.account_group_members
                  where group_id = p_group and user_id = p_user and left_at is null) then
    raise exception 'not in this group';
  end if;
  if not p_admin and not exists (select 1 from public.account_group_members
                                  where group_id = p_group and left_at is null and is_admin
                                    and user_id <> p_user) then
    raise exception 'a group needs at least one admin';
  end if;
  update public.account_group_members set is_admin = p_admin
   where group_id = p_group and user_id = p_user;
end;
$fn$;

-- ── messages ────────────────────────────────────────────────────────

create or replace function public.send_account_group_message(
  p_group uuid, p_body text, p_expected_account uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
begin
  perform public.mcp_require_native();
  if auth.uid() is null or p_expected_account is distinct from auth.uid() then
    raise exception 'account changed';
  end if;
  if not public.account_group_member(p_group) then raise exception 'not in this group'; end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'invalid message';
  end if;
  if (select count(*) from public.account_group_messages
       where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.account_group_messages (group_id, author_id, body)
  values (p_group, auth.uid(), btrim(p_body)) returning id into v_id;
  update public.account_groups set last_message_at = now() where id = p_group;
  return v_id;
end;
$fn$;

create or replace function public.my_account_group_messages(
  p_group uuid, p_before_at timestamptz default null, p_before_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if not public.account_group_member(p_group) then raise exception 'group unavailable'; end if;
  if (p_before_at is null) <> (p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(x order by x.created_at desc, x.id desc) from (
    select m.id, m.body, m.created_at, m.author_id = auth.uid() as is_mine,
           public.account_display_name(m.author_id) as author_name,
           null::timestamptz as read_at, m.no_forward, m.forwarded_from, m.notice
      from public.account_group_messages m
     where m.group_id = p_group
       and (p_before_at is null or (m.created_at, m.id) < (p_before_at, p_before_id))
     order by m.created_at desc, m.id desc limit 50) x), '[]'::jsonb);
end;
$fn$;

create or replace function public.mark_account_group_read(p_group uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  update public.account_group_members set last_read_at = now()
   where group_id = p_group and user_id = auth.uid() and left_at is null;
end;
$fn$;

create or replace function public.delete_account_group_message(p_message uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_group uuid;
begin
  perform public.mcp_require_native();
  select group_id into v_group from public.account_group_messages
   where id = p_message and author_id = auth.uid();
  if v_group is null or not public.account_group_member(v_group) then
    raise exception 'only the author can delete a message';
  end if;
  delete from public.account_group_messages where id = p_message;
  insert into public.message_events (message_kind, message_id, event, actor_user_id, detail)
  values ('group_message', p_message, 'deleted', auth.uid(),
          jsonb_build_object('context_kind', 'account_group', 'context_id', v_group));
end;
$fn$;

-- Who a message of mine reached, in a group.
create or replace function public.account_group_message_reach(p_message uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  m public.account_group_messages;
begin
  perform public.mcp_require_native();
  select * into m from public.account_group_messages where id = p_message;
  if m.id is null or m.author_id is distinct from auth.uid() then
    raise exception 'only the author sees who a message reached';
  end if;
  return jsonb_build_object(
    'sent_at', m.created_at,
    'readers', coalesce((select jsonb_agg(jsonb_build_object(
                'member_id', x.user_id, 'name', public.account_display_name(x.user_id),
                'read_at', x.last_read_at) order by x.last_read_at)
              from public.account_group_members x
             where x.group_id = m.group_id and x.left_at is null and x.user_id <> m.author_id
               and x.last_read_at >= m.created_at), '[]'::jsonb),
    'pending', coalesce((select jsonb_agg(jsonb_build_object(
                'member_id', x.user_id, 'name', public.account_display_name(x.user_id)))
              from public.account_group_members x
             where x.group_id = m.group_id and x.left_at is null and x.user_id <> m.author_id
               and (x.last_read_at is null or x.last_read_at < m.created_at)), '[]'::jsonb));
end;
$fn$;

-- The inbox rows of my groups, in the shape `my_inbox` answers.
create or replace function public.my_group_inbox()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return coalesce((select jsonb_agg(x order by x.last_at desc nulls last) from (
    select 'account_group'::text as context_kind, g.id as context_id,
           null::uuid as workspace_id, null::text as workspace_name,
           g.title as title,
           left(coalesce(last.body, ''), 64) as last_body,
           coalesce(last.created_at, g.last_message_at) as last_at,
           (select count(*)::int from public.account_group_messages n
             where n.group_id = g.id and n.author_id is distinct from auth.uid()
               and n.created_at > coalesce(me.last_read_at, me.joined_at)) as unread,
           null::uuid as peer_id,
           (select count(*)::int from public.account_group_members c
             where c.group_id = g.id and c.left_at is null) as member_count
      from public.account_group_members me
      join public.account_groups g on g.id = me.group_id
      left join lateral (
        select n.body, n.created_at from public.account_group_messages n
         where n.group_id = g.id order by n.created_at desc, n.id desc limit 1) last on true
     where me.user_id = auth.uid() and me.left_at is null
     limit 200) x), '[]'::jsonb);
end;
$fn$;

-- ── the shared plumbing learns `group_message` ───────────────────────

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

do $patch$
declare
  v_def text;
  v_next text;
begin
  -- message_source: a message of a group
  v_def := pg_get_functiondef('public.message_source(text, uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $a$  elsif p_kind = 'inquiry_message' then$a$,
    $a$  elsif p_kind = 'group_message' then
    select jsonb_build_object(
             'workspace_id', null,
             'author_user_id', q.author_id,
             'author_name', public.account_display_name(q.author_id),
             'body', q.body, 'sent_at', q.created_at,
             'no_forward', q.no_forward, 'is_notice', q.notice is not null,
             'forwarded_from', q.forwarded_from,
             'context_kind', 'account_group', 'family', 'group',
             'context_id', q.group_id, 'context_label', g.title,
             'read_at', null)
      into v
      from public.account_group_messages q
      join public.account_groups g on g.id = q.group_id
     where q.id = p_message_id and public.account_group_member(q.group_id);
  elsif p_kind = 'inquiry_message' then$a$);
  if v_next is null then raise exception '0384: message_source anchor missing'; end if;
  execute v_next;

  -- forward_message: into a group
  v_def := pg_get_functiondef('public.forward_message(text, uuid, text, uuid, uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $a$  elsif p_target_kind = 'inquiry' then$a$,
    $a$  elsif p_target_kind = 'account_group' then
    if not public.account_group_member(p_target_id) then
      raise exception 'conversation unavailable';
    end if;
    insert into public.account_group_messages (group_id, author_id, body, forwarded_from)
    values (p_target_id, auth.uid(), v_src->>'body', v_from)
    returning id into v_new;
    update public.account_groups set last_message_at = now() where id = p_target_id;
    select g.title into v_label from public.account_groups g where g.id = p_target_id;
  elsif p_target_kind = 'inquiry' then$a$);
  if v_next is null then raise exception '0384: forward_message anchor missing'; end if;
  execute v_next;

  -- set_message_forward_lock: a group message
  v_def := pg_get_functiondef('public.set_message_forward_lock(text, uuid, boolean)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $a$  else
    update public.space_inquiry_messages set no_forward = p_locked where id = p_message_id;$a$,
    $a$  elsif p_kind = 'group_message' then
    update public.account_group_messages set no_forward = p_locked where id = p_message_id;
  else
    update public.space_inquiry_messages set no_forward = p_locked where id = p_message_id;$a$);
  if v_next is null then raise exception '0384: set_message_forward_lock anchor missing'; end if;
  execute v_next;
end
$patch$;

-- 0382's own functions, with the fourth kind.
create or replace function public.react_to_message(p_kind text, p_message_id uuid, p_emoji text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_current text;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('member_note', 'account_message', 'inquiry_message', 'group_message') then
    raise exception 'unknown message kind';
  end if;
  if public.message_source(p_kind, p_message_id) is null then
    raise exception 'message unavailable';
  end if;
  if (select count(*) from public.message_reactions
       where user_id = auth.uid() and created_at > now() - interval '1 minute') >= 60 then
    raise exception 'message limit reached';
  end if;
  select emoji into v_current from public.message_reactions
   where message_kind = p_kind and message_id = p_message_id and user_id = auth.uid();
  if p_emoji is null or btrim(p_emoji) = '' or v_current = p_emoji then
    delete from public.message_reactions
     where message_kind = p_kind and message_id = p_message_id and user_id = auth.uid();
    return;
  end if;
  insert into public.message_reactions (message_kind, message_id, user_id, emoji)
  values (p_kind, p_message_id, auth.uid(), p_emoji)
  on conflict (message_kind, message_id, user_id) do update
    set emoji = excluded.emoji, created_at = now();
end;
$fn$;

create or replace function public.toggle_message_star(p_kind text, p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('member_note', 'account_message', 'inquiry_message', 'group_message') then
    raise exception 'unknown message kind';
  end if;
  if public.message_source(p_kind, p_message_id) is null then
    raise exception 'message unavailable';
  end if;
  if exists (select 1 from public.message_stars
              where message_kind = p_kind and message_id = p_message_id and user_id = auth.uid()) then
    delete from public.message_stars
     where message_kind = p_kind and message_id = p_message_id and user_id = auth.uid();
    return false;
  end if;
  insert into public.message_stars (message_kind, message_id, user_id)
  values (p_kind, p_message_id, auth.uid());
  return true;
end;
$fn$;

create or replace function public.edit_message(p_kind text, p_message_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_body text := btrim(coalesce(p_body, ''));
  v_done int;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if length(v_body) = 0 then raise exception 'empty message'; end if;
  if p_kind = 'member_note' then
    if length(v_body) > 500 then raise exception 'message too long'; end if;
    update public.member_notes n set body = v_body, edited_at = now()
     where n.id = p_message_id and n.notice is null
       and n.created_at > now() - interval '15 minutes'
       and exists (select 1 from public.members m
                    where m.id = n.from_member_id and m.user_id = auth.uid());
  elsif p_kind = 'account_message' then
    if length(v_body) > 4000 then raise exception 'message too long'; end if;
    update public.account_messages a set body = v_body, edited_at = now()
     where a.id = p_message_id and a.author_id = auth.uid() and a.notice is null
       and a.created_at > now() - interval '15 minutes';
  elsif p_kind = 'inquiry_message' then
    if length(v_body) > 4000 then raise exception 'message too long'; end if;
    update public.space_inquiry_messages q set body = v_body, edited_at = now()
     where q.id = p_message_id and q.author_user_id = auth.uid() and q.notice is null
       and q.created_at > now() - interval '15 minutes';
  elsif p_kind = 'group_message' then
    if length(v_body) > 4000 then raise exception 'message too long'; end if;
    update public.account_group_messages g set body = v_body, edited_at = now()
     where g.id = p_message_id and g.author_id = auth.uid() and g.notice is null
       and g.created_at > now() - interval '15 minutes'
       and public.account_group_member(g.group_id);
  else
    raise exception 'unknown message kind';
  end if;
  get diagnostics v_done = row_count;
  if v_done = 0 then raise exception 'this message can no longer be edited'; end if;
end;
$fn$;

create or replace function public.message_marks_in(p_context_kind text, p_context_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_kind text;
  v_ids uuid[];
  v_edited uuid[];
  v_none jsonb := jsonb_build_object('reactions', '[]'::jsonb, 'starred', '[]'::jsonb, 'edited', '[]'::jsonb);
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_context_kind = 'conversation' then
    v_kind := 'member_note';
    if not exists (
      select 1 from public.conversation_participants p
        join public.members m on m.id = p.member_id
       where p.conversation_id = p_context_id and m.user_id = auth.uid() and m.status = 'active'
    ) then return v_none; end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.member_notes where conversation_id = p_context_id;
  elsif p_context_kind = 'account_conversation' then
    v_kind := 'account_message';
    if not exists (select 1 from public.account_conversations c
                    where c.id = p_context_id and auth.uid() in (c.user_a, c.user_b)) then
      return v_none;
    end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.account_messages where conversation_id = p_context_id;
  elsif p_context_kind = 'account_group' then
    v_kind := 'group_message';
    if not public.account_group_member(p_context_id) then return v_none; end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.account_group_messages where group_id = p_context_id;
  elsif p_context_kind = 'inquiry' then
    v_kind := 'inquiry_message';
    if public.inquiry_role(p_context_id) is null then return v_none; end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.space_inquiry_messages where inquiry_id = p_context_id;
  else
    raise exception 'unknown context';
  end if;
  return jsonb_build_object(
    'reactions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'message_id', r.message_id, 'emoji', r.emoji,
               'count', r.cnt, 'mine', r.mine))
        from (
          select message_id, emoji, count(*) as cnt, bool_or(user_id = auth.uid()) as mine
            from public.message_reactions
           where message_kind = v_kind and message_id = any(v_ids)
           group by message_id, emoji
        ) r), '[]'::jsonb),
    'starred', coalesce((
      select jsonb_agg(message_id) from public.message_stars
       where message_kind = v_kind and message_id = any(v_ids) and user_id = auth.uid()), '[]'::jsonb),
    'edited', to_jsonb(v_edited));
end;
$fn$;

-- ── doors ───────────────────────────────────────────────────────────
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;
revoke execute on function public.react_to_message(text, uuid, text) from public, anon;
revoke execute on function public.toggle_message_star(text, uuid) from public, anon;
revoke execute on function public.edit_message(text, uuid, text) from public, anon;
revoke execute on function public.message_marks_in(text, uuid) from public, anon;
revoke execute on function public.account_group_member(uuid) from public, anon;
revoke execute on function public.account_group_admin(uuid) from public, anon;
revoke execute on function public.account_group_messages_guard() from public, anon;
revoke execute on function public.create_account_group(text, uuid[], uuid) from public, anon;
revoke execute on function public.account_group_details(uuid) from public, anon;
revoke execute on function public.account_group_members_of(uuid) from public, anon;
revoke execute on function public.add_account_group_member(uuid, uuid) from public, anon;
revoke execute on function public.remove_account_group_member(uuid, uuid) from public, anon;
revoke execute on function public.leave_account_group(uuid) from public, anon;
revoke execute on function public.set_account_group_meta(uuid, text, text, boolean) from public, anon;
revoke execute on function public.set_account_group_admin(uuid, uuid, boolean) from public, anon;
revoke execute on function public.send_account_group_message(uuid, text, uuid) from public, anon;
revoke execute on function public.my_account_group_messages(uuid, timestamptz, uuid) from public, anon;
revoke execute on function public.mark_account_group_read(uuid) from public, anon;
revoke execute on function public.delete_account_group_message(uuid) from public, anon;
revoke execute on function public.account_group_message_reach(uuid) from public, anon;
revoke execute on function public.my_group_inbox() from public, anon;
grant execute on function public.create_account_group(text, uuid[], uuid) to authenticated;
grant execute on function public.account_group_details(uuid) to authenticated;
grant execute on function public.account_group_members_of(uuid) to authenticated;
grant execute on function public.add_account_group_member(uuid, uuid) to authenticated;
grant execute on function public.remove_account_group_member(uuid, uuid) to authenticated;
grant execute on function public.leave_account_group(uuid) to authenticated;
grant execute on function public.set_account_group_meta(uuid, text, text, boolean) to authenticated;
grant execute on function public.set_account_group_admin(uuid, uuid, boolean) to authenticated;
grant execute on function public.send_account_group_message(uuid, text, uuid) to authenticated;
grant execute on function public.my_account_group_messages(uuid, timestamptz, uuid) to authenticated;
grant execute on function public.mark_account_group_read(uuid) to authenticated;
grant execute on function public.delete_account_group_message(uuid) to authenticated;
grant execute on function public.account_group_message_reach(uuid) to authenticated;
grant execute on function public.my_group_inbox() to authenticated;


-- Where the references of a group may point: the workspaces EVERY member of
-- the group belongs to (the caller included).
create or replace function public.shared_workspaces_of_group(p_group uuid)
returns table (id uuid, name text)
language sql
stable
security definer
set search_path = public
as $fn$
  select w.id, w.name
    from public.workspaces w
   where public.account_group_member(p_group)
     and not exists (
       select 1 from public.account_group_members g
        where g.group_id = p_group and g.left_at is null
          and not exists (select 1 from public.members m
                           where m.workspace_id = w.id and m.user_id = g.user_id
                             and m.status = 'active'))
   order by w.name;
$fn$;
revoke execute on function public.shared_workspaces_of_group(uuid) from public, anon;
grant execute on function public.shared_workspaces_of_group(uuid) to authenticated;

-- The subject-access export carries my groups, memberships and messages.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0384: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'account_group_members', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb) from public.account_group_members m where m.user_id = auth.uid()),
    'account_group_messages', (select coalesce(jsonb_agg(to_jsonb(g)), '[]'::jsonb) from public.account_group_messages g where g.author_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(384);
