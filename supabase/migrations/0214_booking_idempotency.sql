-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0214 — #1241 step 3's foundation: a booking can be replayed safely.
--
-- A booking made with no network is lost today. The `SocketException`
-- propagates, the member sees a sentence (a better one since #1240),
-- and the booking is gone. #1241 asks for three things in order: say it
-- plainly (done), retry, and queue the one write that matters.
--
-- Queueing is only safe if a replay cannot book twice, and that guard
-- has to be on the server — a client that has just lost the network is
-- exactly the client whose local state you cannot trust. So this is the
-- guard, and it lands before the queue rather than with it.
--
-- ## Why a wrapper and not a parameter
--
-- `create_reservation` is two hundred lines of booking rules with a
-- retry loop inside it. Adding a parameter means re-creating the whole
-- function, and #1226 has just finished proving that the body the hosted
-- projects hold is not always the body the files write. A wrapper
-- touches none of it.
--
-- ## Why a table and not a column
--
-- The key has to be claimed BEFORE the booking is attempted, so that two
-- replays racing each other cannot both get past the check. A primary
-- key on (workspace_id, client_request_id) with `on conflict do nothing`
-- is that claim: exactly one caller inserts, and the loser reads the
-- winner's answer. A column on `reservations` could only be written
-- after the row exists, which is the window this is here to close.
create table if not exists public.reservation_requests (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  client_request_id uuid not null,
  member_id uuid not null references public.members(id) on delete cascade,
  reservation_id uuid references public.reservations(id) on delete set null,
  claimed_at timestamptz not null default now(),
  primary key (workspace_id, client_request_id)
);
select public.ensure_system_columns('reservation_requests');

alter table public.reservation_requests enable row level security;
-- No policy, and no grant: the claim ledger is the server's own
-- bookkeeping. A member reads the ANSWER through the function, which
-- returns the reservation id they already have a policy for (#1226 —
-- a table with no policy grants nothing either).
revoke all on table public.reservation_requests from anon, authenticated;

comment on table public.reservation_requests is
  '#1241 — one row per booking a client asked for, keyed by the id the '
  'CLIENT generated. Lets an offline queue replay a booking without '
  'making a second one.';

create or replace function public.create_reservation_once(
  p_client_request_id uuid,
  p_workspace_id uuid,
  p_seat_id uuid default null,
  p_desk_id uuid default null,
  p_office_id uuid default null,
  p_level_id uuid default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_check_in boolean default false
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_claimed int := 0;
  v_owner uuid;
  v_existing uuid;
  v_id uuid;
begin
  if p_client_request_id is null then
    raise exception 'a replayable booking needs a request id';
  end if;
  select * into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid()
     and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;

  -- Claim the key. Exactly one caller wins; the rest read the answer.
  insert into public.reservation_requests
    (workspace_id, client_request_id, member_id)
  values (p_workspace_id, p_client_request_id, v_member.id)
  on conflict do nothing;
  get diagnostics v_claimed = row_count;

  if v_claimed = 0 then
    select reservation_id, member_id into v_existing, v_owner
      from public.reservation_requests
     where workspace_id = p_workspace_id
       and client_request_id = p_client_request_id;
    -- A request id is a member's own. Replaying somebody else's would
    -- hand them a reservation id they may have no policy to read.
    if v_owner is distinct from v_member.id then
      raise exception 'that request id belongs to another member';
    end if;
    if v_existing is null then
      -- Claimed, not finished: either it is still running in another
      -- transaction, or it failed and the member should see why rather
      -- than be told a booking exists.
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
revoke execute on function public.create_reservation_once(
  uuid, uuid, uuid, uuid, uuid, uuid, timestamptz, timestamptz, boolean)
from public, anon;
