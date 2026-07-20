-- SPDX-License-Identifier: MIT
-- Owner-initiated workspace reset: wipe all transactions and the entire
-- floor plan, keeping only the workspace configuration and its members.
-- Applied to the hosted reference project on 2026-07-20.
--
-- DELETES: reservations, events (+ their decisions), ledger entries, quota
-- extensions, and the whole floor plan (plan images, seat accessories,
-- seats, desks, offices, levels — including level background photos).
-- KEEPS: the workspaces row (settings / booking_rules / feature_flags /
-- availability / payment instructions / whatsapp group), members, profiles,
-- fee bands, the service and accessory catalogs, closure days, validation
-- policies and admin invites.
--
-- Guarded to owners; the client additionally requires a typed confirmation
-- ("I agree") before calling it. Irreversible.

create or replace function public.reset_workspace(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may reset the workspace';
  end if;

  -- Transactions first (events.reservation_id is ON DELETE SET NULL, and
  -- event_decisions cascade from events; delete both explicitly anyway).
  delete from public.event_decisions d
    using public.events e
    where d.event_id = e.id and e.workspace_id = p_workspace_id;
  delete from public.events where workspace_id = p_workspace_id;
  delete from public.ledger_entries where workspace_id = p_workspace_id;
  delete from public.quota_extensions where workspace_id = p_workspace_id;
  delete from public.reservations where workspace_id = p_workspace_id;

  -- The floor plan (seat_accessories cascade from seats; children before
  -- parents so the delete never trips a foreign key either way).
  delete from public.plan_images where workspace_id = p_workspace_id;
  delete from public.seat_accessories where workspace_id = p_workspace_id;
  delete from public.seats where workspace_id = p_workspace_id;
  delete from public.desks where workspace_id = p_workspace_id;
  delete from public.offices where workspace_id = p_workspace_id;
  delete from public.levels where workspace_id = p_workspace_id;
end;
$$;
revoke execute on function public.reset_workspace(uuid) from public, anon;
