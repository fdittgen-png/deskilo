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

## Auditing rule

Every migration that touches a table, policy, or `security definer` function
MUST update this matrix in the same PR and re-run
`get_advisors(type: security)` (or the Supabase dashboard linter) — the
advisor result belongs in the PR description.
