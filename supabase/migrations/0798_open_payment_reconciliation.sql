-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4126 -- a payment attempt left open with a provider's order is reconciled
-- with that provider. A schedule asks the provider, with the credentials the
-- business already stored, about every attempt still open a short while after
-- it was opened, and applies the answer through the paths the notifications
-- use: settled once (settle_online_payment), ended (mark_payment_failed), or
-- left while the provider still calls it pending. A provider that cannot be
-- reached leaves the attempt as it is; an attempt is never ended on silence.
--
-- Two ages per provider, both rule functions: an open attempt is READ from
-- payment_read_after_<provider>() on (early enough to capture an approval
-- whose notification was lost), and an attempt is ENDED for want of an
-- answer only after the provider's own lifetime of an unpaid order
-- (payment_open_lifetime_<provider>()). An attempt whose order is still the
-- provisional id of an uncertain answer (#3917) after that lifetime was never
-- given a way to pay: it is ended and counted apart; a late notification
-- still credits it once through #3917's path.
--
-- Every attempt remembers when it was last checked and how often
-- (payment_reconciliation_checks): the claim takes the least recently checked
-- first and waits longer after every check (payment_reconcile_backoff()), so
-- an attempt that stays unreadable is still named on every check and never
-- holds back the newer ones.
--
--  * payment_reconciliation_runs: one row per run and business -- what was
--    read, settled, ended, left, abandoned, and the attempts that could not be
--    read with a reason word (ids and words only). Kept for
--    payment_reconciliation_retention(); no client reads it.
--  * payment_reconciliation_state: the lease per business, the attempts it
--    claimed, its last finish and error.
--  * payment_reconciliation_schedule: the last tick, its outcome, and the
--    start of the last run (the run's marker, taken from the database).
--  * begin / claim / finish / tick, the service role only; pg_cron runs the
--    tick hourly at :41.
--
-- Operator, before the schedule does anything on a project: set the Edge
-- secret PAYMENT_RECONCILE_SECRET and the Vault secret
-- deskilo_payment_reconcile_secret to the same value, and deploy
-- payment-reconcile.

-- ── when an open attempt is read ──────────────────────────────────────
-- Half an hour: a provider's notification arrives within minutes; one that
-- has not arrived by then is the case this schedule exists for, and PayPal's
-- approval (3 hours, below) is still there to be captured.
create or replace function public.payment_read_after_stripe()
returns interval language sql immutable set search_path = public as $fn$
  select interval '30 minutes';
$fn$;

create or replace function public.payment_read_after_mollie()
returns interval language sql immutable set search_path = public as $fn$
  select interval '30 minutes';
$fn$;

create or replace function public.payment_read_after_paypal()
returns interval language sql immutable set search_path = public as $fn$
  select interval '30 minutes';
$fn$;

-- ── when an unpaid attempt may be ended ───────────────────────────────
-- Stripe: a Checkout Session expires 24 hours after it is created unless the
-- session sets expires_at (Stripe API reference, Checkout Session
-- `expires_at`; DesKilo sets none).
create or replace function public.payment_open_lifetime_stripe()
returns interval language sql immutable set search_path = public as $fn$
  select interval '24 hours';
$fn$;

-- Mollie (and Wero through Mollie): an open payment expires after a time that
-- depends on its method, two hours at most for the methods with a fixed time
-- (Mollie docs, "Handling payment status", expiry times per method); a SEPA
-- bank transfer stays open longer (12 days by default) and is simply left
-- and read again.
create or replace function public.payment_open_lifetime_mollie()
returns interval language sql immutable set search_path = public as $fn$
  select interval '2 hours';
$fn$;

-- PayPal: an order stays CREATED for 3 hours (PayPal developer docs, Orders
-- API, "Expanded Checkout"; an account may have it extended up to 72 hours).
create or replace function public.payment_open_lifetime_paypal()
returns interval language sql immutable set search_path = public as $fn$
  select interval '3 hours';
$fn$;

-- PayPal has no "expired" status: an order past its lifetime answers 404
-- RESOURCE_NOT_FOUND (INVALID_RESOURCE_ID, PayPal Orders v2 errors), and the
-- documentation names no time after which a completed order stops being
-- readable. A known order that answers not-found is ended only after the
-- longest lifetime an account may have (72 hours) and a day's margin; by then
-- the schedule has read it, and settled it if it was paid, many times over.
create or replace function public.payment_paypal_gone_after()
returns interval language sql immutable set search_path = public as $fn$
  select interval '96 hours';
$fn$;

-- The provider's read age and lifetime; null for a provider not asked.
create or replace function public.payment_read_after(p_provider text)
returns interval language sql immutable set search_path = public as $fn$
  select case p_provider
    when 'stripe' then public.payment_read_after_stripe()
    when 'mollie' then public.payment_read_after_mollie()
    when 'wero' then public.payment_read_after_mollie()
    when 'paypal' then public.payment_read_after_paypal()
  end;
$fn$;

create or replace function public.payment_open_lifetime(p_provider text)
returns interval language sql immutable set search_path = public as $fn$
  select case p_provider
    when 'stripe' then public.payment_open_lifetime_stripe()
    when 'mollie' then public.payment_open_lifetime_mollie()
    when 'wero' then public.payment_open_lifetime_mollie()
    when 'paypal' then public.payment_open_lifetime_paypal()
  end;
$fn$;

-- How long after its last check an attempt is checked again: half an hour
-- while it is younger than its provider's lifetime (a payer may approve
-- between two checks), then half an hour doubled per check made after the
-- lifetime, at most a day.
create or replace function public.payment_reconcile_backoff(p_checks integer)
returns interval language sql immutable set search_path = public as $fn$
  select least(interval '30 minutes' * power(2, least(greatest(coalesce(p_checks, 0) - 1, 0), 16)),
               interval '24 hours');
$fn$;

-- How long a run's row is kept: long enough to answer "what happened to this
-- attempt" over a quarter's closing, after which the payments themselves are
-- the record.
create or replace function public.payment_reconciliation_retention()
returns interval language sql immutable set search_path = public as $fn$
  select interval '120 days';
$fn$;

-- How long the same order request may be sent again under its key: an
-- attempt still on its provisional id is not ended before it, since a resend
-- would still hand the payer a way to pay. Equal to KEY_RETENTION_S of
-- create-payment-order/outcome.ts (test/lint/payment_resend_window_test.dart).
create or replace function public.payment_resend_window()
returns interval language sql immutable set search_path = public as $fn$
  select interval '23 hours';
$fn$;

revoke execute on function public.payment_resend_window() from public, anon, authenticated;
revoke execute on function public.payment_read_after_stripe() from public, anon, authenticated;
revoke execute on function public.payment_read_after_mollie() from public, anon, authenticated;
revoke execute on function public.payment_read_after_paypal() from public, anon, authenticated;
revoke execute on function public.payment_open_lifetime_stripe() from public, anon, authenticated;
revoke execute on function public.payment_open_lifetime_mollie() from public, anon, authenticated;
revoke execute on function public.payment_open_lifetime_paypal() from public, anon, authenticated;
revoke execute on function public.payment_paypal_gone_after() from public, anon, authenticated;
revoke execute on function public.payment_read_after(text) from public, anon, authenticated;
revoke execute on function public.payment_open_lifetime(text) from public, anon, authenticated;
revoke execute on function public.payment_reconcile_backoff(integer) from public, anon, authenticated;
revoke execute on function public.payment_reconciliation_retention() from public, anon, authenticated;

-- The open attempts, by business and age: what the claim reads.
create index if not exists payment_intents_open_idx
  on public.payment_intents (workspace_id, created_at) where status = 'created';

-- ── the record of what each run did ───────────────────────────────────
create table public.payment_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  started_at timestamptz not null,
  finished_at timestamptz not null default now(),
  read_count integer not null check (read_count >= 0),
  settled_count integer not null check (settled_count >= 0),
  ended_count integer not null check (ended_count >= 0),
  left_count integer not null check (left_count >= 0),
  -- ended because no order was ever known for them (an uncertain answer).
  abandoned_count integer not null default 0 check (abandoned_count >= 0),
  unreadable_count integer not null check (unreadable_count >= 0),
  -- [{intent, reason}]: the attempt's id and a reason word, nothing else.
  unreadable jsonb not null default '[]'::jsonb check (jsonb_typeof(unreadable) = 'array'),
  -- the counts the function sent that were not counts, recorded as 0.
  malformed text[] not null default '{}'
);
select public.ensure_system_columns('payment_reconciliation_runs');
create index payment_reconciliation_runs_workspace_idx
  on public.payment_reconciliation_runs (workspace_id, finished_at desc);

comment on table public.payment_reconciliation_runs is
  '#4126 -- what each reconciliation run did for a business: attempts read, settled, ended, left, ended without any known order (abandoned), and those it could not read with the reason word. Written by the service role through payment_reconciliation_finish_v1 only; no client reads it.';

alter table public.payment_reconciliation_runs enable row level security;
revoke all on public.payment_reconciliation_runs from public, anon, authenticated;
create policy mcp_delegated_deny on public.payment_reconciliation_runs as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the lease per business ────────────────────────────────────────────
create table public.payment_reconciliation_state (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  lease_token uuid,
  lease_until timestamptz,
  last_attempt_at timestamptz,
  -- the attempts the lease's holder claimed: the only ones its record names.
  claimed uuid[] not null default '{}',
  last_finish_at timestamptz,
  last_error text,
  -- when a run last took over a lease another run left without finishing
  last_unfinished_at timestamptz
);
select public.ensure_system_columns('payment_reconciliation_state');

comment on table public.payment_reconciliation_state is
  '#4126 -- the reconciliation schedule''s lease per business, the attempts it claimed, its last finish, the last error, and when a lease was last left unfinished. Written by the service role only.';

alter table public.payment_reconciliation_state enable row level security;
revoke all on public.payment_reconciliation_state from public, anon, authenticated;
create policy mcp_delegated_deny on public.payment_reconciliation_state as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── when each attempt was checked ─────────────────────────────────────
create table public.payment_reconciliation_checks (
  intent_id uuid primary key references public.payment_intents(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  last_checked_at timestamptz not null,
  -- the checks made after the provider's lifetime: what the backoff doubles
  checks integer not null default 0 check (checks >= 0),
  -- what the provider last said of the order (its own status word) and under
  -- which credentials (a fingerprint of the client id, never of a secret):
  -- a PayPal order that answers not-found ends only when the job SAW it
  -- created or approved under the same credentials.
  seen_state text check (seen_state ~ '^[A-Z_]{1,32}$'),
  seen_client text check (seen_client ~ '^[0-9a-f]{16,64}$')
);
select public.ensure_system_columns('payment_reconciliation_checks');

comment on table public.payment_reconciliation_checks is
  '#4126 -- when the reconciliation last read an open attempt, how often after its provider''s lifetime, and what the provider last said of it under which credentials. The least recently read comes first. Written by the service role only; removed once the attempt is no longer open.';

alter table public.payment_reconciliation_checks enable row level security;
revoke all on public.payment_reconciliation_checks from public, anon, authenticated;
create policy mcp_delegated_deny on public.payment_reconciliation_checks as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the schedule's own trace ──────────────────────────────────────────
create table public.payment_reconciliation_schedule (
  id boolean primary key default true check (id),
  last_tick_at timestamptz,
  last_tick_outcome text,
  last_run_started_at timestamptz
);
select public.ensure_system_columns('payment_reconciliation_schedule');

comment on table public.payment_reconciliation_schedule is
  '#4126 -- the reconciliation schedule''s last tick, its outcome (posted, not_configured) and the start of its last run. Written by the service role only.';

alter table public.payment_reconciliation_schedule enable row level security;
revoke all on public.payment_reconciliation_schedule from public, anon, authenticated;
create policy mcp_delegated_deny on public.payment_reconciliation_schedule as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- A table without a business is a personal surface: only a native session
-- reaches it at all (personal_surface_inventory_test).
create policy personal_native_session on public.payment_reconciliation_schedule as restrictive for all to public
  using ((select public.personal_native_session()))
  with check ((select public.personal_native_session()));

-- ── what is due ───────────────────────────────────────────────────────
-- An open attempt of [p_workspace_id] the schedule asks about now: a known
-- order once its provider's read age passed, a provisional one once the
-- resend window passed, and either only when its last read is older than its
-- backoff. Oldest read first, then oldest attempt.
create or replace function public.payment_reconciliation_due(p_workspace_id uuid)
returns table (intent_id uuid, last_checked_at timestamptz, created_at timestamptz)
language sql stable security definer set search_path = '' as $fn$
  select i.id, c.last_checked_at, i.created_at
    from public.payment_intents i
    left join public.payment_reconciliation_checks c on c.intent_id = i.id
   where i.workspace_id = p_workspace_id
     and i.status = 'created'
     and public.payment_open_lifetime(i.provider) is not null
     and case when i.order_id like 'pending:%'
              then i.created_at < now() - public.payment_resend_window()
              else i.created_at < now() - public.payment_read_after(i.provider) end
     and (c.last_checked_at is null
          or c.last_checked_at < now() - case
               when i.created_at > now() - public.payment_open_lifetime(i.provider)
               then public.payment_reconcile_backoff(0)
               else public.payment_reconcile_backoff(c.checks) end);
$fn$;
revoke execute on function public.payment_reconciliation_due(uuid) from public, anon, authenticated;

-- ── begin ─────────────────────────────────────────────────────────────
-- The start of a run, from the database's clock: the run's marker.
create or replace function public.payment_reconciliation_begin_v1()
returns timestamptz
language plpgsql security definer set search_path = '' as $fn$
begin
  insert into public.payment_reconciliation_schedule (id, last_run_started_at) values (true, now())
  on conflict (id) do update set last_run_started_at = now();
  return now();
end;
$fn$;
revoke execute on function public.payment_reconciliation_begin_v1() from public, anon, authenticated;
grant execute on function public.payment_reconciliation_begin_v1() to service_role;

-- ── claim ─────────────────────────────────────────────────────────────
-- The next business with attempts due, leased to the caller for
-- p_lease_seconds, with at most p_limit of them (least recently read first).
-- An attempt is stamped when its run says it was READ (the finish), so one
-- claimed and not read keeps its place. p_run_started (from begin): a
-- business attempted since then is not claimed again in the same run. A lease
-- another run left without finishing is traced (last_unfinished_at).
create or replace function public.payment_reconciliation_claim_v1(
  p_lease_seconds integer, p_run_started timestamptz, p_limit integer)
returns table (workspace_id uuid, lease_token uuid, intents jsonb)
language plpgsql security definer set search_path = '' as $fn$
#variable_conflict use_column
declare
  v_ws uuid;
  v_token uuid := gen_random_uuid();
  v_ids uuid[];
begin
  if p_lease_seconds is null or p_lease_seconds < 1 or p_run_started is null
     or p_limit is null or p_limit < 1 then
    raise exception 'a lease, the run''s start and a limit are required' using errcode = '22023';
  end if;
  insert into public.payment_reconciliation_state (workspace_id)
  select distinct i.workspace_id from public.payment_intents i
   where i.status = 'created'
  on conflict do nothing;
  select s.workspace_id into v_ws
    from public.payment_reconciliation_state s
   where (s.lease_until is null or s.lease_until < now())
     and (s.last_attempt_at is null or s.last_attempt_at < p_run_started)
     and exists (select 1 from public.payment_reconciliation_due(s.workspace_id))
   order by s.last_attempt_at nulls first, s.workspace_id
   limit 1
   for update of s skip locked;
  if v_ws is null then
    return;
  end if;
  select array_agg(d.intent_id order by d.last_checked_at nulls first, d.created_at, d.intent_id)
    into v_ids
    from (select * from public.payment_reconciliation_due(v_ws)
           order by last_checked_at nulls first, created_at, intent_id
           limit p_limit) d;
  update public.payment_reconciliation_state
     set last_unfinished_at = case when lease_token is not null then now() else last_unfinished_at end,
         last_error = case when lease_token is not null then 'unfinished' else last_error end,
         lease_token = v_token,
         lease_until = now() + make_interval(secs => p_lease_seconds),
         last_attempt_at = now(),
         claimed = v_ids
   where workspace_id = v_ws;
  return query
  select v_ws, v_token, coalesce(jsonb_agg(jsonb_build_object(
           'id', i.id, 'provider', i.provider, 'order_id', i.order_id,
           'amount_cents', i.amount_cents, 'currency', i.currency, 'reference', i.reference,
           -- a PayPal order that answers not-found may be ended now ...
           'gone_may_end', i.provider = 'paypal' and i.created_at < now() - public.payment_paypal_gone_after(),
           -- ... if this job saw it created or approved under these credentials
           'seen_state', c.seen_state, 'seen_client', c.seen_client,
           -- an approval is captured by the job only inside the lifetime
           'may_capture', i.created_at > now() - public.payment_open_lifetime(i.provider))
           order by array_position(v_ids, i.id)), '[]'::jsonb)
    from public.payment_intents i
    left join public.payment_reconciliation_checks c on c.intent_id = i.id
   where i.id = any (v_ids);
end;
$fn$;
revoke execute on function public.payment_reconciliation_claim_v1(integer, timestamptz, integer) from public, anon, authenticated;
grant execute on function public.payment_reconciliation_claim_v1(integer, timestamptz, integer) to service_role;

-- ── finish ────────────────────────────────────────────────────────────
-- The run's row for p_workspace_id, from the lease's holder only (false
-- otherwise: the lease ran out and another run may hold the business now;
-- nothing is written). p_result: {read, settled, ended, left, abandoned,
-- unreadable: [{intent, reason}], read_items: [{intent, seen_state?,
-- seen_client?}]}. A count that is not a whole number is recorded as 0 and
-- named in `malformed`; an unreadable entry is kept only for an attempt this
-- lease claimed and with a reason word. Each read item of a claimed attempt
-- is stamped (and counted toward its backoff once past its lifetime); the
-- check rows of this business's attempts no longer open are removed.
create or replace function public.payment_reconciliation_finish_v1(
  p_workspace_id uuid, p_lease_token uuid, p_result jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $fn$
declare
  v_state public.payment_reconciliation_state;
  v_result jsonb := case when jsonb_typeof(p_result) = 'object' then p_result else '{}'::jsonb end;
  v_counts jsonb := '{}'::jsonb;
  v_malformed text[] := '{}';
  v_key text;
  v_unreadable jsonb;
begin
  select * into v_state from public.payment_reconciliation_state
   where workspace_id = p_workspace_id
   for update;
  if not found or v_state.lease_token is distinct from p_lease_token then
    return false;
  end if;
  foreach v_key in array array['read', 'settled', 'ended', 'left', 'abandoned'] loop
    if v_result ? v_key and not (jsonb_typeof(v_result -> v_key) = 'number'
                                 and (v_result ->> v_key) ~ '^[0-9]{1,9}$') then
      v_malformed := v_malformed || v_key;
      v_counts := v_counts || jsonb_build_object(v_key, 0);
    else
      v_counts := v_counts || jsonb_build_object(v_key, coalesce((v_result ->> v_key)::integer, 0));
    end if;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('intent', i.id, 'reason', e ->> 'reason')
                            order by i.id), '[]'::jsonb)
    into v_unreadable
    from jsonb_array_elements(case when jsonb_typeof(v_result -> 'unreadable') = 'array'
                                   then v_result -> 'unreadable' else '[]'::jsonb end) e
    join public.payment_intents i
      on i.id::text = e ->> 'intent' and i.workspace_id = p_workspace_id
   where i.id = any (v_state.claimed)
     and e ->> 'reason' in ('unreachable', 'refused', 'not_configured', 'unknown_order', 'mismatch',
                            'unexpected_answer', 'record_failed', 'approved_not_captured');
  insert into public.payment_reconciliation_checks
    (intent_id, workspace_id, last_checked_at, checks, seen_state, seen_client)
  select i.id, p_workspace_id, now(),
         case when i.created_at < now() - public.payment_open_lifetime(i.provider) then 1 else 0 end,
         case when e ->> 'seen_state' ~ '^[A-Z_]{1,32}$' then e ->> 'seen_state' end,
         case when e ->> 'seen_client' ~ '^[0-9a-f]{16,64}$' then e ->> 'seen_client' end
    from jsonb_array_elements(case when jsonb_typeof(v_result -> 'read_items') = 'array'
                                   then v_result -> 'read_items' else '[]'::jsonb end) e
    join public.payment_intents i
      on i.id::text = e ->> 'intent' and i.workspace_id = p_workspace_id
   where i.id = any (v_state.claimed)
  on conflict (intent_id) do update
    set last_checked_at = excluded.last_checked_at,
        checks = public.payment_reconciliation_checks.checks + excluded.checks,
        seen_state = coalesce(excluded.seen_state, public.payment_reconciliation_checks.seen_state),
        seen_client = coalesce(excluded.seen_client, public.payment_reconciliation_checks.seen_client);
  delete from public.payment_reconciliation_checks c
   using public.payment_intents i
   where c.intent_id = i.id and c.workspace_id = p_workspace_id and i.status <> 'created';
  insert into public.payment_reconciliation_runs
    (workspace_id, started_at, read_count, settled_count, ended_count, left_count,
     abandoned_count, unreadable_count, unreadable, malformed)
  values (p_workspace_id,
          coalesce(v_state.last_attempt_at, now()),
          (v_counts ->> 'read')::integer, (v_counts ->> 'settled')::integer,
          (v_counts ->> 'ended')::integer, (v_counts ->> 'left')::integer,
          (v_counts ->> 'abandoned')::integer,
          jsonb_array_length(v_unreadable), v_unreadable, v_malformed);
  update public.payment_reconciliation_state
     set lease_token = null, lease_until = null, claimed = '{}',
         last_finish_at = now(),
         last_error = case when cardinality(v_malformed) > 0 then 'malformed counts' else null end
   where workspace_id = p_workspace_id;
  return true;
end;
$fn$;
revoke execute on function public.payment_reconciliation_finish_v1(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.payment_reconciliation_finish_v1(uuid, uuid, jsonb) to service_role;

-- ── tick ──────────────────────────────────────────────────────────────
-- What the schedule runs: the rows past their retention go, then one post to
-- payment-reconcile, or nothing when the functions URL or the shared secret
-- is missing. Either way the outcome is kept on the schedule's row.
create or replace function public.payment_reconciliation_tick()
returns text
language plpgsql security definer set search_path = '' as $fn$
declare
  v_cfg public.push_config;
  v_secret text;
  v_outcome text;
begin
  delete from public.payment_reconciliation_runs
   where finished_at < now() - public.payment_reconciliation_retention();
  select * into v_cfg from public.push_config where id;
  select decrypted_secret into v_secret from vault.decrypted_secrets
   where name = 'deskilo_payment_reconcile_secret';
  if v_cfg.functions_url is null or nullif(v_secret, '') is null then
    raise notice 'payment reconciliation not configured: the functions URL or the Vault secret deskilo_payment_reconcile_secret is missing';
    v_outcome := 'not_configured';
  else
    perform net.http_post(
      url := v_cfg.functions_url || '/payment-reconcile',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_cfg.anon_key,
        'Content-Type', 'application/json',
        'x-deskilo-reconcile-secret', v_secret),
      body := '{}'::jsonb);
    v_outcome := 'posted';
  end if;
  insert into public.payment_reconciliation_schedule (id, last_tick_at, last_tick_outcome)
  values (true, now(), v_outcome)
  on conflict (id) do update set last_tick_at = now(), last_tick_outcome = v_outcome;
  return v_outcome;
end;
$fn$;
revoke execute on function public.payment_reconciliation_tick() from public, anon, authenticated;
grant execute on function public.payment_reconciliation_tick() to service_role;

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-payment-reconcile')
    where exists (select 1 from cron.job where jobname = 'deskilo-payment-reconcile');
  perform cron.schedule('deskilo-payment-reconcile', '41 * * * *',
    $job$select public.payment_reconciliation_tick()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs payment_reconciliation_tick() instead', sqlerrm;
end
$cron$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(798);
