-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (accounting_connector_actor and record_accounting_delivery patched at
-- asserted anchors: their admission check now asks capability_admits;
-- accounting_connector_actor becomes volatile so its check sees a state
-- change committed while it waited for the admission lock)
--
-- #3336 (slice 2a) -- the operational state of a capability, per workspace:
-- `active` admits new work, `servicing` and `retired` refuse it. 0691 derived
-- the state from the feature choice alone; this stores the operator's
-- decision beside it, keeping the feature choice authoritative (a feature that
-- is off admits nothing whatever the row says).
--
--  * capability_states -- one row per (workspace, capability key); the key is
--    a WorkspaceFeature name ('accountingConnectors' first), so one registry
--    serves both. Absent row = derived: feature on is active, off servicing.
--  * capability_admits(ws, key) -- the one admission test. It takes the
--    capability's advisory lock SHARED, so admissions run together and a
--    state change (exclusive) waits for the ones in flight and wins over
--    those that follow: admission commits before deactivation, or is refused
--    after it.
--  * set_capability_state_v1 -- the transitions of the contract:
--      active -> servicing   the connector authority (manageBilling)
--      servicing -> active   the same, and the feature must be on
--      servicing -> retired  owner, with a reason, refused while any delivery
--                            is unresolved (the first one named)
--      retired -> servicing  owner, with a reason
--    Anything else is refused. Repeating the current state records nothing.
--  * capability_states_v1 -- the state for the managers (derived or stored).
-- Reads, revocation and the outcome of admitted work stay on 0691's paths.

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

create or replace function pg_temp.patch(p_def text, p_old text, p_new text, p_done text)
returns text language plpgsql as $f$
begin
  if position(p_done in p_def) > 0 then return p_def; end if;
  return pg_temp.anchor_replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.patch(text, text, text, text) from public, anon, authenticated;

-- ── the table ────────────────────────────────────────────────────────────
create table if not exists public.capability_states (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  capability_key text not null check (capability_key in ('accountingConnectors')),
  state text not null check (state in ('active', 'servicing', 'retired')),
  reason text not null default '' check (char_length(reason) <= 300),
  changed_by_member_id uuid not null,
  changed_at timestamptz not null default now(),
  primary key (workspace_id, capability_key),
  constraint capability_states_changed_by_fk
    foreign key (workspace_id, changed_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('capability_states');

alter table public.capability_states enable row level security;
revoke all on public.capability_states from public, anon, authenticated;
grant select on public.capability_states to authenticated;
drop policy if exists capability_states_select on public.capability_states;
create policy capability_states_select on public.capability_states
  for select to authenticated using (public.accounting_reader(workspace_id));
drop policy if exists mcp_delegated_deny on public.capability_states;
create policy mcp_delegated_deny on public.capability_states as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the admission test ───────────────────────────────────────────────────
create or replace function public.capability_lock_key(p_workspace_id uuid, p_key text)
returns bigint language sql immutable set search_path = public as $fn$
  select hashtextextended('capability:' || p_workspace_id::text || ':' || p_key, 0)
$fn$;
revoke execute on function public.capability_lock_key(uuid, text) from public, anon, authenticated;

create or replace function public.capability_admits(p_workspace_id uuid, p_key text)
returns boolean language plpgsql security definer set search_path = public as $fn$
begin
  -- shared: admissions together, a state change after the ones in flight
  perform pg_advisory_xact_lock_shared(public.capability_lock_key(p_workspace_id, p_key));
  return public.feature_effective(p_workspace_id, p_key)
     and not exists (select 1 from public.capability_states s
                      where s.workspace_id = p_workspace_id and s.capability_key = p_key
                        and s.state <> 'active');
end;
$fn$;
revoke execute on function public.capability_admits(uuid, text) from public, anon, authenticated;

-- ── the state, as the managers see it ───────────────────────────────────
create or replace function public.capability_states_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.accounting_connector_member(p_workspace_id, 'read');
  return jsonb_build_array((
    select jsonb_build_object(
      'key', 'accountingConnectors',
      'state', coalesce(s.state, case when public.feature_effective(p_workspace_id, 'accountingConnectors')
                                      then 'active' else 'servicing' end),
      'derived', s.state is null,
      'reason', coalesce(s.reason, ''),
      'changed_at', s.changed_at)
    from (select 1) one
    left join public.capability_states s
      on s.workspace_id = p_workspace_id and s.capability_key = 'accountingConnectors'));
end;
$fn$;
revoke execute on function public.capability_states_v1(uuid) from public, anon;
grant execute on function public.capability_states_v1(uuid) to authenticated;

-- ── the transitions ──────────────────────────────────────────────────────
create or replace function public.set_capability_state_v1(
  p_workspace_id uuid, p_key text, p_to text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_from text;
  v_reason text := left(btrim(coalesce(p_reason, '')), 300);
  v_open int;
begin
  if p_key is distinct from 'accountingConnectors' then
    raise exception 'unknown capability' using errcode = '22023';
  end if;
  if p_to not in ('active', 'servicing', 'retired') then
    raise exception 'unknown state' using errcode = '22023';
  end if;
  -- the connector authority first (signed in, native token, active member,
  -- manageBilling); retiring and reopening are the owner's besides
  v_me := public.accounting_connector_member(p_workspace_id, 'manageBilling');
  -- exclusive: waits for the admissions in flight, and wins over later ones
  perform pg_advisory_xact_lock(public.capability_lock_key(p_workspace_id, p_key));
  select coalesce(
           (select s.state from public.capability_states s
             where s.workspace_id = p_workspace_id and s.capability_key = p_key),
           case when public.feature_effective(p_workspace_id, p_key) then 'active' else 'servicing' end)
    into v_from;
  if v_from = p_to then
    return jsonb_build_object('state', v_from, 'previous', v_from, 'changed', false);
  end if;
  if (v_from, p_to) not in (('active', 'servicing'), ('servicing', 'active'),
                            ('servicing', 'retired'), ('retired', 'servicing')) then
    raise exception 'a capability goes from % to % only through servicing', v_from, p_to
      using errcode = '22023';
  end if;
  if 'retired' in (v_from, p_to) then
    if not public.is_owner_of(p_workspace_id) then
      raise exception 'only the owner retires or reopens a capability' using errcode = '42501';
    end if;
    if v_reason = '' then
      raise exception 'a reason is required' using errcode = '22023';
    end if;
  end if;
  if p_to = 'active' and not public.feature_effective(p_workspace_id, p_key) then
    raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
  end if;
  if p_to = 'retired' then
    select count(*) into v_open from public.accounting_deliveries d
     where d.workspace_id = p_workspace_id and d.status <> 'acknowledged';
    if v_open > 0 then
      raise exception '% deliveries are unresolved: finish them before retiring', v_open
        using errcode = '22023';
    end if;
  end if;
  insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id, changed_at)
  values (p_workspace_id, p_key, p_to, v_reason, v_me, now())
  on conflict (workspace_id, capability_key) do update
    set state = excluded.state, reason = excluded.reason,
        changed_by_member_id = excluded.changed_by_member_id, changed_at = excluded.changed_at;
  return jsonb_build_object('state', p_to, 'previous', v_from, 'changed', true);
end;
$fn$;
revoke execute on function public.set_capability_state_v1(uuid, text, text, text) from public, anon;
grant execute on function public.set_capability_state_v1(uuid, text, text, text) to authenticated;

-- ── the two admission points ask the one test ───────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.accounting_connector_actor(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$if not public.feature_effective(p_workspace_id, 'accountingConnectors') then$a$,
    $a$if not public.capability_admits(p_workspace_id, 'accountingConnectors') then$a$,
    $a$capability_admits(p_workspace_id, 'accountingConnectors')$a$);
  if v_def is null then raise exception '0692: accounting_connector_actor anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef(
    'public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, integer)'::regprocedure
  ) into v_def;
  v_def := pg_temp.patch(v_def,
    $a$if d.id is null and not public.feature_effective(c.workspace_id, 'accountingConnectors') then$a$,
    $a$if d.id is null and not public.capability_admits(c.workspace_id, 'accountingConnectors') then$a$,
    $a$capability_admits(c.workspace_id, 'accountingConnectors')$a$);
  if v_def is null then raise exception '0692: record_accounting_delivery anchor missing'; end if;
  execute v_def;
end
$migration$;
-- the admission test reads the state after it may have waited for a change:
-- a STABLE caller would read it from the statement's old snapshot
alter function public.accounting_connector_actor(uuid, text) volatile;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(692);
