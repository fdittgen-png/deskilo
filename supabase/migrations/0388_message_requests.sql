-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0388 -- #2211: message requests. A first message from someone outside my
-- reachability is no longer refused: it is HELD as a request I accept, ignore
-- or block. Only "Only me" still refuses outright. Until accepted the
-- requester may send ONE message; my reply is an acceptance. An ignored
-- request stays invisible to me and looks like any pending one to the sender,
-- so nothing is announced. Existing conversations stay accepted.
--
-- The one-message bound lives in a trigger on account_messages, because
-- several paths (send_account_message, the context sender, a forward) insert
-- into it.

alter table public.account_conversations
  add column request_state text not null default 'accepted'
    check (request_state in ('pending', 'accepted', 'ignored')),
  add column requested_by uuid references auth.users(id) on delete set null;

create or replace function public.account_message_request_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_c public.account_conversations;
begin
  select * into v_c from public.account_conversations where id = new.conversation_id;
  if v_c.id is null or v_c.request_state = 'accepted' then return new; end if;
  if new.author_id is distinct from v_c.requested_by then
    -- the person asked answers: that accepts the request.
    update public.account_conversations set request_state = 'accepted'
     where id = v_c.id;
    return new;
  end if;
  if exists (select 1 from public.account_messages m
              where m.conversation_id = v_c.id and m.author_id = new.author_id) then
    raise exception 'request pending';
  end if;
  return new;
end;
$$;
revoke execute on function public.account_message_request_guard() from public, anon, authenticated;
create trigger account_messages_request_guard before insert on public.account_messages
  for each row execute function public.account_message_request_guard();

create or replace function public.send_account_message(p_recipient uuid, p_body text, p_expected_account uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_a uuid; v_b uuid; v_state text := 'accepted';
begin
  perform public.mcp_require_native();
  if auth.uid() is null or p_expected_account is distinct from auth.uid() then raise exception 'account changed'; end if;
  if p_recipient is null or p_recipient = auth.uid() or p_body is null
     or length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid message'; end if;
  if public.account_blocked_between(auth.uid(), p_recipient) then
    raise exception 'recipient unavailable';
  end if;
  v_a := least(auth.uid(), p_recipient); v_b := greatest(auth.uid(), p_recipient);
  perform pg_advisory_xact_lock(hashtextextended(v_a::text || v_b::text, 1791));
  select id into v_id from public.account_conversations where user_a = v_a and user_b = v_b;
  if v_id is null then
    if not public.account_field_visible_to(p_recipient, 'reachability', auth.uid()) then
      -- #2211: outside my reachability is a REQUEST, unless I said "only me".
      if public.account_audience_of(p_recipient, 'reachability') = 'nobody' then
        raise exception 'recipient unavailable';
      end if;
      if (select count(*) from public.account_conversations c
           where c.requested_by = auth.uid() and c.request_state <> 'accepted'
             and c.created_datetime > now() - interval '1 day') >= 10 then
        raise exception 'message limit reached';
      end if;
      v_state := 'pending';
    end if;
    insert into public.account_conversations (user_a, user_b, request_state, requested_by)
    values (v_a, v_b, v_state, case when v_state = 'pending' then auth.uid() end)
    returning id into v_id;
  end if;
  if (select count(*) from public.account_messages
       where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.account_messages (conversation_id, author_id, body) values (v_id, auth.uid(), btrim(p_body));
  update public.account_conversations set updated_at = now() where id = v_id;
  return v_id;
end;
$$;
revoke execute on function public.send_account_message(uuid, text, uuid) from public, anon;
grant execute on function public.send_account_message(uuid, text, uuid) to authenticated;

-- The requests waiting for me: who, and what they wrote.
create or replace function public.my_message_requests()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return coalesce((select jsonb_agg(x order by x.at desc) from (
    select c.id as conversation_id, c.requested_by as user_id,
           public.account_display_name(c.requested_by) as name,
           coalesce((select m.body from public.account_messages m
                      where m.conversation_id = c.id order by m.created_at, m.id limit 1), '') as body,
           c.updated_at as at
      from public.account_conversations c
     where auth.uid() in (c.user_a, c.user_b) and c.requested_by <> auth.uid()
       and c.request_state = 'pending'
       and not public.account_blocked_between(auth.uid(), c.requested_by)
     order by c.updated_at desc limit 50) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_message_requests() from public, anon;
grant execute on function public.my_message_requests() to authenticated;

create or replace function public.respond_to_message_request(p_conversation uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.account_conversations
     set request_state = case when p_accept then 'accepted' else 'ignored' end
   where id = p_conversation and auth.uid() in (user_a, user_b)
     and requested_by <> auth.uid() and request_state = 'pending';
  if not found then raise exception 'request unavailable'; end if;
end;
$$;
revoke execute on function public.respond_to_message_request(uuid, boolean) from public, anon;
grant execute on function public.respond_to_message_request(uuid, boolean) to authenticated;

-- A held request is not a conversation yet: the recipient's list leaves it out.
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
       and (c.request_state = 'accepted' or c.requested_by = auth.uid())
       and (p_before_at is null or (c.updated_at, c.id) < (p_before_at, p_before_id))
     order by c.updated_at desc, c.id desc limit 50) x), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_account_conversations(timestamptz, uuid) from public, anon;
grant execute on function public.my_account_conversations(timestamptz, uuid) to authenticated;

-- ... and so does the unified inbox (anchored patch of the account branch).
do $inbox$
declare
  v_def text;
  v_anchor text := $a$       where auth.uid() in (c.user_a, c.user_b)
      union all
      select 'inquiry_out'$a$;
begin
  v_def := pg_get_functiondef('public.my_inbox()'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0388: my_inbox anchor missing'; end if;
  -- The hosts' inquiry branch keeps the 0324 gate untouched; the newest patch
  -- of a classified function must name it, so it is asserted here.
  if position($g$public.feature_operation_allowed(i.workspace_id, 'spaceInquiries', 'service_existing')$g$
              in v_def) = 0 then
    raise exception '0388: my_inbox inquiry gate missing';
  end if;
  execute replace(v_def, v_anchor, $a$       where auth.uid() in (c.user_a, c.user_b)
         and (c.request_state = 'accepted' or c.requested_by = auth.uid())
      union all
      select 'inquiry_out'$a$);
end;
$inbox$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(388);
