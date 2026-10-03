-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0364 (#2137) -- manageReservations, given through a role, works.
--
-- Cancelling, checking in or out for someone else, converting to a series,
-- the shared calendar and seat blocks already ask manageReservations. The
-- doors below still asked "is admin or owner", so a member who holds the
-- permission only through one of the workspace's own roles was refused:
--
--   * admin_create_reservation_for -- booking for another member;
--   * create_reservation, create_series -- the whole-level bypass for
--     staff (a member without can_reserve_level still may not);
--   * set_member_level_permission, set_member_reservation_limit,
--     set_member_simultaneous_limit -- a member's booking allowances
--     (never your own: that rule stays).
--
-- Additive: the owner and the Administrator pass exactly as before; the
-- permission is a third way through. Every other check in these bodies
-- (adminLevelAssign for assigning a level, the booking rules, the quota,
-- blocked seats) is untouched.
--
-- Anchored patches: each anchor is asserted, and a body whose anchor is
-- missing fails the migration rather than being skipped.

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
  v_patched text;
  v_missing text[] := '{}';
  v_fn text;
  -- The staff door of a member lookup: admin, owner, or the permission.
  c_actor_old constant text :=
    $a$and status = 'active' and (is_admin or is_owner);$a$;
  c_actor_new constant text :=
    $a$and status = 'active' and (is_admin or is_owner
          or public.member_has_permission(members.id, 'manageReservations'));$a$;
  -- The whole-level bypass: may reserve a level, owner, admin, or the
  -- permission.
  c_level_old constant text := $a$or v_member.is_admin) then$a$;
  c_level_new constant text :=
    $a$or v_member.is_admin
                or public.member_has_permission(v_member.id, 'manageReservations')) then$a$;
begin
  foreach v_fn in array array[
    'public.admin_create_reservation_for(uuid, uuid, uuid, timestamptz, timestamptz, uuid)',
    'public.set_member_level_permission(uuid, boolean)',
    'public.set_member_reservation_limit(uuid, integer)',
    'public.set_member_simultaneous_limit(uuid, integer)'
  ] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    v_patched := pg_temp.anchor_replace(v_def, c_actor_old, c_actor_new);
    if v_patched is null then v_missing := v_missing || v_fn;
    else execute v_patched; end if;
  end loop;

  foreach v_fn in array array[
    'public.create_reservation(uuid, uuid, uuid, timestamptz, timestamptz, boolean, uuid, uuid)',
    'public.create_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz, uuid, uuid, uuid)'
  ] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    v_patched := pg_temp.anchor_replace(v_def, c_level_old, c_level_new);
    if v_patched is null then v_missing := v_missing || v_fn;
    else execute v_patched; end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception '0364: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(364);
