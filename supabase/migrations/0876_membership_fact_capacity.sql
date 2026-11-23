-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (membership_fact_enqueue and membership_fact_drain are patched at asserted anchors; one setting,
--  one index and one reader are added; no stored data moves)
--
-- #4327 -- membership fact renewals keep up on a host with many relationships.
--
-- A server renews each live relationship once per `identity.status_reconcile_seconds` and the drain
-- sent a literal 200 events a minute: 1 000 per default period, so a host with more relationships
-- built a backlog, events expired unsent after 900 seconds, and the facts at the personal home passed
-- their deadline for people whose membership had not changed.
--
--   * The drain's batch is the platform setting `federation.fact_drain_batch` (500, 50..2000), read
--     through `membership_fact_drain_batch()`. The capacity is stated in its note: the batch times the
--     refresh period in seconds divided by 60 relationships per period (default: 2 500).
--   * A renewal is not queued again while an earlier event for the SAME assertion (same revision) is
--     still waiting to be sent: the queue holds at most one waiting event per live relationship, so it
--     cannot grow beyond the relationships and keeps its first-come order. A changed relationship (a
--     new revision) is queued as before.
--   * `membership_fact_backlog()` tells the instance doctor how many events wait longer than one
--     refresh period (a drain that does not keep up), how many wait, how many relationships are live
--     and the capacity of one period.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('federation.fact_drain_batch', 'int', '500'::jsonb, 50, 2000, 'entries', 'security', array['platform'], 'workspaceSettings', null, true, null, 'membership fact drain (#4327)', 'The most membership facts a workspace server sends to its personal home in one minute. A server renews each live relationship once per identity status refresh period, so it keeps up with at most this number times the period in seconds divided by 60 relationships (500 and 300 seconds: 2 500). Raise it when the instance doctor reports a delivery backlog.')
on conflict (key) do nothing;
-- END GENERATED SEED

create index if not exists membership_fact_outbox_waiting
  on public.membership_fact_outbox (issuer, subject, network_id, revision) where state = 'pending';

create or replace function public.membership_fact_drain_batch()
returns int language sql stable security definer set search_path = public as $fn$
  select (public.setting_value(null, 'federation.fact_drain_batch') #>> '{}')::int;
$fn$;
revoke execute on function public.membership_fact_drain_batch() from public, anon, authenticated, service_role;

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

-- restates 0574
do $patch$
declare
  v_def text := pg_get_functiondef('public.membership_fact_enqueue(public.membership_fact_state)'::regprocedure);
  v_old text := $o$  if v_home.home_installation_id is null then
    return 0;
  end if;$o$;
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, 'v_home.home_installation_id is null', ''))) / length('v_home.home_installation_id is null') <> 1 then
    raise exception '0876: the home check of membership_fact_enqueue is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := pg_temp.anchor_replace(v_def, v_old, v_old || $n$

  -- A renewal waits behind the event of the same assertion that has not been sent yet.
  if exists (select 1 from public.membership_fact_outbox o
              where o.issuer = p_state.issuer and o.subject = p_state.subject
                and o.network_id = p_state.network_id and o.revision = p_state.revision
                and o.state = 'pending') then
    return 0;
  end if;$n$);
  if v_next is null then raise exception '0876: the anchor of membership_fact_enqueue is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- restates 0579
do $patch$
declare
  v_def text := pg_get_functiondef('public.membership_fact_drain()'::regprocedure);
  v_old text := $o$where state = 'pending' order by asserted_at limit 200 for update skip locked$o$;
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, 'limit 200', ''))) / length('limit 200') <> 1 then
    raise exception '0876: the batch of membership_fact_drain is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := pg_temp.anchor_replace(v_def, v_old,
    $n$where state = 'pending' order by asserted_at limit public.membership_fact_drain_batch() for update skip locked$n$);
  if v_next is null then raise exception '0876: the anchor of membership_fact_drain is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- 'overdue|waiting|live|capacity': the events waiting longer than one refresh period, all that
-- wait, the live relationships, and what one period delivers.
create or replace function public.membership_fact_backlog()
returns text language sql stable security definer set search_path = public as $fn$
  select concat_ws('|',
    (select count(*) from public.membership_fact_outbox
      where state = 'pending'
        and asserted_at <= now() - make_interval(secs =>
          (public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int)),
    (select count(*) from public.membership_fact_outbox where state = 'pending'),
    (select count(*) from public.membership_fact_state where status <> 'tombstone'),
    public.membership_fact_drain_batch() *
      ((public.setting_value(null, 'identity.status_reconcile_seconds') #>> '{}')::int / 60));
$fn$;
revoke execute on function public.membership_fact_backlog() from public, anon, authenticated, service_role;

select public.set_deskilo_schema_version(876);
