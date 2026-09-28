-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0298 (#1630, checkpoint 1) -- the MCP facade counts every call it
-- answers and refuses the ones over a limit before any work is done.
-- (0297 is #1647's consent context; this follows it.)
--
--   * mcp_usage: one row per tools/call attempt mcp_execute_v1 answers --
--     who (user, client), where (installation, workspace), what (operation,
--     whether it mutates) and how it ended (the envelope status and, when
--     the answer names one, the event). Never a token, an argument or a
--     result body. The row is written by the facade itself, so a mutation
--     and its usage row commit or roll back together. An idempotent replay
--     answers from mcp_idempotency and writes no row.
--   * mcp_limits: one row. 60 calls and 10 mutations per minute per user
--     and client, 10000 calls per day per workspace; UTC windows.
--   * the check runs after authorisation and, for a mutation, after the
--     replay lookup, under an advisory lock on user+client so two
--     concurrent calls cannot both take the last slot. Over a limit the
--     answer is rate_limited with data.retry_after (seconds until the
--     window resets) and nothing else runs.
--   * a refused call does no work, so a denied, rate_limited or
--     validation_error row never counts toward the workspace's day: a
--     caller outside a workspace cannot exhaust it by naming it. The
--     per-user minute counts everything but rate_limited rows.

create table if not exists public.mcp_usage (
  id uuid primary key default gen_random_uuid(),
  request_id uuid,
  installation_id uuid not null,
  workspace_id uuid not null,
  local_user_id uuid not null references auth.users (id) on delete cascade,
  client_id text,
  operation text not null,
  mutation boolean not null,
  outcome text not null,
  event_id uuid,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('mcp_usage');
create index if not exists mcp_usage_caller_idx
  on public.mcp_usage (local_user_id, client_id, created_at);
create index if not exists mcp_usage_workspace_idx
  on public.mcp_usage (workspace_id, created_at);
alter table public.mcp_usage enable row level security;
revoke all on table public.mcp_usage from anon, authenticated;
create policy mcp_delegated_deny on public.mcp_usage
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table if not exists public.mcp_limits (
  singleton boolean primary key default true check (singleton),
  calls_per_minute integer not null default 60 check (calls_per_minute > 0),
  mutations_per_minute integer not null default 10 check (mutations_per_minute > 0),
  workspace_calls_per_day integer not null default 10000 check (workspace_calls_per_day > 0)
);
select public.ensure_system_columns('mcp_limits');
insert into public.mcp_limits (singleton) values (true) on conflict do nothing;
alter table public.mcp_limits enable row level security;
revoke all on table public.mcp_limits from anon, authenticated;
create policy mcp_delegated_deny on public.mcp_limits
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Seconds until the tightest exceeded window resets, or null when the call
-- may proceed. Takes the caller's lock, held to the end of the transaction,
-- so the count and the usage row the facade writes are one step.
create or replace function public.mcp_limit_retry_after(p_workspace_id uuid, p_client text, p_mutation boolean)
returns integer language plpgsql volatile set search_path = public as $fn$
declare
  v_limits public.mcp_limits;
  v_minute timestamptz := date_trunc('minute', now(), 'UTC');
  v_day timestamptz := date_trunc('day', now(), 'UTC');
  v_calls integer;
  v_mutations integer;
  v_retry integer;
begin
  select * into v_limits from public.mcp_limits;
  perform pg_advisory_xact_lock(hashtextextended(
    public.installation_id()::text || '|' || auth.uid()::text || '|' || p_client, 1630));
  select count(*), count(*) filter (where mutation) into v_calls, v_mutations
    from public.mcp_usage
   where local_user_id = auth.uid() and client_id = p_client
     and created_at >= v_minute and outcome <> 'rate_limited';
  if v_calls >= coalesce(v_limits.calls_per_minute, 60)
     or (p_mutation and v_mutations >= coalesce(v_limits.mutations_per_minute, 10)) then
    v_retry := ceil(extract(epoch from v_minute + interval '1 minute' - now()))::integer;
  end if;
  if (select count(*) from public.mcp_usage
       where workspace_id = p_workspace_id and created_at >= v_day
         and outcome not in ('denied', 'rate_limited', 'validation_error'))
     >= coalesce(v_limits.workspace_calls_per_day, 10000) then
    v_retry := greatest(coalesce(v_retry, 0),
                        ceil(extract(epoch from v_day + interval '1 day' - now()))::integer);
  end if;
  return case when v_retry is null then null else greatest(v_retry, 1) end;
end;
$fn$;
revoke execute on function public.mcp_limit_retry_after(uuid, text, boolean) from public, anon, authenticated;

-- Records the answer the facade is about to give and hands it back
-- unchanged. Reads only the envelope's head (status, operation, event_id);
-- the arguments never reach it.
create or replace function public.mcp_usage_note(p_spec jsonb, p_envelope jsonb)
returns jsonb language plpgsql volatile set search_path = public as $fn$
begin
  if p_envelope->>'workspace_id' is not null and auth.uid() is not null then
    insert into public.mcp_usage (request_id, installation_id, workspace_id, local_user_id, client_id,
                                  operation, mutation, outcome, event_id)
    values ((p_envelope->>'request_id')::uuid, public.installation_id(),
            (p_envelope->>'workspace_id')::uuid, auth.uid(), left(auth.jwt()->>'client_id', 200),
            case when p_spec is null then 'unknown' else p_envelope->>'operation' end,
            coalesce(p_spec->>'mutation', 'read') <> 'read',
            coalesce(p_envelope->>'status', 'unknown'),
            case when p_envelope->'data'->>'event_id'
                      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                 then (p_envelope->'data'->>'event_id')::uuid end);
  end if;
  return p_envelope;
end;
$fn$;
revoke execute on function public.mcp_usage_note(jsonb, jsonb) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_next text;
  v_returns integer;
begin
  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('public.mcp_usage_note(' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  v_ops jsonb;
begin$a$,
      $a$  v_ops jsonb;
  v_retry integer;
begin$a$);
    if v_next is null then raise exception '0298: declare anchor not found'; end if;
    v_def := v_next;

    v_next := pg_temp.anchor_replace(v_def,
      $a$  if v_spec->>'mutation' = 'read' then
    begin$a$,
      $a$  -- #1630 — a read is limited once authorised, before any work.
  if v_spec->>'mutation' = 'read' then
    v_retry := public.mcp_limit_retry_after(p_workspace_id, v_client, false);
    if v_retry is not null then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'rate_limited', null, 'rate_limited')
             || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry));
    end if;
  end if;
  if v_spec->>'mutation' = 'read' then
    begin$a$);
    if v_next is null then raise exception '0298: read anchor not found (needs 0275)'; end if;
    v_def := v_next;

    v_next := pg_temp.anchor_replace(v_def,
      $a$  if v_spec->>'confirmation' = 'native' then$a$,
      $a$  -- #1630 — a mutation is limited after the replay (a replay is not a
  -- new call) and before confirmation or any business work.
  v_retry := public.mcp_limit_retry_after(p_workspace_id, v_client, true);
  if v_retry is not null then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'rate_limited', null, 'rate_limited')
           || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry));
  end if;
  if v_spec->>'confirmation' = 'native' then$a$);
    if v_next is null then raise exception '0298: mutation anchor not found (needs 0272)'; end if;
    v_def := v_next;

    v_next := pg_temp.anchor_replace(v_def,
      $a$  return v_data;
end;$a$,
      $a$  return public.mcp_usage_note(v_spec, v_data);
end;$a$);
    if v_next is null then raise exception '0298: final return anchor not found'; end if;
    v_def := v_next;

    -- Every other answer the facade gives is `return public.mcp_envelope(...)`:
    -- each is recorded. The replay (`return v_prior.outcome ...`) is not.
    v_returns := (length(v_def) - length(replace(v_def, 'return public.mcp_envelope(', '')))
                 / length('return public.mcp_envelope(');
    if v_returns < 20 then raise exception '0298: expected the facade''s envelope returns, found %', v_returns; end if;
    v_next := regexp_replace(v_def, 'return (public\.mcp_envelope\([^;]*\));',
                             'return public.mcp_usage_note(v_spec, \1);', 'g');
    if position('return public.mcp_envelope(' in v_next) > 0
       or (length(v_next) - length(replace(v_next, 'return public.mcp_usage_note(v_spec, ', '')))
          / length('return public.mcp_usage_note(v_spec, ') <> v_returns + 1 then
      raise exception '0298: not every envelope return was wrapped';
    end if;
    execute v_next;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(298);
