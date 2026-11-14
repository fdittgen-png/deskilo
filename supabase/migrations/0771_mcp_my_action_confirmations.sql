-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0771 (#3978) -- the person's own assistant requests, for the assistants
-- page: every request still waiting for them, and the ones answered since
-- the moment the app names. Each reads as mcp_get_action_confirmation reads
-- one (a waiting request past its time reads as expired), with when it was
-- asked. Only the person it is bound to, only from a session of the app:
-- an assistant's token is refused, as for the answer itself.

create or replace function public.mcp_my_action_confirmations(p_answered_since timestamptz)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if auth.jwt() ? 'client_id' then raise exception 'confirmations are answered in the Deskilo app' using errcode = 'DKN01'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'status', case when c.status = 'pending' and c.expires_at <= now() then 'expired' else c.status end,
      'operation', c.operation,
      'workspace_id', c.workspace_id,
      'workspace_name', (select name from public.workspaces where id = c.workspace_id),
      'client_name', (select name from public.mcp_clients where client_id = c.client_id),
      'preview', c.preview,
      'created_at', c.created_at,
      'expires_at', c.expires_at) order by c.created_at desc)
      from public.mcp_action_confirmations c
     where c.local_user_id = auth.uid()
       and ((c.status = 'pending' and c.expires_at > now()) or c.created_at >= p_answered_since)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.mcp_my_action_confirmations(timestamptz) from public, anon;
grant execute on function public.mcp_my_action_confirmations(timestamptz) to authenticated;

select public.set_deskilo_schema_version(771);
