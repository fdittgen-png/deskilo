-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0496 (#2568) -- a room the space rents from a lessor.
--
-- A level can be `external` (a floor or building the space rents rooms in); a
-- `room_rentals` row says which room of it the space rents from which
-- supplier, from which day to which day (the last day inclusive), and at what
-- cost to the space. `room_rental_audience` says who may book it (a role, a
-- plan or one member) and `room_rental_fees` what each use costs the member
-- (per half day, hour or day, optionally for one audience entry only).
--
-- The rule lives where every booking passes: one BEFORE trigger on
-- `reservations` (create_reservation, create_series, the MCP probe and any
-- direct insert all end there), so there is one refusal wording per cause.
-- Nobody outside the audience sees the room: restrictive select policies on
-- levels, offices, desks and seats hide it, and the rental, its supplier and
-- its cost are readable by the plan's managers and finance readers only.
--
--   set_level_kind_v1          manageSites: own or external
--   save_room_rental_v1        manageSites: the rental of one room
--   set_room_rental_audience_v1 / set_room_rental_fees_v1
--   room_rentals_v1            managers: every rental with its cost
--   room_offer_v1              any member: what THEY would pay, never the cost
--
-- A room in a site of another country than the space is refused until the
-- place-of-supply recharge is wired (#2463, decision 6).

alter table public.levels
  add column kind text not null default 'own' check (kind in ('own', 'external'));
create index levels_external on public.levels (workspace_id) where kind = 'external';

create table public.room_rentals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  office_id uuid not null references public.offices(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id),
  available_from date not null,
  available_until date,
  cost_kind text not null default 'fixed_per_period' check (cost_kind in ('fixed_per_period', 'per_use')),
  cost_cents bigint not null default 0 check (cost_cents >= 0),
  period text not null default 'month' check (period in ('month', 'quarter', 'year')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'draft' check (status in ('draft', 'active', 'ended')),
  document_id uuid references public.workspace_documents(id) on delete set null,
  revision int not null default 1 check (revision >= 1),
  check (available_until is null or available_until >= available_from),
  unique (office_id)
);
select public.ensure_system_columns('room_rentals');
create index room_rentals_workspace on public.room_rentals (workspace_id, status);

create table public.room_rental_audience (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  rental_id uuid not null references public.room_rentals(id) on delete cascade,
  role_id uuid references public.workspace_roles(id) on delete cascade,
  plan_id uuid references public.plans(id) on delete cascade,
  member_id uuid references public.members(id) on delete cascade,
  check (num_nonnulls(role_id, plan_id, member_id) = 1)
);
select public.ensure_system_columns('room_rental_audience');
create index room_rental_audience_rental on public.room_rental_audience (rental_id);

create table public.room_rental_fees (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  rental_id uuid not null references public.room_rentals(id) on delete cascade,
  unit text not null check (unit in ('half_day', 'hour', 'day')),
  fee_cents bigint not null check (fee_cents >= 0),
  role_id uuid references public.workspace_roles(id) on delete cascade,
  plan_id uuid references public.plans(id) on delete cascade,
  member_id uuid references public.members(id) on delete cascade,
  check (num_nonnulls(role_id, plan_id, member_id) <= 1)
);
select public.ensure_system_columns('room_rental_fees');
create index room_rental_fees_rental on public.room_rental_fees (rental_id);

alter table public.room_rentals enable row level security;
alter table public.room_rental_audience enable row level security;
alter table public.room_rental_fees enable row level security;
revoke all on public.room_rentals, public.room_rental_audience, public.room_rental_fees from public, anon, authenticated;
grant select on public.room_rentals, public.room_rental_audience, public.room_rental_fees to authenticated;
create policy room_rentals_select on public.room_rentals for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageSites', 'viewFinances'])));
create policy room_rental_audience_select on public.room_rental_audience for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageSites', 'viewFinances'])));
create policy room_rental_fees_select on public.room_rental_fees for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageSites', 'viewFinances'])));
create policy mcp_delegated_deny on public.room_rentals as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.room_rental_audience as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.room_rental_fees as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── who may book, who may see ─────────────────────────────────────────────
-- Is the member in the rental's audience (their member row, one of their
-- roles, or their plan)?
create or replace function public.room_audience_has(p_rental uuid, p_member uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.room_rental_audience a
     where a.rental_id = p_rental
       and (a.member_id = p_member
            or a.plan_id = (select m.plan_id from public.members m where m.id = p_member)
            or exists (select 1 from public.workspace_role_members rm
                        where rm.member_id = p_member and rm.role_id = a.role_id)));
$fn$;
revoke execute on function public.room_audience_has(uuid, uuid) from public, anon, authenticated;

-- Can the signed-in person see this office (and what is in it)?
create or replace function public.room_visible(p_office uuid)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_kind text;
  v_rental public.room_rentals;
  v_me uuid;
begin
  select o.workspace_id, l.kind into v_ws, v_kind
    from public.offices o join public.levels l on l.id = o.level_id where o.id = p_office;
  if v_ws is null then return true; end if;
  select * into v_rental from public.room_rentals where office_id = p_office;
  if v_kind = 'own' and v_rental.id is null then return true; end if;
  if public.has_permission(v_ws, 'manageSites') then return true; end if;
  if v_rental.id is null or v_rental.status <> 'active' then return false; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = v_ws and m.user_id = auth.uid() and m.status = 'active';
  return v_me is not null and public.room_audience_has(v_rental.id, v_me);
end;
$fn$;
revoke execute on function public.room_visible(uuid) from public, anon;
grant execute on function public.room_visible(uuid) to authenticated;

create or replace function public.level_visible(p_level uuid)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare v_ws uuid; v_kind text;
begin
  select workspace_id, kind into v_ws, v_kind from public.levels where id = p_level;
  if v_ws is null or v_kind = 'own' then return true; end if;
  return public.has_permission(v_ws, 'manageSites')
      or exists (select 1 from public.offices o where o.level_id = p_level and public.room_visible(o.id));
end;
$fn$;
revoke execute on function public.level_visible(uuid) from public, anon;
grant execute on function public.level_visible(uuid) to authenticated;

create policy levels_external_hidden on public.levels as restrictive for select to authenticated
  using (kind = 'own' or public.level_visible(id));
create policy offices_external_hidden on public.offices as restrictive for select to authenticated
  using (public.room_visible(id));
create policy desks_external_hidden on public.desks as restrictive for select to authenticated
  using (public.room_visible(office_id));
-- A seat's room is read past the desks policy: a hidden desk would otherwise
-- make the lookup return nothing, and nothing is "visible".
create or replace function public.desk_room_visible(p_desk uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.room_visible(d.office_id) from public.desks d where d.id = p_desk;
$fn$;
revoke execute on function public.desk_room_visible(uuid) from public, anon;
grant execute on function public.desk_room_visible(uuid) to authenticated;
create policy seats_external_hidden on public.seats as restrictive for select to authenticated
  using (public.desk_room_visible(desk_id));

-- ── the booking guard ─────────────────────────────────────────────────────
create or replace function public.reservation_rental_guard()
returns trigger language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_desk uuid;
  v_office uuid;
  v_level uuid;
  v_kind text;
  v_rental public.room_rentals;
  v_tz text;
  v_first date;
  v_last date;
begin
  if new.status not in ('reserved', 'checked_in') then return new; end if;

  v_desk := coalesce(new.desk_id, (select s.desk_id from public.seats s where s.id = new.seat_id));
  v_office := coalesce(new.office_id, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(new.level_id, (select o.level_id from public.offices o where o.id = v_office));
  select l.kind into v_kind from public.levels l where l.id = v_level;
  if v_kind is null or v_kind = 'own' then
    -- an own level may still hold a rental row (never created, but be exact)
    if v_office is null or not exists (select 1 from public.room_rentals r where r.office_id = v_office) then
      return new;
    end if;
  end if;

  if new.level_id is not null then
    raise exception 'a rented room is booked room by room, not as a whole level';
  end if;
  select * into v_rental from public.room_rentals r where r.office_id = v_office;
  if v_rental.id is null or v_rental.status <> 'active' then
    raise exception 'that room is not rented';
  end if;

  select w.timezone into v_tz from public.workspaces w where w.id = new.workspace_id;
  v_first := (new.starts_at at time zone v_tz)::date;
  v_last := ((new.ends_at - interval '1 second') at time zone v_tz)::date;
  if v_first < v_rental.available_from then
    raise exception 'that room is available from %', to_char(v_rental.available_from, 'YYYY-MM-DD');
  end if;
  if v_rental.available_until is not null and v_last > v_rental.available_until then
    raise exception 'that room is available until %', to_char(v_rental.available_until, 'YYYY-MM-DD');
  end if;
  if not public.room_audience_has(v_rental.id, new.member_id) then
    raise exception 'that room is not open to you';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.reservation_rental_guard() from public, anon, authenticated;
drop trigger if exists reservation_rental_guard on public.reservations;
create trigger reservation_rental_guard
  before insert or update of starts_at, ends_at, status, seat_id, desk_id, office_id, level_id, member_id
  on public.reservations
  for each row execute function public.reservation_rental_guard();

-- ── the commands ──────────────────────────────────────────────────────────
create or replace function public.room_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'externalRooms') then
    raise exception 'rented rooms are switched off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'manageSites') then
    raise exception 'you may not manage rented rooms';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.room_actor(uuid) from public, anon, authenticated;

create or replace function public.set_level_kind_v1(p_workspace_id uuid, p_level_id uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare l public.levels;
begin
  perform public.room_actor(p_workspace_id);
  if p_kind not in ('own', 'external') then raise exception 'the kind is own or external'; end if;
  select * into l from public.levels where id = p_level_id and workspace_id = p_workspace_id for update;
  if l.id is null then raise exception 'unknown level'; end if;
  if l.kind <> p_kind then
    if p_kind = 'own' and exists (
        select 1 from public.room_rentals r join public.offices o on o.id = r.office_id
         where o.level_id = l.id) then
      raise exception 'end the rentals of this level first';
    end if;
    if p_kind = 'external' and exists (
        select 1 from public.reservations v
         where v.workspace_id = p_workspace_id and v.status in ('reserved', 'checked_in')
           and v.ends_at > now()
           and coalesce(v.level_id, (select o.level_id from public.offices o where o.id =
                 coalesce(v.office_id, (select d.office_id from public.desks d where d.id =
                   coalesce(v.desk_id, (select s.desk_id from public.seats s where s.id = v.seat_id)))))) = l.id) then
      raise exception 'cancel the upcoming bookings of this level first';
    end if;
    update public.levels set kind = p_kind where id = l.id;
  end if;
  return jsonb_build_object('level_id', l.id, 'kind', p_kind);
end;
$fn$;
revoke execute on function public.set_level_kind_v1(uuid, uuid, text) from public, anon;
grant execute on function public.set_level_kind_v1(uuid, uuid, text) to authenticated;

create or replace function public.room_rental_json(r public.room_rentals)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', r.id, 'revision', r.revision, 'office_id', r.office_id,
    'office_name', (select o.name from public.offices o where o.id = r.office_id),
    'supplier_id', r.supplier_id,
    'supplier_name', (select s.name from public.suppliers s where s.id = r.supplier_id),
    'available_from', r.available_from, 'available_until', r.available_until,
    'cost_kind', r.cost_kind, 'cost_cents', r.cost_cents, 'period', r.period,
    'currency', r.currency, 'status', r.status, 'document_id', r.document_id,
    'audience', coalesce((select jsonb_agg(jsonb_build_object('role_id', a.role_id, 'plan_id', a.plan_id, 'member_id', a.member_id))
                            from public.room_rental_audience a where a.rental_id = r.id), '[]'::jsonb),
    'fees', coalesce((select jsonb_agg(jsonb_build_object('unit', f.unit, 'fee_cents', f.fee_cents,
                            'role_id', f.role_id, 'plan_id', f.plan_id, 'member_id', f.member_id) order by f.unit)
                        from public.room_rental_fees f where f.rental_id = r.id), '[]'::jsonb));
$fn$;
revoke execute on function public.room_rental_json(public.room_rentals) from public, anon, authenticated;

create or replace function public.save_room_rental_v1(
  p_workspace_id uuid, p_office_id uuid, p_supplier_id uuid, p_available_from date,
  p_available_until date, p_cost_kind text, p_cost_cents bigint, p_period text,
  p_status text, p_document_id uuid, p_revision int
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  o public.offices;
  l public.levels;
  r public.room_rentals;
  v_ws_country text;
  v_ws_currency text;
  v_site_country text;
begin
  perform public.room_actor(p_workspace_id);
  perform pg_advisory_xact_lock(hashtext('room-rental:' || p_workspace_id));
  select * into o from public.offices where id = p_office_id and workspace_id = p_workspace_id;
  if o.id is null then raise exception 'unknown room'; end if;
  select * into l from public.levels where id = o.level_id;
  if l.kind <> 'external' then raise exception 'a rented room sits on an external level'; end if;
  if not exists (select 1 from public.suppliers s where s.id = p_supplier_id
                  and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'unknown lessor';
  end if;
  if p_document_id is not null and not exists (
      select 1 from public.workspace_documents d where d.id = p_document_id and d.workspace_id = p_workspace_id) then
    raise exception 'unknown contract document';
  end if;
  if p_available_from is null then raise exception 'say from which day the room is rented'; end if;
  if p_available_until is not null and p_available_until < p_available_from then
    raise exception 'the rental cannot end before it starts';
  end if;
  if coalesce(p_status, 'draft') not in ('draft', 'active', 'ended') then raise exception 'unknown status'; end if;
  if coalesce(p_cost_kind, 'fixed_per_period') not in ('fixed_per_period', 'per_use') then raise exception 'unknown cost kind'; end if;
  if coalesce(p_period, 'month') not in ('month', 'quarter', 'year') then raise exception 'unknown period'; end if;
  if coalesce(p_cost_cents, 0) < 0 then raise exception 'the cost cannot be negative'; end if;

  select w.country_code, w.currency_code into v_ws_country, v_ws_currency
    from public.workspaces w where w.id = p_workspace_id;
  select s.country_code into v_site_country from public.sites s where s.id = l.site_id;
  if coalesce(v_site_country, '') <> '' and upper(v_site_country) <> upper(coalesce(v_ws_country, '')) then
    raise exception 'a room in another country than the space is not supported yet';
  end if;

  select * into r from public.room_rentals where office_id = o.id for update;
  if r.id is null then
    insert into public.room_rentals
      (workspace_id, office_id, supplier_id, available_from, available_until, cost_kind, cost_cents,
       period, currency, status, document_id)
    values (p_workspace_id, o.id, p_supplier_id, p_available_from, p_available_until,
            coalesce(p_cost_kind, 'fixed_per_period'), coalesce(p_cost_cents, 0), coalesce(p_period, 'month'),
            v_ws_currency, coalesce(p_status, 'draft'), p_document_id)
    returning * into r;
  else
    if r.revision <> coalesce(p_revision, 0) then raise exception 'the rental changed meanwhile'; end if;
    update public.room_rentals
       set supplier_id = p_supplier_id, available_from = p_available_from, available_until = p_available_until,
           cost_kind = coalesce(p_cost_kind, cost_kind), cost_cents = coalesce(p_cost_cents, cost_cents),
           period = coalesce(p_period, period), status = coalesce(p_status, status),
           document_id = p_document_id, revision = revision + 1
     where id = r.id returning * into r;
  end if;
  return public.room_rental_json(r);
end;
$fn$;
revoke execute on function public.save_room_rental_v1(uuid, uuid, uuid, date, date, text, bigint, text, text, uuid, int) from public, anon;
grant execute on function public.save_room_rental_v1(uuid, uuid, uuid, date, date, text, bigint, text, text, uuid, int) to authenticated;

-- audience: [{"role_id":..}|{"plan_id":..}|{"member_id":..}, ...] replaces the list.
create or replace function public.set_room_rental_audience_v1(p_workspace_id uuid, p_rental_id uuid, p_audience jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare r public.room_rentals; e jsonb;
begin
  perform public.room_actor(p_workspace_id);
  select * into r from public.room_rentals where id = p_rental_id and workspace_id = p_workspace_id for update;
  if r.id is null then raise exception 'unknown rental'; end if;
  if jsonb_typeof(coalesce(p_audience, '[]'::jsonb)) <> 'array' then raise exception 'the audience is a list'; end if;
  delete from public.room_rental_audience where rental_id = r.id;
  for e in select * from jsonb_array_elements(coalesce(p_audience, '[]'::jsonb)) loop
    if num_nonnulls(e->>'role_id', e->>'plan_id', e->>'member_id') <> 1 then
      raise exception 'each audience entry names one role, one plan or one member';
    end if;
    if (e->>'role_id') is not null and not exists (select 1 from public.workspace_roles x where x.id = (e->>'role_id')::uuid and x.workspace_id = p_workspace_id)
       or (e->>'plan_id') is not null and not exists (select 1 from public.plans x where x.id = (e->>'plan_id')::uuid and x.workspace_id = p_workspace_id)
       or (e->>'member_id') is not null and not exists (select 1 from public.members x where x.id = (e->>'member_id')::uuid and x.workspace_id = p_workspace_id) then
      raise exception 'an audience entry is not of this space';
    end if;
    insert into public.room_rental_audience (workspace_id, rental_id, role_id, plan_id, member_id)
    values (p_workspace_id, r.id, (e->>'role_id')::uuid, (e->>'plan_id')::uuid, (e->>'member_id')::uuid);
  end loop;
  update public.room_rentals set revision = revision + 1 where id = r.id returning * into r;
  return public.room_rental_json(r);
end;
$fn$;
revoke execute on function public.set_room_rental_audience_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.set_room_rental_audience_v1(uuid, uuid, jsonb) to authenticated;

-- fees: [{"unit":"half_day","fee_cents":1500,"role_id"|"plan_id"|"member_id": optional}, ...]
create or replace function public.set_room_rental_fees_v1(p_workspace_id uuid, p_rental_id uuid, p_fees jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare r public.room_rentals; e jsonb;
begin
  perform public.room_actor(p_workspace_id);
  select * into r from public.room_rentals where id = p_rental_id and workspace_id = p_workspace_id for update;
  if r.id is null then raise exception 'unknown rental'; end if;
  if jsonb_typeof(coalesce(p_fees, '[]'::jsonb)) <> 'array' then raise exception 'the fees are a list'; end if;
  delete from public.room_rental_fees where rental_id = r.id;
  for e in select * from jsonb_array_elements(coalesce(p_fees, '[]'::jsonb)) loop
    if (e->>'unit') not in ('half_day', 'hour', 'day') then raise exception 'unknown fee unit'; end if;
    if coalesce((e->>'fee_cents')::bigint, -1) < 0 then raise exception 'a fee is zero or more'; end if;
    if num_nonnulls(e->>'role_id', e->>'plan_id', e->>'member_id') > 1 then
      raise exception 'a fee names at most one role, plan or member';
    end if;
    insert into public.room_rental_fees (workspace_id, rental_id, unit, fee_cents, role_id, plan_id, member_id)
    values (p_workspace_id, r.id, e->>'unit', (e->>'fee_cents')::bigint,
            (e->>'role_id')::uuid, (e->>'plan_id')::uuid, (e->>'member_id')::uuid);
  end loop;
  update public.room_rentals set revision = revision + 1 where id = r.id returning * into r;
  return public.room_rental_json(r);
end;
$fn$;
revoke execute on function public.set_room_rental_fees_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.set_room_rental_fees_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.room_rentals_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not public.feature_effective(p_workspace_id, 'externalRooms') then
    raise exception 'rented rooms are switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'manageSites') or public.has_permission(p_workspace_id, 'viewFinances')) then
    raise exception 'you may not read the rentals';
  end if;
  return jsonb_build_object('rentals', coalesce((
    select jsonb_agg(public.room_rental_json(r) order by r.available_from, r.id)
      from public.room_rentals r where r.workspace_id = p_workspace_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.room_rentals_v1(uuid) from public, anon;
grant execute on function public.room_rentals_v1(uuid) to authenticated;

-- What the caller would pay for one use of a room, and until when it is
-- rented: never the cost to the space, the lessor or the contract. A fee
-- aimed at the caller's own member, then role, then plan wins over the
-- general one; none at all is null.
create or replace function public.room_offer_v1(p_workspace_id uuid, p_office_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare r public.room_rentals; v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  select * into r from public.room_rentals where office_id = p_office_id and workspace_id = p_workspace_id;
  if r.id is null or r.status <> 'active' or not public.room_audience_has(r.id, v_me) then
    raise exception 'that room is not open to you';
  end if;
  return jsonb_build_object(
    'office_id', r.office_id, 'available_from', r.available_from, 'available_until', r.available_until,
    'currency', r.currency,
    'fees', coalesce((
      select jsonb_agg(jsonb_build_object('unit', pick.unit, 'fee_cents', pick.fee_cents) order by pick.unit)
        from (
          select distinct on (f.unit) f.unit, f.fee_cents
            from public.room_rental_fees f
           where f.rental_id = r.id
             and (f.member_id = v_me
                  or f.plan_id = (select m.plan_id from public.members m where m.id = v_me)
                  or exists (select 1 from public.workspace_role_members rm where rm.member_id = v_me and rm.role_id = f.role_id)
                  or num_nonnulls(f.member_id, f.plan_id, f.role_id) = 0)
           order by f.unit, (f.member_id is not null) desc, (f.role_id is not null) desc,
                    (f.plan_id is not null) desc
        ) pick), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.room_offer_v1(uuid, uuid) from public, anon;
grant execute on function public.room_offer_v1(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(496);
