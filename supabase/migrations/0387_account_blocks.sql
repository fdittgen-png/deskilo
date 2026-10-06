-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0387 -- #2211: a block list. A person blocks another account; from then on
-- neither can see the other's fields (identity, about, contact, presence),
-- reach the other, or start or continue an account conversation. The refusal
-- is the same words an unreachable person gets ("recipient unavailable"), so
-- a block is not announced. Groups and workspace conversations are NOT
-- touched: a space's own rules govern what happens inside a space.
--
-- Enforcement sits in the two functions every read and every first message
-- already go through: account_field_visible_to (so visible_account, the
-- account search and the projections follow) and send_account_message.

create table public.account_blocks (
  blocker uuid not null references auth.users(id) on delete cascade,
  blocked uuid not null references auth.users(id) on delete cascade,
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
select public.ensure_system_columns('account_blocks');
alter table public.account_blocks enable row level security;
revoke all on public.account_blocks from public, anon, authenticated;
create policy mcp_delegated_deny on public.account_blocks as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.account_blocked_between(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.account_blocks
     where (blocker = p_a and blocked = p_b) or (blocker = p_b and blocked = p_a));
$$;
revoke execute on function public.account_blocked_between(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.block_account(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_user is null or p_user = auth.uid()
     or not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'invalid account';
  end if;
  insert into public.account_blocks (blocker, blocked) values (auth.uid(), p_user)
  on conflict do nothing;
end;
$$;
revoke execute on function public.block_account(uuid) from public, anon;
grant execute on function public.block_account(uuid) to authenticated;

create or replace function public.unblock_account(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.account_blocks where blocker = auth.uid() and blocked = p_user;
end;
$$;
revoke execute on function public.unblock_account(uuid) from public, anon;
grant execute on function public.unblock_account(uuid) to authenticated;

-- The accounts I blocked, with the name I knew them by.
create or replace function public.my_blocks()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  return coalesce((select jsonb_agg(jsonb_build_object(
            'user_id', b.blocked,
            'name', public.account_display_name(b.blocked),
            'blocked_at', b.created_datetime) order by b.created_datetime desc)
          from public.account_blocks b where b.blocker = auth.uid()), '[]'::jsonb);
end;
$$;
revoke execute on function public.my_blocks() from public, anon;
grant execute on function public.my_blocks() to authenticated;

create or replace function public.account_field_visible_to(
  p_owner uuid, p_field text, p_viewer uuid
) returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_audience text;
begin
  if p_owner is null or p_viewer is null then return false; end if;
  if p_owner = p_viewer then return true; end if;
  -- #2211: a block, either way, removes every field and the reachability.
  if public.account_blocked_between(p_owner, p_viewer) then return false; end if;
  v_audience := public.account_audience_of(p_owner, p_field);
  if v_audience = 'signed_in' then return true; end if;
  if v_audience = 'my_spaces' then
    return exists (
      select 1 from public.members a
        join public.members b on b.workspace_id = a.workspace_id
       where a.user_id = p_owner and b.user_id = p_viewer
         and a.status in ('active', 'paused')
         and b.status in ('active', 'paused'));
  end if;
  if v_audience = 'chosen_spaces' then
    return exists (
      select 1 from public.account_field_audience_spaces s
        join public.members a on a.workspace_id = s.workspace_id
         and a.user_id = p_owner and a.status in ('active', 'paused')
        join public.members b on b.workspace_id = s.workspace_id
         and b.user_id = p_viewer and b.status in ('active', 'paused')
       where s.user_id = p_owner and s.field = p_field);
  end if;
  return false;
end;
$$;

create or replace function public.send_account_message(p_recipient uuid, p_body text, p_expected_account uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_a uuid; v_b uuid;
begin
  perform public.mcp_require_native();
  if auth.uid() is null or p_expected_account is distinct from auth.uid() then raise exception 'account changed'; end if;
  if p_recipient is null or p_recipient = auth.uid() or p_body is null
     or length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid message'; end if;
  -- #2211: a block refuses with the SAME words as an unreachable person, so
  -- the blocked one learns nothing more than they already could.
  if public.account_blocked_between(auth.uid(), p_recipient) then
    raise exception 'recipient unavailable';
  end if;
  v_a := least(auth.uid(), p_recipient); v_b := greatest(auth.uid(), p_recipient);
  perform pg_advisory_xact_lock(hashtextextended(v_a::text || v_b::text, 1791));
  select id into v_id from public.account_conversations where user_a = v_a and user_b = v_b;
  if v_id is null then
    -- #1823: the recipient's reachability audience decides who may START.
    if not public.account_field_visible_to(p_recipient, 'reachability', auth.uid()) then
      raise exception 'recipient unavailable';
    end if;
    insert into public.account_conversations (user_a, user_b) values (v_a, v_b) returning id into v_id;
  end if;
  -- Bounded native inbox traffic. No public listing or messaging role grants.
  if (select count(*) from public.account_messages
       where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'message limit reached';
  end if;
  insert into public.account_messages (conversation_id, author_id, body) values (v_id, auth.uid(), btrim(p_body));
  update public.account_conversations set updated_at = now() where id = v_id;
  return v_id;
end;
$$;

create or replace function public.visible_account(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_fields text[];
begin
  perform public.mcp_require_native();
  if p_user_id is null then raise exception 'account unavailable'; end if;
  select coalesce(array_agg(f), '{}') into v_fields
    from unnest(array['identity', 'about', 'contact_channels', 'presence']) f
   where public.account_field_visible_to(p_user_id, f, auth.uid());
  return public.account_projection(p_user_id, v_fields)
    || jsonb_build_object('can_message',
         p_user_id <> auth.uid()
         and not public.account_blocked_between(auth.uid(), p_user_id)
         and (public.account_field_visible_to(p_user_id, 'reachability', auth.uid())
              or exists (select 1 from public.account_conversations c
                          where c.user_a = least(auth.uid(), p_user_id)
                            and c.user_b = greatest(auth.uid(), p_user_id))));
end;
$$;

revoke execute on function public.account_field_visible_to(uuid, text, uuid)
  from public, anon, authenticated;
revoke execute on function public.send_account_message(uuid, text, uuid) from public, anon;
grant execute on function public.send_account_message(uuid, text, uuid) to authenticated;
revoke execute on function public.visible_account(uuid) from public, anon;
grant execute on function public.visible_account(uuid) to authenticated;

-- The subject-access export carries the blocks I set.
do $export$
declare
  v_def text;
  v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def) = 0 then raise exception '0387: export anchor missing'; end if;
  execute replace(v_def, v_anchor, $a$    'exported_at', now(),
    'account_blocks', (select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb) from public.account_blocks k where k.blocker = auth.uid()),$a$);
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(387);
