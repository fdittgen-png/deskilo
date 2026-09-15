# Threat model

**Status:** first version, 2026-09-13 (#1243). Reviewed with every
migration that changes a policy.

`SUPABASE_RLS_MATRIX.md` beside this file says who may do what. This
says who would want to do otherwise, what stops them, and — the column
most threat models omit — **whether anything tests it**.

## What is worth taking

| Asset | Why an attacker wants it |
|---|---|
| Members' identities and presence | who is in the building, and when |
| The ledger and invoices | money, and the leverage of altering a record |
| Badge and PIN credentials | physical entry |
| Payment provider keys and webhook secrets | money, directly |
| The workspace's own configuration | a door left open for later |
| The member list of a competitor's space | commercial |

## Who

1. **A curious member.** Authenticated, in one workspace, reading what
   is not theirs. The commonest and the one the design is built against.
2. **A former member.** Credentials that worked yesterday.
3. **An administrator of another workspace.** Authenticated, privileged
   somewhere else, and the reason tenancy is the central boundary.
4. **A malicious administrator of this workspace.** Legitimately
   privileged. The realistic insider in a coworking space, and the one
   most systems ignore.
5. **Anonymous internet.** Holding a URL, a workspace UUID, or a QR code
   photographed off a wall.
6. **A payment provider impersonator.** Anyone who can POST to a webhook.

## Trust boundaries

```
device ──┬─→ Supabase Auth ──→ JWT
         └─→ PostgREST ──→ RLS ──→ tables
                      └──→ SECURITY DEFINER functions ──→ tables
provider ──→ edge function ──→ signature check ──→ RPC ──→ tables
```

The device is never trusted. **The only boundary that holds is the
database's**, which is why business rules live in SQL and why the client
cannot write the ledger, the invoices or the reservations directly.

## Threats, mitigations, and what proves it

| # | Threat | Mitigation | Proof today |
|---|---|---|---|
| T1 | A member reads another workspace's data — rows **and storage objects** | RLS on every table; storage policies scoped to the workspace folder | `10_tenancy_isolation.sql`, `11_tenancy_matrix.sql` (#1226, #1227); `12_storage_tenancy.sql` for storage, added with 0215 after a hand-made broad read was found live on `floor-plans` |
| T2 | A member reads another member's invoice | `invoices_select` scoped to the member or an issuer permission | none (#1227) |
| T3 | Privilege escalation to admin | `has_permission`, role matrix, last-owner protection | Dart tests against fakes only |
| T4 | A `SECURITY DEFINER` function answers for any workspace | 54 of 57 client-reachable functions check the caller | **3 do not** (#1228) |
| T5 | Anonymous execution of a definer function | `revoke … from anon`, swept by `0191` | `migration_grants_test` — source text, forward-looking only |
| T6 | Invitation abuse: a code redeemed by the wrong person, or replayed | single-use personal codes, workspace-scoped | Dart tests |
| T7 | A QR or NFC badge photographed and replayed | hashed credentials, revocable, PIN as a second factor for sign-in | Dart tests; the SQL gate is untested |
| T8 | Booking manipulation — taking a seat that is held | database constraints and `create_reservation` | untested at the database (#1232) |
| T9 | Financial manipulation — altering an issued invoice | `invoices_no_mutation` trigger, SHA-256 content signature | **trigger never fires in a test** (#1226) |
| T10 | Webhook spoofing | signature verification in each edge function | `payment_money_test` reads the source; Deno never runs in CI |
| T11 | A webhook replayed to double a payment | `for update` + status guard, `0205:48` | none (#1231) |
| T12 | Document access outside the member's role | RLS on `workspace_documents` | none |
| T13 | Export abuse — exporting somebody else's data | `export_my_data` takes no member parameter; it is always the caller | none (#1238) |
| T14 | **A malicious administrator** empties a workspace or rewrites its money | delegated actions need confirmations (0017), nobody validates their own event (0086), invoices are immutable | partially — the confirmation rules are tested against fakes |
| T15 | Diagnostic data leaking through a shared log | device-local only, no telemetry | **no redaction** (#1240) |
| T16 | A stale session after removal | membership status checked server-side on every call | Dart tests |

## Residual risk, stated plainly

The mitigation column is largely honest and the proof column largely is
not. Sixteen threats, and **the database that enforces most of the
mitigations is never executed by a test**. That single fact is the
project's largest security risk, and it is #1226.

T4 is a live finding rather than a hypothetical: three functions answer
for any workspace id handed to them.

T14 is the one with no technical answer. An administrator of a workspace
can legitimately do almost everything in it; what limits them is the
confirmation protocol and the audit trail, and both are designed to make
damage *visible* rather than impossible. That is the right trade for a
coworking community and it should be said out loud rather than implied.
