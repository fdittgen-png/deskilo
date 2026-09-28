-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0300 (#1630, checkpoint 2) -- what mcp_usage (0298) counted, read back as
-- counts only, and a bounded retention.
--
--   * mcp_usage_summary_mine: the caller's own rows, per assistant (client):
--     today's requests, refusals (denied, validation_error, rate_limited),
--     applied mutations (completed and mutating), answers still pending
--     validation, and when the assistant was last used. Never anyone
--     else's row, never an argument or a result (the table holds none).
--   * mcp_usage_summary_workspace: the workspace's owner, or an
--     administrator of this database (require_database_reviewer), sees the
--     same counts for that workspace per day and per operation over the
--     last 30 days (UTC). People appear only as a count.
--   * mcp_usage_cleanup: service_role only. Deletes at most 10000 rows per
--     call, older than p_keep_days (default 90), and never a row younger
--     than 30 days whatever it is asked. Answers how many it deleted.
--   * an assistant (a delegated MCP token) reads none of this: the table's
--     restrictive policy already refuses it, and so do these functions.

create or replace function public.mcp_usage_summary_mine(p_installation_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_day timestamptz := date_trunc('day', now(), 'UTC');
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if public.mcp_is_delegated() then raise exception 'native client required' using errcode = '42501'; end if;
  return jsonb_build_object(
    'installation_id', coalesce(p_installation_id, public.installation_id()),
    'since', v_day,
    'clients', coalesce((
      select jsonb_agg(jsonb_build_object(
               'client_id', s.client_id,
               'client_name', coalesce(c.name, s.client_id),
               'requests_today', s.requests,
               'refusals', s.refusals,
               'applied', s.applied,
               'pending_validation', s.pending,
               'last_used_at', s.last_used_at)
             order by s.last_used_at desc, s.client_id)
        from (select coalesce(u.client_id, '') as client_id,
                     count(*) filter (where u.created_at >= v_day) as requests,
                     count(*) filter (where u.created_at >= v_day
                                        and u.outcome in ('denied', 'validation_error', 'rate_limited')) as refusals,
                     count(*) filter (where u.created_at >= v_day
                                        and u.outcome = 'completed' and u.mutation) as applied,
                     count(*) filter (where u.created_at >= v_day
                                        and u.outcome = 'pending_validation') as pending,
                     max(u.created_at) as last_used_at
                from public.mcp_usage u
               where u.local_user_id = auth.uid()
                 and u.installation_id = coalesce(p_installation_id, public.installation_id())
               group by coalesce(u.client_id, '')) s
        left join public.mcp_clients c on c.client_id = s.client_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.mcp_usage_summary_mine(uuid) from public, anon;
grant execute on function public.mcp_usage_summary_mine(uuid) to authenticated;

create or replace function public.mcp_usage_summary_workspace(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_since timestamptz := date_trunc('day', now(), 'UTC') - interval '29 days';
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if public.mcp_is_delegated() then raise exception 'native client required' using errcode = '42501'; end if;
  if p_workspace_id is null or not public.is_owner_of(p_workspace_id) then
    begin
      perform public.require_database_reviewer();
    exception when others then
      raise exception 'only the workspace owner or a database administrator' using errcode = '42501';
    end;
  end if;
  return jsonb_build_object(
    'workspace_id', p_workspace_id,
    'since', v_since,
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
               'day', s.day, 'operation', s.operation,
               'requests', s.requests, 'refusals', s.refusals, 'applied', s.applied,
               'pending_validation', s.pending, 'people', s.people)
             order by s.day desc, s.operation)
        from (select (u.created_at at time zone 'UTC')::date as day,
                     u.operation,
                     count(*) as requests,
                     count(*) filter (where u.outcome in ('denied', 'validation_error', 'rate_limited')) as refusals,
                     count(*) filter (where u.outcome = 'completed' and u.mutation) as applied,
                     count(*) filter (where u.outcome = 'pending_validation') as pending,
                     count(distinct u.local_user_id) as people
                from public.mcp_usage u
               where u.workspace_id = p_workspace_id
                 and u.installation_id = public.installation_id()
                 and u.created_at >= v_since
               group by 1, 2) s), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.mcp_usage_summary_workspace(uuid) from public, anon;
grant execute on function public.mcp_usage_summary_workspace(uuid) to authenticated;

create or replace function public.mcp_usage_cleanup(p_keep_days integer default 90)
returns integer language plpgsql volatile set search_path = public as $fn$
declare
  v_cutoff timestamptz := now() - make_interval(days => greatest(coalesce(p_keep_days, 90), 30));
  v_deleted integer;
begin
  with doomed as (
    select id from public.mcp_usage
     where created_at < v_cutoff
     order by created_at
     limit 10000
     for update skip locked)
  delete from public.mcp_usage u using doomed d where u.id = d.id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$fn$;
revoke execute on function public.mcp_usage_cleanup(integer) from public, anon, authenticated;
grant execute on function public.mcp_usage_cleanup(integer) to service_role;

select public.set_deskilo_schema_version(300);
