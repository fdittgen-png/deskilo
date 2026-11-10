-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table, two functions; invoice_essentials_missing patched at one
-- asserted anchor)
--
-- #3159 -- a seller in a country whose law routes every invoice through a
-- national channel (Italy's SdI, Spain's Verifactu; the `issuing_gate` rows
-- with `national_channel_required`) stayed refused at issue by a constant:
-- `seller_country_unsupported`, whatever the workspace had proven. The gate
-- now lifts PER WORKSPACE once that channel has accepted a submission of the
-- workspace's (a sandbox or a production one) and the acceptance is recorded:
--
--  * national_channel_acceptances -- one row per (workspace, country,
--    channel, environment): the channel's receipt and when it accepted.
--    Readable by who reads the finances; written only by
--    record_national_channel_acceptance_v1, which only the service role (the
--    channel's edge function) may call. No client can claim an acceptance.
--  * national_channel_accepted(ws, country) -- the one test the gate asks.
--  * invoice_essentials_missing -- `national_channel_required` refuses only
--    while no acceptance is recorded for the seller's country.
--
-- Nothing else of the gate changes: an unsupported country, a seller at a
-- site outside the VAT and every other essential are refused as before.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── the table ────────────────────────────────────────────────────────────
create table if not exists public.national_channel_acceptances (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  channel text not null check (channel in ('it_sdi', 'es_verifactu', 'pl_ksef', 'ro_efactura')),
  environment text not null check (environment in ('sandbox', 'production')),
  receipt jsonb not null check (jsonb_typeof(receipt) = 'object' and receipt <> '{}'::jsonb),
  accepted_at timestamptz not null,
  unique (workspace_id, country_code, channel, environment)
);
select public.ensure_system_columns('national_channel_acceptances');

alter table public.national_channel_acceptances enable row level security;
revoke all on public.national_channel_acceptances from public, anon;
revoke insert, update, delete on public.national_channel_acceptances from authenticated;
grant select on public.national_channel_acceptances to authenticated;
drop policy if exists national_channel_acceptances_select on public.national_channel_acceptances;
create policy national_channel_acceptances_select on public.national_channel_acceptances
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
drop policy if exists mcp_delegated_deny on public.national_channel_acceptances;
create policy mcp_delegated_deny on public.national_channel_acceptances as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the one test ─────────────────────────────────────────────────────────
create or replace function public.national_channel_accepted(p_workspace_id uuid, p_country text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.national_channel_acceptances a
                  where a.workspace_id = p_workspace_id
                    and a.country_code = upper(btrim(coalesce(p_country, ''))))
$fn$;
revoke execute on function public.national_channel_accepted(uuid, text) from public, anon, authenticated;

-- ── the only writer: the channel's edge function ─────────────────────────
-- Idempotent: the same acceptance again changes nothing; a later one of the
-- same channel and environment replaces the receipt and its time.
create or replace function public.record_national_channel_acceptance_v1(
  p_workspace_id uuid, p_country text, p_channel text, p_environment text,
  p_receipt jsonb, p_accepted_at timestamptz
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_cc text := upper(btrim(coalesce(p_country, '')));
  v_id uuid;
begin
  if not exists (select 1 from public.workspaces w where w.id = p_workspace_id) then
    raise exception 'unknown workspace';
  end if;
  if not coalesce((public.issuing_gate_of(v_cc) ->> 'national_channel_required')::boolean, false) then
    raise exception 'no national channel is required for %', v_cc;
  end if;
  if p_accepted_at is null or p_accepted_at > now() + interval '5 minutes' then
    raise exception 'the acceptance needs its time, not in the future';
  end if;
  insert into public.national_channel_acceptances
    (workspace_id, country_code, channel, environment, receipt, accepted_at)
  values (p_workspace_id, v_cc, p_channel, p_environment, p_receipt, p_accepted_at)
  on conflict (workspace_id, country_code, channel, environment) do update
    set receipt = excluded.receipt, accepted_at = excluded.accepted_at
    where public.national_channel_acceptances.accepted_at < excluded.accepted_at
  returning id into v_id;
  return jsonb_build_object('recorded', v_id is not null,
                            'gate_open', public.national_channel_accepted(p_workspace_id, v_cc));
end;
$fn$;
revoke execute on function public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)
  from public, anon, authenticated;
grant execute on function public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)
  to service_role;

-- ── the gate asks it ─────────────────────────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)'::regprocedure)
    into v_def;
  if position('national_channel_accepted(p_workspace_id, v_cc)' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $a$     or coalesce((v_gate ->> 'national_channel_required')::boolean, false) then$a$,
      $a$     or (coalesce((v_gate ->> 'national_channel_required')::boolean, false)
         and not public.national_channel_accepted(p_workspace_id, v_cc)) then$a$);
    if v_def is null then raise exception '0701: invoice_essentials_missing anchor missing'; end if;
    execute v_def;
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(701);
