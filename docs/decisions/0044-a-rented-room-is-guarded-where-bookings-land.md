# ADR 0044 — A rented room is guarded where every booking lands

**Status:** accepted · **Date:** 2026-10-19 · **Refs:** #2568, #2463, #2575, #2567

## Context
The space can rent a room from a lessor and open it to a chosen audience for
a period. Bookings reach the database through `create_reservation`,
`create_series`, the MCP availability probe and edits of existing rows; the
booking RPCs are long and patched many times, and a rule copied into each one
would drift.

## Decision
1. **One trigger, not four patches.** `reservation_rental_guard` (BEFORE
   INSERT, and UPDATE of the time, status and place columns) resolves the
   booking's seat/desk/office/level chain, and for a room that has a rental,
   or sits on an `external` level, checks: the rental is `active`, the
   booking's workspace-local days lie inside `available_from` ..
   `available_until` (**the last day is inclusive**; a booking running past
   midnight into the next day is judged by its last second), and the member is
   in the audience. Every path ends there, so the wording of each refusal is
   identical everywhere: "that room is not rented", "… is available from
   YYYY-MM-DD", "… is available until YYYY-MM-DD", "… is not open to you".
   The MCP probe returns that same message.
2. **Series are judged occurrence by occurrence.** Each occurrence is an
   insert; a role or plan change in the middle of a series refuses the later
   occurrences, never the ones already made.
3. **A level is `own` or `external`.** An external level is booked room by
   room; a whole-level booking of it is refused. Making a level external
   needs no upcoming booking on it; making it own again needs no rental on it.
4. **An empty audience is nobody.** A rental is opened on purpose.
5. **Hidden, not just refused.** Restrictive select policies on `levels`,
   `offices`, `desks` and `seats` hide a room (and an external level none of
   whose rooms is visible) from everyone outside its audience, except the
   managers of the plan (`manageSites`). The rental, its lessor, its cost and
   its contract are readable only by `manageSites` and `viewFinances`.
   What a member is shown is `room_offer_v1`: the window and the fee for them,
   the most specific fee winning (their member, then a role, then their plan,
   then the general one) — never the cost to the space.
6. **One country.** A room in a site of another country than the space is
   refused when the rental is saved, until place-of-supply recharge is wired.
7. **The flag gates the commands, not the guard.** `externalRooms` (platform,
   off, under `levelBooking`) gates the commands and reads; a rental that
   exists keeps guarding its room if the flag is switched off later.

## Consequences
- A workspace with no external level and no rental pays one level lookup per
  booking; nothing else changes.
- Reservations of a hidden room remain readable as rows (the reservations
  policy is not narrowed here); they name an id the member cannot resolve.
  Narrowing it is a follow-up with the member-facing screens (#2575).
- The purchase side of the rent (the lessor's invoices, the commitment) is
  #2575 / #2573; this ADR only fixes who may book, when, and what they see.
