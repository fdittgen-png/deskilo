-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0382 — what a chat does besides carrying words: react with an emoji, star a
-- message, correct a message you wrote.
--
--   * `message_reactions`: one emoji per person per message (tapping the same
--     one again takes it back; another replaces it), on all three message
--     tables, through `react_to_message`;
--   * `message_stars`: a person's own bookmarks, private to them;
--   * `edit_message`: the author corrects their own message within fifteen
--     minutes; the edit is stamped (`edited_at`) and passes the same
--     reference guard (0381) as a new message;
--   * `message_marks_in(context)`: everything a thread needs to draw — the
--     reactions with counts and mine, my stars, the edited ones — in one
--     read; `my_starred_messages()` lists my bookmarks across conversations.
-- Neither table has client access: the functions are the only door, and each
-- checks the caller may read the message (or the whole context).

alter table public.member_notes add column if not exists edited_at timestamptz;
alter table public.account_messages add column if not exists edited_at timestamptz;
alter table public.space_inquiry_messages add column if not exists edited_at timestamptz;

create table public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_kind text not null check (message_kind in
    ('member_note', 'account_message', 'inquiry_message')),
  message_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  unique (message_kind, message_id, user_id)
);
select public.ensure_system_columns('message_reactions');
alter table public.message_reactions enable row level security;
revoke all on public.message_reactions from public, anon, authenticated;
create policy mcp_delegated_deny on public.message_reactions as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index message_reactions_message_idx on public.message_reactions (message_kind, message_id);
create index message_reactions_user_idx on public.message_reactions (user_id);

create table public.message_stars (
  id uuid primary key default gen_random_uuid(),
  message_kind text not null check (message_kind in
    ('member_note', 'account_message', 'inquiry_message')),
  message_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (message_kind, message_id, user_id)
);
select public.ensure_system_columns('message_stars');
alter table public.message_stars enable row level security;
revoke all on public.message_stars from public, anon, authenticated;
create policy mcp_delegated_deny on public.message_stars as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index message_stars_user_idx on public.message_stars (user_id, created_at desc);

-- A reference guard also stands on a message that is EDITED.
drop trigger if exists member_notes_refs_guard on public.member_notes;
create trigger member_notes_refs_guard before insert or update of body on public.member_notes
  for each row execute function public.member_notes_refs_guard();
drop trigger if exists account_messages_refs_guard on public.account_messages;
create trigger account_messages_refs_guard before insert or update of body on public.account_messages
  for each row execute function public.account_messages_refs_guard();
drop trigger if exists inquiry_messages_refs_guard on public.space_inquiry_messages;
create trigger inquiry_messages_refs_guard before insert or update of body on public.space_inquiry_messages
  for each row execute function public.inquiry_messages_refs_guard();

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
  if p_kind not in ('member_note', 'account_message', 'inquiry_message') then
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
  if p_kind not in ('member_note', 'account_message', 'inquiry_message') then
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
  else
    raise exception 'unknown message kind';
  end if;
  get diagnostics v_done = row_count;
  if v_done = 0 then raise exception 'this message can no longer be edited'; end if;
end;
$fn$;

-- Everything a thread draws besides the words, in one read.
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
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_context_kind = 'conversation' then
    v_kind := 'member_note';
    if not exists (
      select 1 from public.conversation_participants p
        join public.members m on m.id = p.member_id
       where p.conversation_id = p_context_id and m.user_id = auth.uid() and m.status = 'active'
    ) then return jsonb_build_object('reactions', '[]'::jsonb, 'starred', '[]'::jsonb, 'edited', '[]'::jsonb); end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.member_notes where conversation_id = p_context_id;
  elsif p_context_kind = 'account_conversation' then
    v_kind := 'account_message';
    if not exists (select 1 from public.account_conversations c
                    where c.id = p_context_id and auth.uid() in (c.user_a, c.user_b)) then
      return jsonb_build_object('reactions', '[]'::jsonb, 'starred', '[]'::jsonb, 'edited', '[]'::jsonb);
    end if;
    select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where edited_at is not null), '{}')
      into v_ids, v_edited from public.account_messages where conversation_id = p_context_id;
  elsif p_context_kind = 'inquiry' then
    v_kind := 'inquiry_message';
    if public.inquiry_role(p_context_id) is null then
      return jsonb_build_object('reactions', '[]'::jsonb, 'starred', '[]'::jsonb, 'edited', '[]'::jsonb);
    end if;
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

create or replace function public.my_starred_messages()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return coalesce((
    select jsonb_agg(x order by x.starred_at desc) from (
      select s.message_kind, s.message_id, s.created_at as starred_at,
             src->>'body' as body, src->>'author_name' as author_name,
             src->>'sent_at' as sent_at, src->>'context_label' as context_label,
             src->>'context_kind' as context_kind, src->>'context_id' as context_id
        from public.message_stars s
        cross join lateral (select public.message_source(s.message_kind, s.message_id) as src) l
       where s.user_id = auth.uid() and l.src is not null
       order by s.created_at desc
       limit 200
    ) x), '[]'::jsonb);
end;
$fn$;

revoke execute on function public.react_to_message(text, uuid, text) from public, anon;
revoke execute on function public.toggle_message_star(text, uuid) from public, anon;
revoke execute on function public.edit_message(text, uuid, text) from public, anon;
revoke execute on function public.message_marks_in(text, uuid) from public, anon;
revoke execute on function public.my_starred_messages() from public, anon;
grant execute on function public.react_to_message(text, uuid, text) to authenticated;
grant execute on function public.toggle_message_star(text, uuid) to authenticated;
grant execute on function public.edit_message(text, uuid, text) to authenticated;
grant execute on function public.message_marks_in(text, uuid) to authenticated;
grant execute on function public.my_starred_messages() to authenticated;

-- The subject-access export carries my reactions and my stars.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0382: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'message_reactions', (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from public.message_reactions r where r.user_id = auth.uid()),
    'message_stars', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) from public.message_stars s where s.user_id = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(382);
