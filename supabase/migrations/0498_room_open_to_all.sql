-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0498 (#2568) -- a room open to every member.
--
-- A space without roles or plans to name still needs to open a rented room to
-- its members: `room_rentals.audience_all` says every ACTIVE member may book
-- it (and sees it). Named entries still add to it. The default stays closed:
-- a rental is opened on purpose.

alter table public.room_rentals add column audience_all boolean not null default false;

create or replace function public.room_audience_has(p_rental uuid, p_member uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.room_rentals r
                  where r.id = p_rental and r.audience_all
                    and exists (select 1 from public.members m where m.id = p_member and m.status = 'active'))
      or exists (
    select 1 from public.room_rental_audience a
     where a.rental_id = p_rental
       and (a.member_id = p_member
            or a.plan_id = (select m.plan_id from public.members m where m.id = p_member)
            or exists (select 1 from public.workspace_role_members rm
                        where rm.member_id = p_member and rm.role_id = a.role_id)));
$fn$;

create or replace function public.room_rental_json(r public.room_rentals)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', r.id, 'revision', r.revision, 'office_id', r.office_id,
    'office_name', (select o.name from public.offices o where o.id = r.office_id),
    'supplier_id', r.supplier_id,
    'supplier_name', (select s.name from public.suppliers s where s.id = r.supplier_id),
    'available_from', r.available_from, 'available_until', r.available_until,
    'cost_kind', r.cost_kind, 'cost_cents', r.cost_cents, 'period', r.period,
    'currency', r.currency, 'status', r.status, 'audience_all', r.audience_all, 'document_id', r.document_id,
    'audience', coalesce((select jsonb_agg(jsonb_build_object('role_id', a.role_id, 'plan_id', a.plan_id, 'member_id', a.member_id))
                            from public.room_rental_audience a where a.rental_id = r.id), '[]'::jsonb),
    'fees', coalesce((select jsonb_agg(jsonb_build_object('unit', f.unit, 'fee_cents', f.fee_cents,
                            'role_id', f.role_id, 'plan_id', f.plan_id, 'member_id', f.member_id) order by f.unit)
                        from public.room_rental_fees f where f.rental_id = r.id), '[]'::jsonb));
$fn$;

drop function if exists public.save_room_rental_v1(uuid, uuid, uuid, date, date, text, bigint, text, text, uuid, int);

create or replace function public.save_room_rental_v1(
  p_workspace_id uuid, p_office_id uuid, p_supplier_id uuid, p_available_from date,
  p_available_until date, p_cost_kind text, p_cost_cents bigint, p_period text,
  p_status text, p_document_id uuid, p_revision int, p_audience_all boolean default false
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
       period, currency, status, document_id, audience_all)
    values (p_workspace_id, o.id, p_supplier_id, p_available_from, p_available_until,
            coalesce(p_cost_kind, 'fixed_per_period'), coalesce(p_cost_cents, 0), coalesce(p_period, 'month'),
            v_ws_currency, coalesce(p_status, 'draft'), p_document_id, coalesce(p_audience_all, false))
    returning * into r;
  else
    if r.revision <> coalesce(p_revision, 0) then raise exception 'the rental changed meanwhile'; end if;
    update public.room_rentals
       set supplier_id = p_supplier_id, available_from = p_available_from, available_until = p_available_until,
           cost_kind = coalesce(p_cost_kind, cost_kind), cost_cents = coalesce(p_cost_cents, cost_cents),
           period = coalesce(p_period, period), status = coalesce(p_status, status),
           document_id = p_document_id, audience_all = coalesce(p_audience_all, audience_all), revision = revision + 1
     where id = r.id returning * into r;
  end if;
  return public.room_rental_json(r);
end;
$fn$;

revoke execute on function public.room_audience_has(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.room_rental_json(public.room_rentals) from public, anon, authenticated;
revoke execute on function public.save_room_rental_v1(uuid, uuid, uuid, date, date, text, bigint, text, text, uuid, int, boolean) from public, anon;
grant execute on function public.save_room_rental_v1(uuid, uuid, uuid, date, date, text, bigint, text, text, uuid, int, boolean) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(498);
