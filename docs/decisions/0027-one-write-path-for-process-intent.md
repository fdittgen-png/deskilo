# ADR 0027 — A process intent has one preview and one write, conditioned on what the preview read

**Status:** accepted · **Date:** 2026-09-18 · **Issue:** #1329 (P6 of #1323)

## Context

The Features screen opens on business processes (#1327). Switching a
process on or off is not one flag: the registry (#1325) names the
capabilities, `featureManifest.requires` pulls prerequisites in, and a
stored-on child can sit under a switched-off parent (#800). The resolver
(#1326) already computes the change-set. What was missing was the
contract between that computation and the row:

* a preview is computed from the flags **as read**; another owner can
  change a prerequisite or a dependant between the preview and the
  confirmation, and a delta merged over the new row applies a decision
  nobody approved;
* `set_feature_flags` merged unconditionally (0176) — the right fix for
  a stale *copy of the row* (#963), and no protection for a stale
  *decision*.

## Decision

1. **One preview, one write.** `application/process_activation.dart`
   holds `planProcessChange` (the preview, pure Dart over the resolver)
   and `applyProcessChange` (the write, the forced refetch, the typed
   outcomes). The overview, the detail and any future surface call
   these; none computes a change-set or writes flags itself.

2. **The write is conditioned on the read-set, atomically.**
   `set_feature_flags(workspace, delta, expected)` (0245) locks the row,
   compares every `expected` key with the locked row through
   `feature_raw` — which normalizes an absent key to the registry
   default exactly as `resolveEnabledFeatures` does — and refuses with
   SQLSTATE `DK409` naming the keys when any of it moved. The read-set
   is **every** flag the preview rested on: the selected capabilities,
   the prerequisites pulled in, the dependants a deactivation would
   orphan, the held-back capabilities an activation revives — not only
   the keys the delta writes. A null `expected` keeps the unconditional
   merge for the callers below that never previewed anything.

3. **On a conflict the client refetches, recomputes and asks again.**
   The old delta is never replayed. A write that went through but whose
   refetch failed is reported as *unconfirmed*, never as success or as
   failure.

4. **Deactivation is lazy and explicit.** The resolver refuses to
   switch a capability off while a stored-on dependant needs it; that
   refusal is the preview. The owner chooses: keep things as they are;
   switch off what they asked for and leave the dependants' stored
   choices in place (ineffective until the prerequisite returns); or
   switch the dependants off as well. `false` is written only for what
   the owner named.

## The writers, and their contract

| writer | path | contract |
|---|---|---|
| process activation / deactivation (Features overview) | `applyProcessChange` → `setFeatureFlags(…, expected:)` | previewed, conditional, refetched |
| one switch (Features switches view) | `toggleWorkspaceFeature` → `setFeatureFlags` (no read-set) | the #963 delta with the `requires` chain; unconditional by design — the switch shows the stored value it flips, there is no multi-key decision to protect |
| NFC feature toggle (Settings) | `toggleWorkspaceFeature` | same as one switch |
| workspace creation | `create_workspace(… p_feature_flags)` / `defaultFeatureFlagsForNewWorkspace` | the explicit tier default written once at creation (#1063); no prior state to compare |
| XML configuration import | `import_workspace_configuration` (server) | merge/mirror as documented in 0219; authoritative import, not a process intent |
| template apply / deployment | `apply_workspace_template`, `deploy_entities` (server) | the `features` entity through the same import; provenance in `workspace_template_applications` |

No client writer builds a full feature map from a copy of the row.

## Consequences

* `supabase/tests/database/49_feature_flags_expected.sql` pins the
  refusal on a written and on an unwritten stale key, the null-read-set
  behaviour, idempotence and the permission check;
  `scripts/feature_flags_race.sh` proves with two real sessions that
  the comparison and the write are one operation.
* The two-argument overload is gone: PostgREST resolves a two-parameter
  call to the defaulted argument, and two overloads would be ambiguous.
* "Enabled through process P" is never shown: it is not stored, so it is
  not known. What is shown is what is true: stored on, needed by X, held
  back by Y, from template T where `workspace_template_applications`
  says so.
