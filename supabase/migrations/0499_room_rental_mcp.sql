-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0499 (#2568) -- an assistant does not see a room it may not book.
--
-- The MCP reads run as definers, past the restrictive select policies of
-- 0496, so `get_availability` listed every office and level (name, id) and
-- `get_place` answered by id for a room outside the member's audience. Both
-- now treat a hidden room as absent: availability omits it, `get_place`
-- answers not_found. `place_visible_to` is the member-keyed twin of
-- `room_visible` (which reads the signed-in user): the same rule, one source.

create or replace function public.place_visible_to(p_member uuid, p_office uuid, p_level uuid)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_kind text;
  v_rental public.room_rentals;
begin
  if p_office is not null then
    select o.workspace_id, l.kind into v_ws, v_kind
      from public.offices o join public.levels l on l.id = o.level_id where o.id = p_office;
    if v_ws is null then return true; end if;
    select * into v_rental from public.room_rentals where office_id = p_office;
    if v_kind = 'own' and v_rental.id is null then return true; end if;
    if public.has_permission(v_ws, 'manageSites') then return true; end if;
    return v_rental.id is not null and v_rental.status = 'active'
       and public.room_audience_has(v_rental.id, p_member);
  end if;
  select workspace_id, kind into v_ws, v_kind from public.levels where id = p_level;
  if v_ws is null or v_kind = 'own' then return true; end if;
  return public.has_permission(v_ws, 'manageSites')
      or exists (select 1 from public.offices o
                  where o.level_id = p_level and public.place_visible_to(p_member, o.id, null));
end;
$fn$;
revoke execute on function public.place_visible_to(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text, p_new text)
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, p_old, ''))) <> length(p_old) then
    raise exception '0499: the anchor is not in % exactly once', p_proc;
  end if;
  v_next := replace(v_def, p_old, p_new);
  execute v_next;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text, text) from public;

select pg_temp.patch_function('public.mcp_read_v1(uuid, members, text, jsonb)'::regprocedure,
  $a$where (v_kind is null or p.kind = v_kind)$a$,
  $a$where public.place_visible_to(p_member.id, p.office_id, case when p.kind = 'level' then p.level_id end)
               and (v_kind is null or p.kind = v_kind)$a$);

select pg_temp.patch_function('public.mcp_place_v1(uuid, members, jsonb)'::regprocedure,
  $a$if v_level_row.id is null then return jsonb_build_object('refused', 'not_found', 'code', 'not_found'); end if;$a$,
  $a$if v_level_row.id is null
     or not public.place_visible_to(p_member.id, v_office, case when v_office is null then v_level end) then
    return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
  end if;$a$);

select public.set_deskilo_schema_version(499);
