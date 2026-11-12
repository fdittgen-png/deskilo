-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3510 (third pull request) -- a schedule reads each Mollie workspace's
-- settlements by itself, instead of only when a person presses the fetch.
-- The recorder (0720) and the review process (0722) are unchanged: the
-- schedule records through record_provider_settlement_v1 like the fetch.
--
--  * provider_settlement_polls: one row per workspace and provider, the
--    schedule's own state. Where an unfinished read continues (`continuation`,
--    Mollie's `from` cursor, never a URL), whether the first full read of the
--    account reached its end (`backfilled`), the last success, the failures in
--    a row, when the next attempt may come, the last error and the last
--    result. No client reads or writes it.
--  * settlement_poll_claim_v1: the next workspace due, under a lease, with
--    its key (the service role only). Due =
--    a Mollie key, online payments on, no live lease, its retry time passed,
--    not attempted yet in this run. `for update skip locked` and the lease
--    keep two polls from ever reading the same workspace at once.
--  * settlement_poll_finish_v1: the result, accepted only from the lease's
--    holder. A success clears the failures; Mollie refusing the key (4xx) is
--    permanent and waits a day; the network, 429, 5xx or the database are
--    retried sooner, doubling up to a bound. The continuation is kept on a
--    failure too: the pages already recorded are not read again first.
--  * settlement_poll_tick: what the schedule runs. It posts to the
--    settlement-poll function (push_config's functions URL) with the Vault
--    secret `deskilo_settlement_poll_secret` in a header; without either it
--    does nothing and says so.
--  * pg_cron: hourly at :23 (Mollie settles at most daily).
--
-- Operator, before the schedule does anything on a project: set the Edge
-- secret SETTLEMENT_POLL_SECRET and the Vault secret
-- deskilo_settlement_poll_secret to the same value, and deploy settlement-poll.

create table public.provider_settlement_polls (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provider text not null check (provider in ('mollie')),
  backfilled boolean not null default false,
  continuation text check (continuation is null or continuation <> ''),
  lease_token uuid,
  lease_until timestamptz,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  failures integer not null default 0 check (failures >= 0),
  next_attempt_at timestamptz,
  last_error jsonb,
  last_result jsonb,
  primary key (workspace_id, provider)
);
select public.ensure_system_columns('provider_settlement_polls');

comment on table public.provider_settlement_polls is
  '#3510 -- the settlement schedule''s state per workspace and provider: where an unfinished read continues, whether the first full read ended, its lease, failures and next attempt. Written by the service role only.';

alter table public.provider_settlement_polls enable row level security;
revoke all on public.provider_settlement_polls from public, anon, authenticated;
create policy mcp_delegated_deny on public.provider_settlement_polls as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The next workspace due, leased to the caller for p_lease_seconds. Every
-- workspace with a Mollie key gets its row first. p_run_started: a row
-- attempted since then is not claimed again in the same run.
create or replace function public.settlement_poll_claim_v1(
  p_provider text, p_lease_seconds integer, p_run_started timestamptz)
returns table (workspace_id uuid, backfilled boolean, continuation text, lease_token uuid, api_key text)
language plpgsql security definer set search_path = '' as $fn$
#variable_conflict use_column
declare
  v_ws uuid;
  v_token uuid := gen_random_uuid();
begin
  if p_provider is distinct from 'mollie' then
    raise exception 'unknown provider' using errcode = '22023';
  end if;
  if p_lease_seconds is null or p_lease_seconds < 1 or p_run_started is null then
    raise exception 'a lease and the run''s start are required' using errcode = '22023';
  end if;
  insert into public.provider_settlement_polls (workspace_id, provider)
  select c.workspace_id, c.provider from public.payment_credentials c
   where c.provider = p_provider and coalesce(c.config ->> 'api_key', '') <> ''
  on conflict do nothing;
  select p.workspace_id into v_ws
    from public.provider_settlement_polls p
    join public.payment_credentials c on c.workspace_id = p.workspace_id and c.provider = p.provider
   where p.provider = p_provider
     and coalesce(c.config ->> 'api_key', '') <> ''
     and public.feature_effective(p.workspace_id, 'onlinePayments')
     and (p.lease_until is null or p.lease_until < now())
     and (p.next_attempt_at is null or p.next_attempt_at <= now())
     and (p.last_attempt_at is null or p.last_attempt_at < p_run_started)
   order by p.last_attempt_at nulls first, p.workspace_id
   limit 1
   for update of p skip locked;
  if v_ws is null then
    return;
  end if;
  -- The key comes with the lease: no second read, and no race with a key
  -- removed in between.
  return query
  update public.provider_settlement_polls p
     set lease_token = v_token,
         lease_until = now() + make_interval(secs => p_lease_seconds),
         last_attempt_at = now()
    from public.payment_credentials c
   where p.workspace_id = v_ws and p.provider = p_provider
     and c.workspace_id = p.workspace_id and c.provider = p.provider
  returning p.workspace_id, p.backfilled, p.continuation, p.lease_token, c.config ->> 'api_key';
end;
$fn$;
revoke execute on function public.settlement_poll_claim_v1(text, integer, timestamptz) from public, anon, authenticated;
grant execute on function public.settlement_poll_claim_v1(text, integer, timestamptz) to service_role;

-- A read's result, from the lease's holder only (false otherwise: the lease
-- ran out and another poll may hold the workspace now; nothing is written).
-- p_result: {complete, continuation, new, unchanged, pending, rejected,
-- refused, pages, failure: null | {kind: refused | unreachable |
-- record_failed, status?, settlement?}}.
create or replace function public.settlement_poll_finish_v1(
  p_workspace_id uuid, p_provider text, p_lease_token uuid, p_result jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $fn$
declare
  -- Mollie refusing the key stays refused until someone changes it.
  c_after_refusal constant interval := interval '24 hours';
  -- A transient failure: the first retry, doubled per failure in a row, up to
  -- the bound.
  c_first_retry constant interval := interval '5 minutes';
  c_longest_retry constant interval := interval '6 hours';
  v_row public.provider_settlement_polls;
  v_kind text := p_result -> 'failure' ->> 'kind';
  v_complete boolean := coalesce((p_result ->> 'complete')::boolean, false);
begin
  if p_result is null or jsonb_typeof(p_result) <> 'object' then
    raise exception 'a result is required' using errcode = '22023';
  end if;
  if v_kind is not null and v_kind not in ('refused', 'unreachable', 'record_failed') then
    raise exception 'unknown failure %', v_kind using errcode = '22023';
  end if;
  select * into v_row from public.provider_settlement_polls
   where workspace_id = p_workspace_id and provider = p_provider
   for update;
  if not found or v_row.lease_token is distinct from p_lease_token then
    return false;
  end if;
  update public.provider_settlement_polls
     set lease_token = null,
         lease_until = null,
         backfilled = backfilled or (v_kind is null and v_complete),
         continuation = case when v_kind is null and v_complete then null
                             else nullif(p_result ->> 'continuation', '') end,
         failures = case when v_kind is null then 0 else failures + 1 end,
         last_success_at = case when v_kind is null then now() else last_success_at end,
         last_error = case when v_kind is null then null else p_result -> 'failure' end,
         last_result = p_result - 'failure',
         next_attempt_at = case
           when v_kind is null then null
           when v_kind = 'refused' then now() + c_after_refusal
           else now() + least(c_longest_retry, c_first_retry * power(2, least(failures, 16))::integer)
         end
   where workspace_id = p_workspace_id and provider = p_provider;
  return true;
end;
$fn$;
revoke execute on function public.settlement_poll_finish_v1(uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.settlement_poll_finish_v1(uuid, text, uuid, jsonb) to service_role;

-- What the schedule runs: one post to settlement-poll, or nothing when the
-- functions URL or the shared secret is missing ('not_configured').
create or replace function public.settlement_poll_tick()
returns text
language plpgsql security definer set search_path = '' as $fn$
declare
  v_cfg public.push_config;
  v_secret text;
begin
  select * into v_cfg from public.push_config where id;
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where name = 'deskilo_settlement_poll_secret';
  if v_cfg.functions_url is null or nullif(v_secret, '') is null then
    raise notice 'settlement poll not configured: the functions URL or the Vault secret deskilo_settlement_poll_secret is missing';
    return 'not_configured';
  end if;
  perform net.http_post(
    url := v_cfg.functions_url || '/settlement-poll',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_cfg.anon_key,
      'Content-Type', 'application/json',
      'x-deskilo-poll-secret', v_secret),
    body := '{}'::jsonb);
  return 'posted';
end;
$fn$;
revoke execute on function public.settlement_poll_tick() from public, anon, authenticated;
grant execute on function public.settlement_poll_tick() to service_role;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-settlement-poll')
    where exists (select 1 from cron.job where jobname = 'deskilo-settlement-poll');
  perform cron.schedule('deskilo-settlement-poll', '23 * * * *',
    $job$select public.settlement_poll_tick()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs settlement_poll_tick() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(732);
