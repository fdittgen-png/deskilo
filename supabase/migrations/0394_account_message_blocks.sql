-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #2211: enforce personal blocks at the shared insert boundary, including
-- forwarded messages and context notices. Keep historical reads and the
-- pending/ignored request rules; workspace and group messaging are unchanged.
create or replace function public.account_message_request_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_c public.account_conversations;
begin
  select * into v_c from public.account_conversations where id = new.conversation_id;
  if public.account_blocked_between(v_c.user_a, v_c.user_b) then
    raise exception 'recipient unavailable';
  end if;
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

select public.set_deskilo_schema_version(394);
