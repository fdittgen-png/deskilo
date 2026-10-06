-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0386 -- #2210/#2216: the Me inbox shows and sets the server-side
-- preferences of a workspace conversation (pin, mute, archive), so they
-- follow the person across devices and silence what they say they silence.
--
-- `my_inbox` leaves out a conversation I archived (0316), so an archived
-- thread had no home in the messenger. `my_conversation_flags` answers MY
-- workspace conversations that carry a flag (pinned, muted or archived), in
-- the row shape of `my_inbox` plus the three flags; the client lays them over
-- the inbox and lists the archived ones under the Archived filter. Setting a
-- flag stays `set_conversation_prefs` (0146); marking unread stays
-- `mark_conversation_unread`. Read-only; nothing else changes.

create or replace function public.my_conversation_flags()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  return coalesce((select jsonb_agg(x order by x.last_at desc nulls last) from (
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
           null::uuid as peer_id,
           (mine.pinned_at is not null) as pinned,
           mine.muted as muted,
           (mine.archived_at is not null) as archived
      from public.members me
      join public.conversation_participants mine
        on mine.member_id = me.id and mine.left_at is null
       and (mine.pinned_at is not null or mine.muted or mine.archived_at is not null)
      join public.conversations c on c.id = mine.conversation_id
      join public.workspaces w on w.id = c.workspace_id
      left join lateral (
        select n.body, n.created_at from public.member_notes n
         where n.conversation_id = c.id order by n.created_at desc limit 1) last on true
     where me.user_id = auth.uid() and me.status = 'active'
       and public.feature_effective(c.workspace_id, 'memberNotifications')
  ) x), '[]'::jsonb);
end;
$$;

revoke execute on function public.my_conversation_flags() from public, anon;
grant execute on function public.my_conversation_flags() to authenticated;

select public.set_deskilo_schema_version(386);
