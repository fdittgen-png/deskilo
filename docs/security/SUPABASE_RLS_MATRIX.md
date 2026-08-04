# Supabase RLS permission matrix

Modeled on Sparkilo's `SUPABASE_RLS_MATRIX`. Audited with the Supabase security
advisors (clean, 2026-07-07). Default-deny: any operation not listed is blocked.

Roles are per workspace (spec §2): **anon** (not signed in), **user** (signed
in, not a member of the row's workspace), **worker** (active member),
**admin** (`is_admin`), **owner** (`is_owner`). Roles are additive.

| Table | Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|---|
| profiles | select own | — | ✅ | ✅ | ✅ | ✅ | `profiles_select` |
| profiles | select co-member | — | — | ✅ | ✅ | ✅ | `shares_workspace_with()` |
| profiles | insert | — | auto | auto | auto | auto | `handle_new_user` trigger only |
| profiles | update own | — | ✅ | ✅ | ✅ | ✅ | `profiles_update` |
| workspaces | select | — | — | ✅ | ✅ | ✅ | `is_member_of()` |
| workspaces | insert | — | RPC | RPC | RPC | RPC | `create_workspace()` (creator becomes owner) |
| workspaces | update | — | — | — | — | ✅ | `is_owner_of()` |
| workspaces | delete | — | — | — | — | ✅ | `is_owner_of()` |
| members | select | — | — | ✅ | ✅ | ✅ | `is_member_of()` |
| members | insert (join) | — | RPC | RPC | RPC | RPC | `join_workspace(invite_code)` |
| members | update (roles/plan/status) | — | — | — | — | ✅ | `members_update_owner` |
| members | update (leave) | — | — | RPC | RPC | RPC | `leave_workspace()` sets status=exited |
| members | delete | — | — | — | — | ✅ | `members_delete_owner` |

## Invariants enforced in the database

- **Last-owner protection** — `protect_last_owner()` trigger: an update/delete
  that would leave a workspace without an active owner raises. The last owner
  can only be *replaced*, never removed (spec §2).
- **Exited members lose visibility**: all helpers exclude `status = 'exited'`.
- **Helper functions are `security definer` with pinned `search_path`** so RLS
  policies on `members` can consult `members` without recursion, and clients
  cannot spoof them.
- **Invite codes** are 10 chars from an unambiguous 32-letter alphabet,
  server-generated, unique; `join_workspace` re-activates an exited membership
  instead of duplicating it.

## Floor-plan tables (levels · offices · desks · seats)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| select | — | — | ✅ | ✅ | ✅ | `is_member_of(workspace_id)` |
| insert / update / delete | — | — | — | — | ✅ | `is_owner_of(workspace_id)` — only owners alter the workspace (spec §2) |
| seat block / unblock (#161) | — | — | — | RPC¹ | RPC | `set_seat_block` (migration 0021) writes `seats.blocked_from/blocked_to` |

¹ Admins only when the workspace's `feature_flags` carry
`adminSeatBlocking = true` (owner-managed registry, #146); the RPC raises
otherwise.

`workspace_id` is denormalized onto all four tables so every policy is a
single helper call.

## Accessories (migration 0022 — accessories · seat_accessories)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| select | — | — | ✅ | ✅ | ✅ | `is_member_of(workspace_id)` |
| insert / update / delete | — | — | — | ✅ | ✅ | `is_admin_of(workspace_id)` — maintainer decision on epic #163: admins co-manage the accessory catalog and seat assignments |

Invariants enforced in the database:
- **Same-workspace guard**: the `seat_accessories_same_workspace` BEFORE
  trigger derives `seat_accessories.workspace_id` from the seat and raises
  if the accessory belongs to another workspace — clients cannot spoof the
  denormalized `workspace_id` the policies check.
- `unique (workspace_id, name)` on `accessories`;
  `supplement_cents >= 0` (per half-day, summed per accessory on a seat).
- Accessories are deactivated (`active = false`), never deleted — seat
  assignments and future bill lines (#170) reference them.
- Data migration: catalogs were seeded from the legacy `seats.amenities`
  keys (English display names, pinned by `AccessorySeed`); the column
  itself is untouched until #168 retires it.

## Reservations (migration 0005)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| select | — | — | ✅ | ✅ | ✅ | `is_member_of(workspace_id)` |
| create (self) | — | — | RPC | RPC | RPC | `create_reservation` — caller-only; admin-for-others goes through the Epic-#6 confirmation protocol |
| check-in / check-out / cancel (own) | — | — | RPC | RPC | RPC | ownership verified via `members.user_id = auth.uid()` |

Hard invariants in the database:
- **No double-booking**: btree_gist exclusion constraints on
  `(seat_id, tstzrange)` and `(office_id, tstzrange)` for active statuses —
  the walk-up race (spec §4.2) cannot commit twice.
- **Guarded deletion**: `on delete restrict` from reservations to
  seats/offices/members — the editor must resolve reservations first.
- Business checks in `create_reservation`: active membership, blocked-seat
  window, office-booked-as-whole vs seat bookings in both directions.
- Since migration 0021 the blocked-seat window is also enforced in
  `admin_create_reservation_for` and per-instance in `create_series`
  (blocked instances land in the skipped report) via
  `assert_seat_not_blocked` (internal helper, EXECUTE revoked from all
  API roles).
- Check-out truncates `ends_at` to `now()` so the seat frees immediately.

## Function grants (migration 0004)

- Trigger functions (`handle_new_user`, `protect_last_owner`) and
  `gen_invite_code`: EXECUTE revoked from every API role.
- Helper predicates + RPCs: EXECUTE revoked from `anon`/`public`;
  `authenticated` keeps EXECUTE.
- **Accepted advisor warnings**: the linter still notes that `authenticated`
  can execute the SECURITY DEFINER RPCs and helper predicates — that IS the
  API surface (RPCs check `auth.uid()`; predicates only answer questions
  about the caller's own memberships). Do not "fix" these.
- `btree_gist` lives in the `extensions` schema (kept for future
  reservation-overlap exclusion constraints).

## Auditing rule

Every migration that touches a table, policy, or `security definer` function
MUST update this matrix in the same PR and re-run
`get_advisors(type: security)` (or the Supabase dashboard linter) — the
advisor result belongs in the PR description.

## E-invoice transmission (0071 · 0074)

| Table | Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|---|
| einvoice_credentials | any | — | — | — | — | RPC¹ | RLS enabled, deliberately ZERO policies (deny-all); only `set/clear_einvoice_credentials` + `einvoice_status` (owner-gated SECURITY DEFINER) and the Edge Function via service role touch it |
| invoice_transmissions | select | — | — | — | ✅ | ✅ | `is_admin_of(workspace_id)` |
| invoice_transmissions | insert | — | — | — | — | — | Edge Function (service role) only — a client cannot claim an invoice was sent |

¹ Secret VALUES never return to any client: `einvoice_status` echoes
non-secret fields and the NAMES of set secrets. 0074 widens the non-secret
set to the environment-suffixed endpoints (`endpoint_uat`, `endpoint_dev`,
header/field overrides) so the owner UI can read back a test endpoint;
every `auth_value*` stays secret. 0074 also adds
`invoice_transmissions.environment` (`prod`/`uat`/`dev`, default `prod`) —
same policies, one more column, so a rehearsal is never mistaken for the
real submission.

## Day-end sweep (0075 — `sweep_day_end`)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| complete past open reservations | — | — | RPC¹ | RPC¹ | RPC¹ | `sweep_day_end(workspace)` SECURITY DEFINER, invoked lazily before reservation reads |

¹ Any ACTIVE member may trigger it for their own workspace — the write it
performs is the workspace's configured policy, not the caller's privilege:
the RPC is a no-op unless `feature_flags.autoCheckInOut = true` (jsonb
boolean check, junk counts as OFF — the 0021 idiom), and it only ever
moves `reserved`/`checked_in` rows whose OWN `ends_at` has passed to
`completed` (stamping `starts_at`/`ends_at`). Cancelled and released rows
are untouchable by shape of the WHERE clause.

## Member emails (0078 — `member_emails`)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| read members' emails | — | — | — | RPC | RPC | `member_emails(workspace_id)` SECURITY DEFINER over `members ⨝ auth.users` |

Emails live ONLY in `auth.users` — `public.profiles` deliberately exposes
no contact data to co-members (WhatsApp is opt-in, `''` = not shared).
The RPC keeps that stance: it returns the member-id → email rows only
when the caller `is_admin_of` the workspace and the empty set for
everyone else (no error, nothing to probe). Revoked from anon/public,
granted to authenticated. The client mirrors the gate by short-circuiting
to `{}` for non-admin viewers before ever calling.

## One place at a time + overrule (0079)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| hold overlapping active reservations | — | ✗ | ✗ | ✗ | ✗ | `enforce_one_place` BEFORE INSERT trigger — pinned refusal on any path |
| check in while checked in elsewhere (running) | — | ✗ | ✗ | ✗ | ✗ | `check_in_reservation` v3 guard; STALE check-ins auto-complete at their own end first |
| reserve a whole desk/office/level | — | grant | grant | ✓ | ✓ | `create_reservation` v8 / `create_series` v3: `can_reserve_level OR is_owner OR is_admin` (kiosk keeps the strict stored grant) |
| cancel ANOTHER member's reservation (overrule) | — | ✗ | ✗ | ✓ | ✓ | `cancel_reservation` v2: owner-or-`is_admin_of`; the 0007 `reservations_log_event` trigger broadcasts the cancellation to the displaced member's feed (admins see all) — that IS the notification |
## Realtime publication (0080)

The `supabase_realtime` publication carries the app-rendered tables
(reservations, members, workspaces, profiles, plan geometry + images,
events + decisions, ledger, payment intents, invoices, services,
accessories, closure days, quota extensions, fee bands, packages,
validation policies). postgres_changes applies RLS per subscriber
(WALRUS) for INSERT/UPDATE; DELETE events carry the primary key only —
bare uuids, used purely as an invalidation signal. Deny-all tables
(payment_credentials, member_badges, push_endpoints) are deliberately
NOT published.

## Workspace developer mode (0081 — `set_dev_mode`)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| flip workspace dev mode | — | ✗ | ✗ | RPC | RPC | `set_dev_mode(workspace_id, enabled)` SECURITY DEFINER, `is_admin_of`-gated; `workspaces_update` RLS stays owner-only |

The `dev_mode` column rides the workspace row every member already
SELECTs, and 0080 publishes it — a flip reaches every device live. The
mode applies to ALL members (e-invoice test environments, Developer
screen); only admins/owners see the switch.

## Push for cancellations (0082 — `notify_pending_event` v2)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| push on overrule cancellation | — | — | — | — | — | events trigger → `net.http_post` to the displaced member's + admins' endpoints (minus the actor) |

`cancel_reservation` v3 re-attributes the cancelled event to the TRUE
actor (the 0007 log trigger stamps the row's member), so the trigger can
tell an overrule from a self-cancel; it also fires on
`actor_member_id` updates — exactly that re-attribution. Payloads stay
the 0012 generic ping (`{"kind":"reservation_cancelled"}`): no names,
no times ever transit the distributor; the client localizes.

## No self-validation (0086 — `respond_to_event` v-next)

| Operation | anon | user | worker | admin | owner | Mechanism |
|---|---|---|---|---|---|---|
| validate one's OWN event | — | ✗ | ✗ | ✗ | ✗ | the #107 solo escape hatch is removed — the actor is refused unconditionally |

Owner rule (#434): only another person validates. The subject-as-
fallback path stays (the subject of someone ELSE's action is another
person). A pool that collapses to the actor leaves the event pending
until it expires: never granted silently, never self-granted.
