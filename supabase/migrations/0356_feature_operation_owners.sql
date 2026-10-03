-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0356 (#1851 C) -- the remaining operation owners: switching a feature
-- off stops NEW business, and the work it already created can still be
-- cleaned up by the people who could do it before.
--
-- 0324 classified spaceInquiries. Three more gated functions are
-- classified here; each one's class is pinned in
-- lib/features/workspace/domain/feature_operation.dart (the Dart test
-- reads this file):
--
--   * assign_workspace_role (customRoles) -- GIVING a custom role is
--     accept_new; TAKING ONE BACK is service_existing. Before, an owner
--     who switched custom roles off could no longer remove one from a
--     member, so the grant waited, intact, for the switch to come back.
--   * set_seat_block (adminSeatBlocking) -- an admin PLACING a block is
--     accept_new; LIFTING an existing one (both dates null) is
--     service_existing. Before, with the switch off, only the owner could
--     lift a block an admin had placed. The owner's own right is
--     unchanged.
--   * sweep_day_end (autoCheckInOut) -- the day-end job is new automated
--     work: accept_new, explicitly (behaviour unchanged).
--
-- Settlement callbacks (payment webhooks, refunds) carry no feature gate:
-- money already committed is always settled. Flags and maturity never
-- widen who may act: every permission check below is untouched, and a
-- class never opens a path a role could not take.

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

do $patch$
declare
  v_def text; v_patched text; v_missing text[] := '{}';
begin
  -- 'public.assign_workspace_role(': taking a role back services it.
  v_def := pg_get_functiondef('public.assign_workspace_role(uuid, uuid, boolean)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $anchor$if not public.feature_effective(v_subject.workspace_id, 'customRoles') then$anchor$,
    $anchor$if not public.feature_operation_allowed(v_subject.workspace_id, 'customRoles',
       case when p_assign then 'accept_new' else 'service_existing' end) then$anchor$);
  if v_patched is null then v_missing := v_missing || 'assign_workspace_role'::text;
  else execute v_patched; end if;

  -- 'public.set_seat_block(': lifting an existing block services it.
  v_def := pg_get_functiondef('public.set_seat_block(uuid, timestamp with time zone, timestamp with time zone)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $anchor$and public.feature_effective(v_workspace_id, 'adminSeatBlocking')$anchor$,
    $anchor$and public.feature_operation_allowed(v_workspace_id, 'adminSeatBlocking',
        case when p_blocked_from is null and p_blocked_to is null
             then 'service_existing' else 'accept_new' end)$anchor$);
  if v_patched is null then v_missing := v_missing || 'set_seat_block'::text;
  else execute v_patched; end if;

  -- 'public.sweep_day_end(': the day-end job is new automated work.
  v_def := pg_get_functiondef('public.sweep_day_end(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $anchor$if not public.feature_effective(p_workspace_id, 'autoCheckInOut') then$anchor$,
    $anchor$if not public.feature_operation_allowed(p_workspace_id, 'autoCheckInOut', 'accept_new') then$anchor$);
  if v_patched is null then v_missing := v_missing || 'sweep_day_end'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0356: anchors missing in %', v_missing;
  end if;
end
$patch$;

select public.set_deskilo_schema_version(356);
