---
name: deskilo-supabase-migration
description: Writing, numbering, proving and applying a DesKilo Supabase migration, RPC, policy or pgTAP file — the number taken at push time, the file shape (SPDX, risk line, system columns, revokes, version marker), the rolled-back harness/pgTAP probe on the dev project before apply_migration, APPLIED.sha256, the predicted contract digest, the instance bundle, the SQL-side registries (event types, permission catalog, feature registry), anchored patches with pg_temp.anchor_replace. Trigger whenever a change adds or edits anything under supabase/migrations or supabase/tests/database, or changes an RPC, policy, trigger or table.
---
# Supabase migrations in DesKilo

Binding rules: AGENT_RULES "Every migration ends with its version", "System
columns on every table", "A grant row never proves access", and the pgTAP traps
under "Testing rules". The generic harness shape (one transaction, impersonation,
per-case subtransactions, results in the aborting RAISE) is the user-level
`supabase-live-rpc-testing` skill; this one is DesKilo's ritual.

**Essentials**
1. Number = master's latest + 1 **at push time**; never push into a gap; first merge keeps it.
2. Prove on the dev project first (rolled-back harness or pgTAP probe, red first), then
   `apply_migration` with the exact file text — all BEFORE the first push.
3. `dart run tool/record_applied_migrations.dart` → commit `supabase/APPLIED.sha256`; an applied file never changes again.
4. Predict `assets/instance/contract.txt` with `tool/contract_predict.dart`; only exit 2 waits for CI's artifact.
5. `dart run tool/build_instance.dart`; check `bundle.json` names every migration.

Idioms, pgTAP probe mechanics and incidents: [reference.md](reference.md).

## 1. The number
- Dev project `zwzbynivewivvjmripeb` (never the tankstellen project). Files are
  `supabase/migrations/NNNN_name.sql`; pgTAP files `supabase/tests/database/NN_name.sql`.
- Claim the number you intend in `AGENT_HANDOFF.md` / `.agent-work/<issue>.json`
  before writing the file — a courtesy, never a reason to leave a gap. pgTAP
  files take the next free number the same way.
- At PUSH time take master's latest + 1. A gap fails the upgrade check ("pending N,
  want N+1") and costs a merge plus another full run. If another open PR holds the
  same number, push anyway: whoever merges first keeps it; the other renames inside
  the merge-master commit it needs anyway — file name, `set_deskilo_schema_version(N)`,
  `requiredSchemaVersion` (`lib/core/instance/schema_compatibility.dart`), then
  `record_applied_migrations` and `build_instance`.
- `set_deskilo_schema_version` is monotonic (`greatest`): after renumbering a file
  already applied to dev DOWN, set `public.deskilo_schema_version` directly on dev
  and say so in the handoff.

## 2. The file
- Line 1 `-- SPDX-License-Identifier: AGPL-3.0-or-later`; line 2
  `-- risk: additive|transforming|destructive` (a destructive one names the backup).
- Every `create table` is followed by `select public.ensure_system_columns('<table>');`
  (lint `system_columns_test`). Every RLS table gets its `mcp_delegated_deny`-style
  policy and a line in `assets/instance/policies.txt` (pgTAP 61/79 and
  `policy_manifest_test`), and a decision in the export-coverage lints
  (`workspace_export_coverage_test`, `gdpr_export_coverage_test`).
- `revoke execute … from public, anon` in the SAME file that first creates a
  function: `CREATE OR REPLACE` keeps the existing ACL, so a later file cannot fix it.
- Adding a defaulted parameter: `drop function if exists public.f(<old signature>);`
  first, or calls become ambiguous between two overloads.
- A long function you do not own is patched at an asserted anchor with
  `pg_temp.anchor_replace(def, old, new)` (0227/0230; returns NULL on a miss —
  raise then). The harness must EXECUTE every branch the patch touches (reference.md).
- An applied file is never rewritten: a later fix is a new migration.
- LAST statement: `select public.set_deskilo_schema_version(NNNN);` (lint
  `migration_version_marker_test`).

## 3. Prove, apply, record — on dev, before the first push
1. **Red first.** Run the migration + its assertions as ONE rolled-back
   `execute_sql`: either a `do $harness$ … raise exception 'HARNESS_RESULTS %' …`
   block (impersonate with `perform set_config('request.jwt.claims',
   json_build_object('sub', uid, 'role','authenticated')::text, true)`; pick
   fixtures by name (`workspaces.name ilike 'COWORKONTI%'`), never by id; negative paths in nested
   `begin … exception when others then v_err := sqlerrm; end;`), or the pgTAP
   file itself through the probe loop (reference.md "pgTAP probe"). Before the
   migration the new behaviour's rows fail; after it, `failed=0`.
2. `apply_migration` with the SAME text (pre-authorised on the dev project). A
   migration stacked on an unmerged one: apply the earlier one to dev first, so
   the probe stays small (an app requiring N accepts a server at N+1).
3. Verify: a `select` proving columns/functions/triggers exist, and
   `md5(prosrc)` against the file's `$fn$` bodies (a chunked md5 finds WHERE they
   differ; comment drift is harmless, logic drift is not).
4. `dart run tool/record_applied_migrations.dart` → commit `supabase/APPLIED.sha256`.
5. After an RPC change, run the rolled-back live harness against the applied
   function too — the fake answers what the test says, the database what the text means.

## 4. Contract digest and generated files
- `quality · database` is a REQUIRED check: a stale `assets/instance/contract.txt`
  holds the PR open. Before the first push:
  `dart run tool/contract_predict.dart sql supabase/migrations/NNNN_x.sql` → run the
  printed query on dev → save the row as JSON (`[{"lines": [...]}]`) →
  `dart run tool/contract_predict.dart apply supabase/migrations/NNNN_x.sql result.json`.
  It owns what the file defines WHOLE (a function created or dropped there, the
  constraints and triggers of a table created there).
- **Exit 2** names what it cannot predict — an anchored patch (dev's long-patched
  bodies drift from the replay) or a constraint/trigger change on an existing
  table. Only then copy CI's artifact ONCE: `gh run download <run> -n quality-database`,
  take its `contract.txt` (and `policies.txt` if it changed) — the + side of the
  replay, never the hosted project's text.
- `docs/database/dictionary.json` drift only WARNS on a PR (#2089);
  `CI · Dictionary refresh` regenerates it after the merge. Do not chase it.
- After merging master into a migration branch, run `dart run tool/build_instance.dart`
  yourself (preflight did not) and check `bundle.json` names every migration.
- An MCP catalogue change: the latest migration defining `mcp_operation_catalogue()`
  carries `renderMcpCatalogueSql` verbatim (`mcp_contract_test`).

## 5. Registries on the SQL side
- **Event types**: `events_type_check` + `validation_policies_event_type_check` both
  list every type — extend both, seed the policy row per workspace, and the client's
  FOUR places (AGENT_RULES "Validation domains").
- **Permissions**: a new `WorkspacePermission` = a migration restating
  `public.role_permission_catalog()` whole (0195 moved the array there; 0340 is the
  latest); `roles_screen_test` reads the LATEST definer of that function.
  `has_permission` admin defaults are a literal list too.
- **Features**: `public.feature_registry()` carries `build_feature_registry_sql.dart`'s
  output (`feature_registry_sql_test`); gates call `public.feature_effective(ws, 'key')`.
- `invoices_no_mutation` (→ `invoices_immutable()`): lift only for test data, re-arm.
  A guard comparing whole rows subtracts `public.system_column_names()`.
- Decisions apply through an AFTER UPDATE trigger on `events`, never a branch in
  `respond_to_event` (0151 idiom).
- A rendering that exists in SQL and Dart (`profile_full_name` / `fullName`, …) changes
  in both; `personal_info_test` pins Dart to the SQL harness output.
