-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0302 (#1630) -- the database administrator may LOWER the MCP limits.
--
-- 0298 fixed the limits at the issue's defaults (60 calls and 10
-- mutations a minute per person and client, 10000 calls a day per
-- workspace). set_mcp_limits lets a database administrator, at AAL2,
-- tighten them for this installation. It can never raise a limit above
-- those defaults, which are the ceiling, and a workspace owner cannot set
-- them at all. An assistant (a delegated MCP token) cannot either.

create or replace function public.set_mcp_limits(
  p_calls_per_minute integer,
  p_mutations_per_minute integer,
  p_workspace_calls_per_day integer)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.mcp_limits;
begin
  if public.mcp_is_delegated() then
    raise exception 'limits are set in the Deskilo app, not by an assistant';
  end if;
  perform public.require_database_reviewer();
  if p_calls_per_minute is null or p_calls_per_minute not between 1 and 60
     or p_mutations_per_minute is null or p_mutations_per_minute not between 1 and 10
     or p_workspace_calls_per_day is null or p_workspace_calls_per_day not between 1 and 10000 then
    raise exception 'a limit may only be lowered: at most 60 calls and 10 mutations a minute, 10000 calls a day';
  end if;
  update public.mcp_limits
     set calls_per_minute = p_calls_per_minute,
         mutations_per_minute = p_mutations_per_minute,
         workspace_calls_per_day = p_workspace_calls_per_day
   where singleton
  returning * into v;
  return jsonb_build_object(
    'calls_per_minute', v.calls_per_minute,
    'mutations_per_minute', v.mutations_per_minute,
    'workspace_calls_per_day', v.workspace_calls_per_day);
end;
$fn$;
revoke execute on function public.set_mcp_limits(integer, integer, integer) from public, anon;
grant execute on function public.set_mcp_limits(integer, integer, integer) to authenticated;

select public.set_deskilo_schema_version(302);
