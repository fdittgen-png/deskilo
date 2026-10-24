-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one settings row and two readers. No table, no policy, no
-- grant on a table; `my_inbox`, `my_group_inbox` and
-- `my_conversation_flags` are not restated and keep answering old clients.
--
-- #2556 C1 -- the inbox read where each conversation lives. The one
-- `my_inbox` (0316, patched by 0324 and 0388) is factored into the two
-- roles of a split deployment:
--
--   my_account_inbox_v1(p_before_at, p_before_key)    -- at the personal home
--     my person-to-person conversations (accepted, or a request I sent,
--     as 0388 decided) and the account groups I am in now (0384). No
--     workspace or membership row is read: a group or a conversation
--     names no workspace here.
--   my_workspace_inbox_v1(p_before_at, p_before_key)  -- at a workspace host
--     my workspace conversations (active membership, memberNotifications
--     effective, archived ones too, each with the pin / mute / archive
--     flags 0386 keeps), the inquiries I wrote and the inquiries I host
--     (the 0324 class: service_existing). Each workspace row carries the
--     workspace's network reference. No account or group row.
--
-- The rows keep the shape `my_inbox` answers (the client's InboxEntry):
-- context_kind, context_id, workspace_id, workspace_name, title,
-- last_body, last_at, unread, peer_id, plus member_count for a group and
-- workspace_ref, pinned, muted, archived for a workspace conversation.
--
-- The answer names who answers: {schema_version, source_role
-- (personal_home | workspace_host), installation_id, items, next_cursor,
-- has_more}. An installation that does not play the role refuses
-- (0A000), so a workspace host can never answer as a personal home.
--
-- Keyset paging, newest first: (last_at desc, key desc), the key being
-- `context_kind:context_id` in byte order, so equal times still page in
-- one total order. The cursor is the last row's {before_at, before_key};
-- both or neither, and a key of this reader's kinds (22023). One more row
-- than the page tells has_more; no total is returned. The page size is
-- the platform setting `messaging.inbox_page_size` (1..100, default 50),
-- resolved once.
--
-- First-party native sessions only (mcp_require_native: no anonymous
-- caller, no delegated assistant, no identity-only upstream token); the
-- caller is auth.uid(), never a parameter; executable by authenticated
-- alone. Authorization reads participants, memberships, group
-- memberships and the hosts' roles; a profile is read only for a title.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('messaging.inbox_page_size', 'int', '50'::jsonb, 1, 100, 'rows', 'messaging', array['platform'], 'workspaceSettings', null, true, null, 'my_account_inbox_v1, my_workspace_inbox_v1 (#2556)', 'How many conversations one inbox source returns per page: the personal home its personal conversations and groups, a workspace server its workspace conversations and inquiries. A bound on one read, not on what the inbox holds.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.my_account_inbox_v1(
  p_before_at timestamptz default null,
  p_before_key text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_me uuid;
  v_size int;
  v_rows jsonb;
  v_more boolean;
  v_last jsonb;
begin
  perform public.mcp_require_native();
  v_me := auth.uid();
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.installation_identity i
                  where 'personal_home' = any (i.roles)) then
    raise exception 'this installation is no personal home' using errcode = '0A000';
  end if;
  if (p_before_at is null) <> (p_before_key is null) then
    raise exception 'a cursor is a time and a key, or nothing' using errcode = '22023';
  end if;
  if p_before_key is not null
     and p_before_key !~ '^(account|account_group):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'the cursor does not belong to this inbox' using errcode = '22023';
  end if;
  v_size := (public.setting_value(null::uuid, 'messaging.inbox_page_size') #>> '{}')::int;

  select coalesce(jsonb_agg(to_jsonb(x) - 'sort_key' order by x.last_at desc, x.sort_key collate "C" desc),
                  '[]'::jsonb)
    into v_rows
    from (select ctx.*
            from (select 'account'::text as context_kind, c.id as context_id,
                         null::uuid as workspace_id, null::text as workspace_name,
                         public.account_display_name(
                           case when c.user_a = v_me then c.user_b else c.user_a end) as title,
                         left(coalesce(last.body, ''), 64) as last_body,
                         coalesce(last.created_at, c.updated_at) as last_at,
                         (select count(*)::int from public.account_messages m
                           where m.conversation_id = c.id and m.read_at is null
                             and m.author_id is distinct from v_me) as unread,
                         case when c.user_a = v_me then c.user_b else c.user_a end as peer_id,
                         null::int as member_count,
                         'account:' || c.id::text as sort_key
                    from public.account_conversations c
                    left join lateral (
                      select m.body, m.created_at from public.account_messages m
                       where m.conversation_id = c.id
                       order by m.created_at desc, m.id desc limit 1) last on true
                   where v_me in (c.user_a, c.user_b)
                     and (c.request_state = 'accepted' or c.requested_by = v_me)
                  union all
                  select 'account_group', g.id, null::uuid, null::text, g.title,
                         left(coalesce(last.body, ''), 64),
                         coalesce(last.created_at, g.last_message_at),
                         (select count(*)::int from public.account_group_messages n
                           where n.group_id = g.id and n.author_id is distinct from v_me
                             and n.created_at > coalesce(me.last_read_at, me.joined_at)),
                         null::uuid,
                         (select count(*)::int from public.account_group_members o
                           where o.group_id = g.id and o.left_at is null),
                         'account_group:' || g.id::text
                    from public.account_group_members me
                    join public.account_groups g on g.id = me.group_id
                    left join lateral (
                      select n.body, n.created_at from public.account_group_messages n
                       where n.group_id = g.id
                       order by n.created_at desc, n.id desc limit 1) last on true
                   where me.user_id = v_me and me.left_at is null) ctx
           where p_before_at is null
              or ctx.last_at < p_before_at
              or (ctx.last_at = p_before_at and ctx.sort_key collate "C" < p_before_key collate "C")
           order by ctx.last_at desc, ctx.sort_key collate "C" desc
           limit v_size + 1) x;

  v_more := jsonb_array_length(v_rows) > v_size;
  if v_more then
    v_rows := v_rows - v_size;
    v_last := v_rows -> (v_size - 1);
  end if;
  return jsonb_build_object(
    'schema_version', 1,
    'source_role', 'personal_home',
    'installation_id', public.installation_id(),
    'items', v_rows,
    'next_cursor', case when v_more then jsonb_build_object(
      'before_at', v_last -> 'last_at',
      'before_key', (v_last ->> 'context_kind') || ':' || (v_last ->> 'context_id')) end,
    'has_more', v_more);
end;
$fn$;
revoke execute on function public.my_account_inbox_v1(timestamptz, text) from public, anon;
grant execute on function public.my_account_inbox_v1(timestamptz, text) to authenticated;

create or replace function public.my_workspace_inbox_v1(
  p_before_at timestamptz default null,
  p_before_key text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_me uuid;
  v_size int;
  v_rows jsonb;
  v_more boolean;
  v_last jsonb;
begin
  perform public.mcp_require_native();
  v_me := auth.uid();
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.installation_identity i
                  where 'workspace_host' = any (i.roles)) then
    raise exception 'this installation hosts no workspace' using errcode = '0A000';
  end if;
  if (p_before_at is null) <> (p_before_key is null) then
    raise exception 'a cursor is a time and a key, or nothing' using errcode = '22023';
  end if;
  if p_before_key is not null
     and p_before_key !~ '^(space|inquiry_out|inquiry_in):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'the cursor does not belong to this inbox' using errcode = '22023';
  end if;
  v_size := (public.setting_value(null::uuid, 'messaging.inbox_page_size') #>> '{}')::int;

  select coalesce(jsonb_agg(to_jsonb(x) - 'sort_key' order by x.last_at desc, x.sort_key collate "C" desc),
                  '[]'::jsonb)
    into v_rows
    from (select ctx.*
            from (select 'space'::text as context_kind, c.id as context_id, c.workspace_id,
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
                         null::uuid as peer_id,
                         w.network_id as workspace_ref,
                         (mine.pinned_at is not null) as pinned,
                         mine.muted as muted,
                         (mine.archived_at is not null) as archived,
                         'space:' || c.id::text as sort_key
                    from public.members me
                    join public.conversation_participants mine
                      on mine.member_id = me.id and mine.left_at is null
                    join public.conversations c on c.id = mine.conversation_id
                    join public.workspaces w on w.id = c.workspace_id
                    left join lateral (
                      select n.body, n.created_at from public.member_notes n
                       where n.conversation_id = c.id
                       order by n.created_at desc, n.id desc limit 1) last on true
                   where me.user_id = v_me and me.status = 'active'
                     and public.feature_effective(c.workspace_id, 'memberNotifications')
                  union all
                  select 'inquiry_out', i.id, i.workspace_id, w.name, w.name,
                         left(coalesce(last.body, ''), 64),
                         coalesce(last.created_at, i.last_message_at),
                         (select count(*)::int from public.space_inquiry_messages q
                           where q.inquiry_id = i.id and q.read_by_requester_at is null
                             and q.author_user_id is distinct from v_me),
                         null::uuid, w.network_id, null::boolean, null::boolean, null::boolean,
                         'inquiry_out:' || i.id::text
                    from public.space_inquiries i
                    join public.workspaces w on w.id = i.workspace_id
                    left join lateral (
                      select q.body, q.created_at from public.space_inquiry_messages q
                       where q.inquiry_id = i.id
                       order by q.created_at desc, q.id desc limit 1) last on true
                   where i.requester_user_id = v_me
                  union all
                  select 'inquiry_in', i.id, i.workspace_id, w.name,
                         public.account_display_name(i.requester_user_id),
                         left(coalesce(last.body, ''), 64),
                         coalesce(last.created_at, i.last_message_at),
                         (select count(*)::int from public.space_inquiry_messages q
                           where q.inquiry_id = i.id and q.read_by_hosts_at is null
                             and q.author_user_id is not distinct from i.requester_user_id),
                         null::uuid, w.network_id, null::boolean, null::boolean, null::boolean,
                         'inquiry_in:' || i.id::text
                    from public.space_inquiries i
                    join public.workspaces w on w.id = i.workspace_id
                    left join lateral (
                      select q.body, q.created_at from public.space_inquiry_messages q
                       where q.inquiry_id = i.id
                       order by q.created_at desc, q.id desc limit 1) last on true
                   where public.inquiry_host(i.workspace_id, v_me)
                     and public.feature_operation_allowed(i.workspace_id, 'spaceInquiries', 'service_existing')) ctx
           where p_before_at is null
              or ctx.last_at < p_before_at
              or (ctx.last_at = p_before_at and ctx.sort_key collate "C" < p_before_key collate "C")
           order by ctx.last_at desc, ctx.sort_key collate "C" desc
           limit v_size + 1) x;

  v_more := jsonb_array_length(v_rows) > v_size;
  if v_more then
    v_rows := v_rows - v_size;
    v_last := v_rows -> (v_size - 1);
  end if;
  return jsonb_build_object(
    'schema_version', 1,
    'source_role', 'workspace_host',
    'installation_id', public.installation_id(),
    'items', v_rows,
    'next_cursor', case when v_more then jsonb_build_object(
      'before_at', v_last -> 'last_at',
      'before_key', (v_last ->> 'context_kind') || ':' || (v_last ->> 'context_id')) end,
    'has_more', v_more);
end;
$fn$;
revoke execute on function public.my_workspace_inbox_v1(timestamptz, text) from public, anon;
grant execute on function public.my_workspace_inbox_v1(timestamptz, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
