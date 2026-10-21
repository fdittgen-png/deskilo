-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0515 (#2575) -- a room the space rents is a purchasing commitment, like
-- the lease: its fixed cost per period becomes a workspace-contract
-- schedule (0474) whose occurrences are EXPECTED obligations, and the
-- lessor's bill is matched to them with the same matching (0479).
--
--   * `room_rental_commitment_sync` (trigger on room_rentals): an active
--     rental with a fixed cost per period keeps exactly one live schedule,
--     contract_id = the rental, supplier = its lessor. A changed cost or
--     period ends the live schedule (history and its matches stay as they
--     are) and starts a new one from today; a changed end date moves the
--     end; a rental that is ended, back to draft, per use or free ends it.
--     The schedule is the space's, never a member's outlay; the member
--     column names who set it up (the person saving, else the owner).
--   * `match_purchase_commitments_v1`: also while `externalRooms` is on,
--     not only `premisesLease` (anchored patch of the feature gate).
--   * `purchase_commitment_page_v1`: the occurrences of any workspace
--     contract by its id, a lease or a rented room; a lease's term columns
--     as before, a room's from its schedule.

create or replace function public.room_rental_commitment_sync()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_due boolean := new.status = 'active' and new.cost_kind = 'fixed_per_period' and new.cost_cents > 0;
  v_unit text := case new.period when 'year' then 'year' else 'month' end;
  v_every int := case new.period when 'quarter' then 3 else 1 end;
  s public.expense_schedules;
  v_from date;
  v_member uuid;
  v_title text;
begin
  select * into s from public.expense_schedules
   where origin = 'workspace_contract' and contract_id = new.id and status in ('pending', 'active')
   order by starts_on desc limit 1;
  if s.id is not null and v_due and s.amount_cents = new.cost_cents and s.unit = v_unit
     and s.every = v_every then
    -- Same terms: only the end may move.
    update public.expense_schedules
       set ends_on = case when new.available_until is null or new.available_until >= starts_on
                          then new.available_until else starts_on end
     where id = s.id;
    return new;
  end if;
  if s.id is not null then
    -- Changed or no longer due: what was generated stays, nothing more is.
    update public.expense_schedules
       set status = 'ended', next_due = null,
           ends_on = greatest(starts_on, least(coalesce(ends_on, current_date - 1), current_date - 1))
     where id = s.id;
  end if;
  if not v_due then return new; end if;
  v_from := case when s.id is null then new.available_from
                 else greatest(new.available_from, current_date) end;
  if new.available_until is not null and new.available_until < v_from then return new; end if;
  select m.id into v_member from public.members m
   where m.workspace_id = new.workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_member is null then
    select m.id into v_member from public.members m
     where m.workspace_id = new.workspace_id and m.is_owner order by m.id limit 1;
  end if;
  if v_member is null then return new; end if;
  select left('Room rent — ' || btrim(o.name) || ' — ' || sp.name, 80) into v_title
    from public.offices o, public.suppliers sp
   where o.id = new.office_id and sp.id = new.supplier_id;
  insert into public.expense_schedules
    (workspace_id, member_id, supplier_id, title, description, amount_cents, starts_on, ends_on,
     unit, every, status, next_due, origin, contract_id)
  values (new.workspace_id, v_member, new.supplier_id, coalesce(v_title, 'Room rent'), '',
          new.cost_cents::int, v_from, new.available_until, v_unit, v_every, 'active', v_from,
          'workspace_contract', new.id);
  return new;
end;
$fn$;
revoke execute on function public.room_rental_commitment_sync() from public, anon, authenticated;

drop trigger if exists room_rental_commitment_sync on public.room_rentals;
create trigger room_rental_commitment_sync
  after insert or update of status, cost_kind, cost_cents, period, available_from, available_until, supplier_id
  on public.room_rentals
  for each row execute function public.room_rental_commitment_sync();

-- The bill of a rented room's lessor is matched like the lease's.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

do $migration$
declare
  v_def text;
begin
  v_def := pg_temp.anchor_replace(
    pg_get_functiondef('public.match_purchase_commitments_v1(uuid, uuid, integer, jsonb, uuid)'::regprocedure),
    $a$     or not public.feature_effective(p_workspace_id, 'premisesLease') then$a$,
    $a$     or not (public.feature_effective(p_workspace_id, 'premisesLease')
             or public.feature_effective(p_workspace_id, 'externalRooms')) then$a$);
  if v_def is null then raise exception '0515: match_purchase_commitments_v1 anchor missing'; end if;
  execute v_def;
end
$migration$;

create or replace function public.purchase_commitment_page_v1(
  p_workspace_id uuid, p_lease_id uuid, p_before date default null, p_limit int default 24
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
  v_next date;
  v_limit int := least(greatest(coalesce(p_limit, 24), 1), 100);
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members mem
                  where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid()
                    and mem.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not (public.has_permission(p_workspace_id, 'viewFinances')
          or public.has_permission(p_workspace_id, 'managePurchases')
          or public.has_permission(p_workspace_id, 'manageLease')) then
    raise exception 'you may not read the commitments';
  end if;
  -- p_lease_id names a workspace contract: a lease, or (0515) a rented room.
  if not exists (select 1 from public.premises_leases l where l.id = p_lease_id and l.workspace_id = p_workspace_id)
     and not exists (select 1 from public.room_rentals rr
                      where rr.id = p_lease_id and rr.workspace_id = p_workspace_id) then
    raise exception 'unknown lease';
  end if;

  with page as (
    select o.id, o.due_on, o.amount_cents, t.id as term_id,
           coalesce(t.kind, 'rent') as term_kind, coalesce(t.label, sc.title) as term_label
      from public.expense_occurrences o
      join public.expense_schedules sc on sc.id = o.schedule_id
      left join public.lease_terms t on t.schedule_id = o.schedule_id
     where sc.origin = 'workspace_contract' and sc.contract_id = p_lease_id
       and o.workspace_id = p_workspace_id
       and (p_before is null or o.due_on < p_before)
     order by o.due_on desc, o.id
     limit v_limit + 1
  ), shown as (
    select * from page order by due_on desc, id limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'due_on', s.due_on, 'expected_cents', s.amount_cents,
      'term_id', s.term_id, 'term_kind', s.term_kind, 'term_label', s.term_label,
      'matched_cents', coalesce((select sum(x.allocated_cents) from public.purchase_commitment_matches x
                                  where x.occurrence_id = s.id), 0),
      'matches', coalesce((select jsonb_agg(jsonb_build_object(
          'id', x.id, 'purchase_id', x.purchase_id, 'line_id', x.purchase_line_id, 'line_no', pl.line_no,
          'reference', d.original_reference, 'allocated_cents', x.allocated_cents,
          'line_gross_cents', pl.gross_cents,
          'line_unallocated_cents', pl.gross_cents - coalesce((select sum(y.allocated_cents)
              from public.purchase_commitment_matches y where y.purchase_line_id = pl.id), 0),
          'reversed', exists (select 1 from public.purchase_commitment_matches r where r.original_match_id = x.id))
          order by x.created_datetime, x.id)
          from public.purchase_commitment_matches x
          join public.purchase_documents d on d.id = x.purchase_id
          join public.purchase_lines pl on pl.id = x.purchase_line_id
         where x.occurrence_id = s.id and x.kind = 'match'), '[]'::jsonb))
      order by s.due_on desc, s.id), '[]'::jsonb),
    case when (select count(*) from page) > v_limit then (select min(due_on) from shown) end
    into v_rows, v_next
    from shown s;
  return jsonb_build_object('occurrences', v_rows, 'next_before', v_next);
end;
$fn$;
revoke execute on function public.purchase_commitment_page_v1(uuid, uuid, date, int) from public, anon;
grant execute on function public.purchase_commitment_page_v1(uuid, uuid, date, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(515);
