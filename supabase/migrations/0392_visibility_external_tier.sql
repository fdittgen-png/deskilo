-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- Narrows only: contact channels or presence set to every signed-in person
-- become "my spaces"; nothing is widened, nothing deleted.
--
-- #2211 (4) — the external-workspace tier.
--
-- There is no server-to-server federation: a connected installation is
-- the app signed in to another server with that server's own account
-- (connected_installations.dart). So a person known only through another
-- workspace or a connected installation is, on the server that holds my
-- account, a signed-in person with no space in common — the matrix's
-- "V3 = via V4". What made that tier untrue was not a missing viewer
-- class but two holes this file closes:
--
--   * contact channels (WhatsApp, e-mail) and presence must never reach
--     beyond my spaces (MESSENGER_VISIBILITY.md §2), and nothing enforced
--     it: set_visibility accepted 'signed_in' for them. The write refuses
--     it now, and rows already that wide are narrowed to 'my_spaces';
--   * visible_account answered can_message for ANY conversation row, so a
--     request the person ignored, or one still pending from them, let the
--     other side keep writing as if accepted. Only an accepted
--     conversation counts now. A pending request already carries its one
--     message (0388's guard), and pending and ignored answer the same, so
--     the sender cannot tell that they were ignored.

-- Writes one audience; `available` follows reachability.
create or replace function public.write_account_audience(
  p_user uuid, p_field text, p_audience text, p_workspaces uuid[]
) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is null or p_user is distinct from auth.uid() then
    raise exception 'not authenticated';
  end if;
  if p_field in ('contact_channels', 'presence') and p_audience = 'signed_in' then
    raise exception 'this field never goes beyond your spaces';
  end if;
  insert into public.account_field_audience (user_id, field, audience)
  values (p_user, p_field, p_audience)
  on conflict (user_id, field) do update set audience = excluded.audience;
  delete from public.account_field_audience_spaces
   where user_id = p_user and field = p_field;
  if p_audience = 'chosen_spaces' then
    insert into public.account_field_audience_spaces (user_id, field, workspace_id)
    select distinct p_user, p_field, w from unnest(p_workspaces) w;
  end if;
  if p_field = 'reachability' then
    insert into public.account_contact_settings (user_id, available)
    values (p_user, p_audience = 'signed_in')
    on conflict (user_id) do update set available = excluded.available
     where public.account_contact_settings.available is distinct from excluded.available;
  end if;
end;
$$;
revoke execute on function public.write_account_audience(uuid, text, text, uuid[])
  from public, anon, authenticated;

update public.account_field_audience
   set audience = 'my_spaces'
 where field in ('contact_channels', 'presence') and audience = 'signed_in';

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
                            and c.user_b = greatest(auth.uid(), p_user_id)
                            and c.request_state = 'accepted')));
end;
$$;
revoke execute on function public.visible_account(uuid) from public, anon;
grant execute on function public.visible_account(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(392);
