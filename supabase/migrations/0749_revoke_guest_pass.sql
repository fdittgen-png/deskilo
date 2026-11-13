-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0749 (#3829, part of #3625) -- a sold guest pass can be revoked.
--
--   * `guest_passes` gains `revoked_at`, `revoked_by` (the person, as
--     `sold_by`), the request id that revoked it and the bookings it
--     cancelled.
--   * `revoke_guest_pass(p_workspace_id, p_pass_id, p_request_id)`, under
--     the seller's own right (issueInvoices; an owner holds it), refused for
--     a delegated assistant like the sale: the pass's bookings that have not
--     started yet are cancelled, those already started or past stay, and the
--     pass is marked revoked. The same request id answers the same again; a
--     pass revoked by another request is refused (DKD01).
--   * No money moves here: the pass's invoice is corrected on the invoice
--     page, by a credit note or a cancellation, as any invoice.
--
-- Re-runnable: the columns are added if missing and the function replaced.

alter table public.guest_passes
  add column if not exists revoked_at timestamptz,
  add column if not exists revoked_by uuid,
  add column if not exists revoke_request_id uuid,
  add column if not exists revoked_reservation_ids uuid[] not null default '{}';
comment on column public.guest_passes.revoked_at is
  '#3829: when the pass was revoked; its bookings not yet started were cancelled then.';

create or replace function public.revoke_guest_pass(
  p_workspace_id uuid, p_pass_id uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_pass public.guest_passes;
  v_actor uuid;
  v_cancelled uuid[] := '{}';
  v_res public.reservations;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = 'P0001'; end if;
  if public.mcp_is_delegated() then
    raise exception 'guest passes are revoked in the Deskilo app' using errcode = 'DKN01';
  end if;
  -- Authorised first: a replay answers only someone who may revoke here.
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed to revoke a guest pass' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'guestPasses') then
    raise exception 'guest passes are off in this space' using errcode = '0A000';
  end if;
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text || p_pass_id::text, 0));
  select * into v_pass from public.guest_passes
   where id = p_pass_id and workspace_id = p_workspace_id for update;
  if v_pass.id is null then
    raise exception 'unknown guest pass' using errcode = '22023';
  end if;
  if v_pass.revoked_at is not null then
    if v_pass.revoke_request_id = p_request_id then
      return jsonb_build_object('pass_id', v_pass.id, 'revoked_at', v_pass.revoked_at,
        'cancelled_reservation_ids', to_jsonb(v_pass.revoked_reservation_ids), 'replayed', true);
    end if;
    raise exception 'this guest pass is already revoked' using errcode = 'DKD01';
  end if;

  select m.id into v_actor from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';

  -- The bookings not started yet are cancelled; those already started (or
  -- past) stay as they are: the guest used them.
  for v_res in
    select r.* from public.reservations r
     where r.id = any (v_pass.reservation_ids) and r.workspace_id = p_workspace_id
       and r.status = 'reserved' and r.starts_at > now()
     order by r.starts_at
     for update
  loop
    update public.reservations set status = 'cancelled' where id = v_res.id;
    v_cancelled := v_cancelled || v_res.id;
  end loop;
  -- As cancel_reservation does for someone else's booking: the feed names
  -- who acted, not the guest.
  if v_actor is not null and cardinality(v_cancelled) > 0 then
    update public.events
       set actor_member_id = v_actor
     where reservation_id = any (v_cancelled)
       and type = 'reservation' and action = 'cancelled';
  end if;

  update public.guest_passes
     set revoked_at = now(), revoked_by = auth.uid(), revoke_request_id = p_request_id,
         revoked_reservation_ids = v_cancelled
   where id = v_pass.id
  returning * into v_pass;

  return jsonb_build_object('pass_id', v_pass.id, 'revoked_at', v_pass.revoked_at,
    'cancelled_reservation_ids', to_jsonb(v_cancelled), 'replayed', false);
end;
$fn$;
revoke execute on function public.revoke_guest_pass(uuid, uuid, uuid) from public, anon;
grant execute on function public.revoke_guest_pass(uuid, uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(749);
