# ADR 0029 — A custom role is an additive grant, resolved in one place

**Status:** accepted · **Date:** 2026-09-19 · **Issue:** #1287 (T16 of #1271)

## Context

An association does not have owners, admins and members. It has a bureau:
a président, a trésorier, a secrétaire, perhaps a référent sécurité. Each
needs a different slice of the product, and the template should be able
to bring that slice with it.

Today the set is four, in both halves of the system:

* client — `enum PermissionRole { owner, coOwner, admin, member }`, and
  `effectivePermissions(member, workspace)` resolves a member to one of
  them;
* server — `has_permission(ws, perm)` (0185) derives the same four from
  three boolean columns on `members` (`is_owner`, `co_owner = 'active'`,
  `is_admin`) and reads `workspaces.role_permissions`, one permission
  list per role name; `set_role_permissions` (0155) refuses any role
  outside `co_owner`, `admin`, `member`.

What *is* configurable is which of the 24 `WorkspacePermission` values
each of those four rows holds. What is not is **how many rows there are
and what they are called**. So the trésorier is "an admin", and giving
them invoicing gives it to every admin.

`has_permission` sits behind every permission-gated definer function and,
through `may_view_member_finances`, behind the finance read policies. It
is called per row during policy evaluation. Whatever this decision is, it
is load-bearing.

## Decision

**1. The built-in four are the floor, and a custom role is additive.**

A member keeps their base role. A custom role adds permissions on top; it
never removes one and never replaces the base. Owner keeps everything,
always — `PermissionRole.owner => WorkspacePermission.values.toSet()` is
an invariant, not a default, and no custom role can take anything from an
owner.

This is the choice that keeps every existing policy correct while the
feature is off *and* while it is on, and it avoids a migration that
re-derives every member's authority. The cost is honest: a custom role
cannot express "an admin without invoicing". Subtraction is the feature
that makes an authorization model unreviewable, and it is a non-goal here
for that reason.

**2. A role is a row, not an enum value.**

`workspace_roles (workspace_id, key, permissions text[], names jsonb,
sort_order, active)` with `key` stable, and the human names as a
**per-locale map on the role row** — not lexicon overrides (#1277
renames the *product's* terminology, and a role a workspace invented is
not the product's word). A map rather than five columns, so a sixth
locale is a value and not a migration.

Membership is a join table, so a person can be both trésorier and member,
and so that granting is a row rather than an edit to a person.

**3. One resolution, in two implementations that must agree.**

`has_permission` gains the custom grants — validated against
`role_permission_catalog()` (0195), the catalogue that already exists,
so a custom role can never hold a permission the product does not have.
The Dart `effectivePermissions` mirrors it. That pair already exists and the mirror is already a known
hazard, so this extends the pinned test rather than adding a second
mechanism. The addition is a union:

```
has_permission(ws, perm) = <the four, as today>
                        OR EXISTS (a custom role the member holds
                                   whose permissions contain perm)
```

Because it is a union, the existing branch is untouched: a workspace with
no custom roles evaluates exactly what it evaluates today, which is what
makes the change safe to deploy before any UI exists.

**4. Definition is owner-only; assignment goes through the quorum.**

A role-granting function is a privilege-escalation surface by definition.

* Creating or editing a role: owner-only (`is_owner_of`), `security
  definer`, `revoke execute … from public, anon`.
* **No client write policy on `workspace_roles` or the membership join.**
  Rows arrive through those definers — the `quota_extensions` and
  `workspace_template_grants` precedent: a grant row never proves access.
* **Never for yourself.** A member may not assign themselves a role, the
  shape `set_member_simultaneous_limit` already uses.
* Assigning a custom role to a person reuses `EventType.roleChange`
  (0035) when the workspace's `role_change` policy requires a quorum, so
  a promotion is validated the way promotions already are.

**5. Flat sets only.** No hierarchy, no inheritance between custom roles,
no negative grants. Each is a way this feature becomes unreviewable.

**6. It travels as configuration, never as an assignment.** The `roles`
deployable entity widens to carry role definitions; **who holds which
role never travels** — the existing entity already carries "the role
matrix only; nothing assigns a role to a person", and that stays true.

## Consequences

* `has_permission` grows one `EXISTS` over two small tables. It must stay
  `stable` and must not become slow: the plan assertion belongs in
  `30_query_budgets.sql`, seeded at scale, because this function runs per
  row in policy evaluation. If the union costs more than the budget, the
  answer is an index on `(workspace_id, member_id)` of the join — not a
  cached copy of the resolution, which would be a second source of truth.
* The anchored-patch hazard applies: the hosted body and the migration
  files are known to diverge, so the patch anchors on meaning and is
  harnessed against the reference project before it is applied.
* pgTAP proves it with `set local role authenticated` and real claims —
  as `postgres` every policy is bypassed and the test proves nothing:
  a custom role granting `issueInvoices` lets its holder issue one and
  removing them stops it; a member cannot create a role, cannot grant
  themselves one, cannot grant a permission to a role they hold; an owner
  keeps every permission whatever the custom roles say.
* The catalogue does not grow. The 24 `WorkspacePermission` values are
  what exists; this changes **who holds them**.
* The feature ships behind a `WorkspaceFeature`, default off. A space
  that wants four roles keeps four, and sees no control for a fifth.

## Alternatives, and why not

| option | why not |
|---|---|
| Replace the enum with rows for all four built-ins | Re-derives every member's authority in a migration, and every policy in the product depends on that derivation being right on the first try. The floor stays where it is. |
| Custom roles that subtract ("admin without invoicing") | The question "what can this person do?" stops being answerable by reading one list. |
| Per-member ad-hoc permissions | How permission systems become unauditable: a permission belongs to a role, a person belongs to roles. |
| Resolve custom grants in the client only | The client is not an authorization boundary. The server must answer, or the feature is decoration. |
| A materialized `members.effective_permissions` column | A second source of truth that is stale exactly when it matters — during the change that granted it. |
