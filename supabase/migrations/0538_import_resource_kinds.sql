-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0538 -- the plan import keeps what kind of place each one is (#2860).
--
-- The workspace XML carried seats, offices and their prices, but a meeting
-- room, a parking bay or a parking area came back from an export as a plain
-- desk seat in a workspace area: `import_floor_plan_v3` (0177, 0363) never
-- read `resource_kind`, `capacity`, `parking_kind`, `slot_minutes` or the
-- office's `area_kind`. Schema v4 of the file writes them; the import now
-- stores them. Absent keys keep today's defaults, so a v3 file imports as
-- before. Anchored, so the rest of the function is untouched.

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
  v_def text := pg_get_functiondef('public.import_floor_plan_v3(uuid, jsonb, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_replace(v_def,
    $a$amenities, blocked_from, blocked_to, nfc_uid)$a$,
    $a$amenities, blocked_from, blocked_to, nfc_uid,
             resource_kind, capacity, parking_kind, slot_minutes)$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$nullif(v_seat->>'nfc_uid', '')$a$,
    $a$nullif(v_seat->>'nfc_uid', ''),
            coalesce(nullif(v_seat->>'resource_kind', ''), 'seat'),
            (v_seat->>'capacity')::int,
            nullif(v_seat->>'parking_kind', ''),
            (v_seat->>'slot_minutes')::int$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$(workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h, price_cents)$a$,
    $a$(workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h, price_cents,
         area_kind)$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$coalesce((v_office->>'price_cents')::int, 0)$a$,
    $a$coalesce((v_office->>'price_cents')::int, 0),
        coalesce(nullif(v_office->>'area_kind', ''), 'workspace')$a$);
  if v_def is null then
    raise exception '0538: an anchor of import_floor_plan_v3 moved';
  end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(538);
