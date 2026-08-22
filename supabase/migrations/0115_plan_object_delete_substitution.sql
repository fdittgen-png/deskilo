-- SPDX-License-Identifier: 0BSD
-- #587 — owner-only delete of plan objects despite past reservations,
-- with an audit substitution text.
--
-- Until now the RESTRICT foreign keys on reservations (seat 0005,
-- office 0005, level 0050, desk 0059) blocked deleting any plan object
-- that a reservation ever referenced. delete_plan_object() unblocks the
-- OWNER: before the object (and its cascade subtree) is removed, every
-- referencing reservation gets a substitution snapshot — the
-- human-readable chain workspace · level · room · table · chair up to
-- the reservation target's depth — written into the new
-- reservations.space_label column, and its foreign key detached. Past
-- reservations and check-ins stay traceable in reports, audits and
-- printed documents through that text; still-RESERVED bookings of a
-- space that no longer exists are cancelled (their slot cannot be sat
-- in), checked-in/completed rows keep their status untouched.
--
-- The planObjectDelete feature flag (defaultOn: true — server mirror:
-- absent means ON) gates the substitution path: switched off, the
-- function refuses to delete a referenced object exactly like the old
-- RESTRICT behaviour, so the flag degrades honestly.
--
-- The RESTRICT foreign keys stay: raw table deletes that skipped the
-- snapshot would still be blocked — this RPC is the only unblocked
-- path.

-- 1. The substitution snapshot column.
alter table public.reservations
  add column if not exists space_label text;

-- 2. A reservation now targets exactly one live plan object OR carries
--    the substitution snapshot of a deleted one.
alter table public.reservations drop constraint reservations_one_target;
alter table public.reservations add constraint reservations_one_target check (
  (case when seat_id is null then 0 else 1 end
   + case when desk_id is null then 0 else 1 end
   + case when office_id is null then 0 else 1 end
   + case when level_id is null then 0 else 1 end) = 1
  or (seat_id is null and desk_id is null and office_id is null
      and level_id is null and space_label is not null)
);

-- 3. The owner-only delete with substitution.
create or replace function public.delete_plan_object(p_kind text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_workspace_id uuid;
  v_enabled boolean;
  v_referenced boolean;
  v_level_ids uuid[] := '{}';
  v_office_ids uuid[] := '{}';
  v_desk_ids uuid[] := '{}';
  v_seat_ids uuid[] := '{}';
begin
  -- Resolve the object and its workspace; owner-only.
  if p_kind = 'seat' then
    select workspace_id into v_workspace_id from public.seats where id = p_id;
  elsif p_kind = 'desk' then
    select workspace_id into v_workspace_id from public.desks where id = p_id;
  elsif p_kind = 'office' then
    select workspace_id into v_workspace_id from public.offices where id = p_id;
  elsif p_kind = 'level' then
    select workspace_id into v_workspace_id from public.levels where id = p_id;
  else
    raise exception 'unknown plan object kind';
  end if;
  if v_workspace_id is null then
    raise exception 'unknown plan object';
  end if;
  if not public.is_owner_of(v_workspace_id) then
    raise exception 'owner only';
  end if;

  -- Server mirror of the client registry default (ON unless the owner
  -- switched it off) — the levelBooking idiom of 0050, inverted default.
  select coalesce(w.feature_flags -> 'planObjectDelete' <> to_jsonb(false), true)
    into v_enabled from public.workspaces w where w.id = v_workspace_id;

  -- The deleted subtree, root included, per object type — childless
  -- branches stay covered because each list is derived from its parent
  -- list, never from a join through the leaves.
  if p_kind = 'level' then
    v_level_ids := array[p_id];
    select coalesce(array_agg(id), '{}') into v_office_ids
      from public.offices where level_id = p_id;
  elsif p_kind = 'office' then
    v_office_ids := array[p_id];
  end if;
  if p_kind = 'desk' then
    v_desk_ids := array[p_id];
  elsif cardinality(v_office_ids) > 0 then
    select coalesce(array_agg(id), '{}') into v_desk_ids
      from public.desks where office_id = any(v_office_ids);
  end if;
  if p_kind = 'seat' then
    v_seat_ids := array[p_id];
  elsif cardinality(v_desk_ids) > 0 then
    select coalesce(array_agg(id), '{}') into v_seat_ids
      from public.seats where desk_id = any(v_desk_ids);
  end if;

  select exists (
    select 1 from public.reservations r
     where r.seat_id = any(v_seat_ids)
        or r.desk_id = any(v_desk_ids)
        or r.office_id = any(v_office_ids)
        or r.level_id = any(v_level_ids)
  ) into v_referenced;

  if v_referenced and not v_enabled then
    -- Honest degrade: the flag off keeps the historic RESTRICT refusal.
    raise exception 'plan object has reservations';
  end if;

  -- Snapshot + detach. Each reservation's label is ITS OWN target's
  -- chain at delete time, ' · '-separated, up to the target's depth.
  update public.reservations r
     set space_label = w.name || ' · ' || l.name || ' · ' || o.name
                       || ' · ' || d.name || ' · ' || s.name,
         seat_id = null,
         status = case when r.status = 'reserved' then 'cancelled'
                       else r.status end
    from public.seats s
    join public.desks d on d.id = s.desk_id
    join public.offices o on o.id = d.office_id
    join public.levels l on l.id = o.level_id
    join public.workspaces w on w.id = s.workspace_id
   where r.seat_id = s.id and s.id = any(v_seat_ids);

  update public.reservations r
     set space_label = w.name || ' · ' || l.name || ' · ' || o.name
                       || ' · ' || d.name,
         desk_id = null,
         status = case when r.status = 'reserved' then 'cancelled'
                       else r.status end
    from public.desks d
    join public.offices o on o.id = d.office_id
    join public.levels l on l.id = o.level_id
    join public.workspaces w on w.id = d.workspace_id
   where r.desk_id = d.id and d.id = any(v_desk_ids);

  update public.reservations r
     set space_label = w.name || ' · ' || l.name || ' · ' || o.name,
         office_id = null,
         status = case when r.status = 'reserved' then 'cancelled'
                       else r.status end
    from public.offices o
    join public.levels l on l.id = o.level_id
    join public.workspaces w on w.id = o.workspace_id
   where r.office_id = o.id and o.id = any(v_office_ids);

  update public.reservations r
     set space_label = w.name || ' · ' || l.name,
         level_id = null,
         status = case when r.status = 'reserved' then 'cancelled'
                       else r.status end
    from public.levels l
    join public.workspaces w on w.id = l.workspace_id
   where r.level_id = l.id and l.id = any(v_level_ids);

  -- Nothing references the subtree any more — the cascades may run.
  if p_kind = 'seat' then
    delete from public.seats where id = p_id;
  elsif p_kind = 'desk' then
    delete from public.desks where id = p_id;
  elsif p_kind = 'office' then
    delete from public.offices where id = p_id;
  else
    delete from public.levels where id = p_id;
  end if;
end;
$$;
revoke execute on function public.delete_plan_object(text, uuid)
  from public, anon;
