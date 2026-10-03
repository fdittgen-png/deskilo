-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0352 (#1855 A) -- a booking's original intent survives a lost answer.
--
-- `create_reservation_once` (0214) claims a client request id before it
-- books, so a replay returns the first booking instead of making a
-- second. Measured on the hosted schema: the claim stored owner and
-- result only -- a replay of the SAME id with a DIFFERENT payload was
-- certified as the original booking, and nothing let a client that lost
-- the answer ask "what became of my request?" without booking again.
--
-- Two additions, nothing else changes:
--   * the claim carries a digest of the material payload (space, window,
--     check-in). A replay with the same payload returns the original; a
--     replay with another payload under the same id is refused by name;
--     a claim from before this migration (no digest) is never certified
--     either way -- the caller is told to look the booking up instead;
--   * `reservation_request_outcome` is the protected own-result lookup:
--     the member who made the request reads committed / in_progress /
--     absent. Another member's request, an unknown id and an expired one
--     all read `absent` -- the caller judges it against the intent's age
--     (rows are kept at least `retention_days`; absence after that is
--     "unresolved", never "nothing was booked").

alter table public.reservation_requests
  add column if not exists payload_digest text;

comment on column public.reservation_requests.payload_digest is
  '#1855 -- md5 of the material payload the claim was made with (space ids, window, check-in); null for claims older than 0352';

-- The one definition of "the same booking", shared by the claim and the
-- replay. Instants compare as epochs, so the textual form a client gives
-- the same instant never matters.
create or replace function public.reservation_request_digest(
  p_seat_id uuid, p_desk_id uuid, p_office_id uuid, p_level_id uuid,
  p_starts_at timestamptz, p_ends_at timestamptz, p_check_in boolean)
returns text
language sql
immutable
set search_path = public
as $fn$
  select md5(concat_ws('|',
    coalesce(p_seat_id::text, ''), coalesce(p_desk_id::text, ''),
    coalesce(p_office_id::text, ''), coalesce(p_level_id::text, ''),
    coalesce(extract(epoch from p_starts_at)::text, ''),
    coalesce(extract(epoch from p_ends_at)::text, ''),
    coalesce(p_check_in, false)::text));
$fn$;
revoke execute on function public.reservation_request_digest(uuid, uuid, uuid, uuid, timestamptz, timestamptz, boolean) from public, anon;
grant execute on function public.reservation_request_digest(uuid, uuid, uuid, uuid, timestamptz, timestamptz, boolean) to authenticated;

create or replace function public.create_reservation_once(
  p_client_request_id uuid, p_workspace_id uuid,
  p_seat_id uuid default null, p_desk_id uuid default null,
  p_office_id uuid default null, p_level_id uuid default null,
  p_starts_at timestamptz default null, p_ends_at timestamptz default null,
  p_check_in boolean default false)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_member public.members;
  v_claimed int := 0;
  v_owner uuid;
  v_existing uuid;
  v_stored text;
  v_digest text;
  v_id uuid;
begin
  if p_client_request_id is null then
    raise exception 'a replayable booking needs a request id';
  end if;
  select * into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid()
     and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;

  v_digest := public.reservation_request_digest(p_seat_id, p_desk_id, p_office_id, p_level_id,
                                                p_starts_at, p_ends_at, p_check_in);
  insert into public.reservation_requests
    (workspace_id, client_request_id, member_id, payload_digest)
  values (p_workspace_id, p_client_request_id, v_member.id, v_digest)
  on conflict do nothing;
  get diagnostics v_claimed = row_count;

  if v_claimed = 0 then
    select reservation_id, member_id, payload_digest into v_existing, v_owner, v_stored
      from public.reservation_requests
     where workspace_id = p_workspace_id
       and client_request_id = p_client_request_id;
    if v_owner is distinct from v_member.id then
      raise exception 'that request id belongs to another member';
    end if;
    -- #1855 -- a replay certifies only the booking it was made for.
    if v_stored is null then
      raise exception 'that request id predates payload checks: look the booking up instead of replaying it';
    end if;
    if v_stored <> v_digest then
      raise exception 'that request id was used for a different booking';
    end if;
    if v_existing is null then
      raise exception 'that booking is already being made';
    end if;
    return v_existing;
  end if;

  v_id := public.create_reservation(
    p_workspace_id, p_seat_id, p_office_id, p_starts_at, p_ends_at,
    p_check_in, p_level_id, p_desk_id);

  update public.reservation_requests set reservation_id = v_id
   where workspace_id = p_workspace_id
     and client_request_id = p_client_request_id;
  return v_id;
end;
$fn$;
revoke execute on function public.create_reservation_once(uuid, uuid, uuid, uuid, uuid, uuid, timestamptz, timestamptz, boolean) from public, anon;
grant execute on function public.create_reservation_once(uuid, uuid, uuid, uuid, uuid, uuid, timestamptz, timestamptz, boolean) to authenticated;

-- The protected own-result lookup: what became of MY request. Rows are
-- kept at least `retention_days`; a request absent after that is
-- unresolved, never "nothing was booked", and the caller says so.
create or replace function public.reservation_request_outcome(p_workspace_id uuid, p_client_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_member public.members;
  v_request public.reservation_requests;
  v_reservation public.reservations;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_client_request_id is null then raise exception 'a lookup needs the request id'; end if;
  select * into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid()
     and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  select * into v_request from public.reservation_requests
   where workspace_id = p_workspace_id and client_request_id = p_client_request_id;
  -- Another member's request reads exactly like no request: the id
  -- discloses nothing about anybody else's bookings.
  if v_request.client_request_id is null or v_request.member_id <> v_member.id then
    return jsonb_build_object('status', 'absent', 'retention_days', 90);
  end if;
  if v_request.reservation_id is null then
    return jsonb_build_object('status', 'in_progress', 'claimed_at', v_request.claimed_at,
                              'retention_days', 90);
  end if;
  select * into v_reservation from public.reservations where id = v_request.reservation_id;
  return jsonb_build_object('status', 'committed',
    'reservation_id', v_request.reservation_id,
    'claimed_at', v_request.claimed_at,
    'reservation_status', v_reservation.status,
    'starts_at', v_reservation.starts_at,
    'ends_at', v_reservation.ends_at,
    'retention_days', 90);
end;
$fn$;
revoke execute on function public.reservation_request_outcome(uuid, uuid) from public, anon;
grant execute on function public.reservation_request_outcome(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(352);
