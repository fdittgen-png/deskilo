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
