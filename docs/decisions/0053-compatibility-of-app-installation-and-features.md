# ADR 0053 — Compatibility of the app, the installation and the features: three numbers, one verdict per installation, the rules of change

**Status:** accepted · **Date:** 2026-11-22 · **Refs:** #3728, #3727, #3726, #3729, #3730, #3731, #3732, #4155, ADR 0051

## Context
One app talks to several installations at once (the personal home, a
business hosted elsewhere), each at its own schema version. Migrations are
applied to the reference installation before a branch is first pushed (the
`deskilo-supabase-migration` skill) and by the operator elsewhere, so "the
app is ahead of its installation" is the normal state between a merge and
the operator's run. The release train (`.github/workflows/release-train.yml`)
has no installation in it: `resolve`, the platform legs, then `report`.

This record fixes the words, the rules and the inventory. It changes no
behaviour. Where a thing below does not exist yet it says **does not exist
yet** and names the leaf that builds it. Counts are deliberately absent
(AGENT_RULES, "Never write a count of this repository down"); the commands
named below print them.

## Decision

### 1. Three numbers, compared per installation

| Number | Who states it | Unit | Exists today? | Where |
|---|---|---|---|---|
| **built against** | the app | schema number | yes | `requiredSchemaVersion`, `lib/core/instance/schema_compatibility.dart`; pinned to the last migration by `test/lint/migration_version_marker_test.dart` |
| **needs at least** | the app, and each feature | schema number | **no.** The app has only the built-against number (it is used as "needs"). A per-feature "since" exists for four features, `featureOperationSince` in `lib/features/workspace/domain/feature_operation.dart`, but it is compared with the build's number, not the installation's | K2 (#3729) |
| **accepts at least** | the installation | the app's **compatibility number** | **partly.** The app carries the number (`appCompatibilityNumber`, `lib/core/instance/app_compatibility.dart`) and reads the floor (`appFloorProvider`, `lib/core/backend/app_floor.dart`); the server's `deskilo_app_floor()` arrives in a later migration, and until then an installation without it answers "no floor" | K1 (#3726) |

Three terms are fixed here because three readers have confused them:

- **Schema number** — the value of `public.deskilo_schema_version()`, written
  by the last statement of every migration (AGENT_RULES, "Every migration ends
  with its version"). Read once per process by `readSchemaVersion` in
  `lib/core/backend/schema_version.dart`. A missing function is an *answer*
  (the server predates 0226, so it is `behind`); a timeout or no network is
  *not* an answer (`SchemaVersionUnavailable`, so `unknown`, which never
  blocks). The doctor reads it the same way (`lib/core/instance/instance_doctor.dart`).
- **Compatibility number** — one integer the app carries, **independent of
  the schema number**, raised by a release that an installation may need to
  require, and published the same way on every distribution channel. It does
  not exist yet (K1). The application version in `pubspec.yaml` is not it: it
  names a build, not a requirement. A schema number cannot tell two app
  releases apart (two releases can share a schema and differ in a client fix
  the installation must demand), so "accepts at least" is stated in this
  number and never in a schema number. An app from before the number exists
  counts as the lowest. A version an app states about itself is not a
  credential: an old contract can only be ended by the server.
- **Release** — a git tag `v<version>+<build>` that the release train builds
  (`git tag --sort=-creatordate` lists them). **Available on a channel** means
  published to that channel's users, not tagged. K4 and K5 count in releases
  *available on a channel*. The milestone called v2.2 is neither a
  compatibility number nor a database marker.

The counterexample the decision is tested against: app A and app B are both
built against schema 717; B contains a client fix an installation must
require. A floor stated in the compatibility number rejects A and accepts B
without pretending the database changed. A newer app built against a
different schema, on an older but sufficient server, is judged by the
schema numbers alone. The two comparisons stay separate.

Today, only the first number exists, and the gate it feeds is
`lib/app/schema_gate.dart`: `behind` sends every route except the server
screens, the help, the privacy page and the Demo to `/server-update`;
`ahead` and `unknown` gate nothing.

### 2. What a person sees, per installation

| Situation | Behaviour | Exists today |
|---|---|---|
| installation older than the app needs | one screen for that installation: it needs an update; an administrator sees which migrations | partly: `behind` blocks the whole app, not only that installation; the migrations list is the doctor's |
| installation older than a feature needs | the app works; that feature is not offered; an administrator sees why | no (K2) |
| installation newer than the app | the app works and ignores what it does not know; a soft notice | works (`ahead` gates nothing); the notice does not exist |
| app older than the installation accepts | blocked for that installation, with the way to update | partly (K1): the installation the app is signed in to, with the update screen and the way out; connected installations follow with K2's per-installation reads |

Other installations are never affected by one installation's verdict. Today
the verdict is one per process, for the app's own client; making it per
installation is part of K1 and K2.

### 3. The rules that keep an older app right
These bind every migration and every contract change from the day this
record is accepted, including v2 and v2.2 leaves under review.

1. **Add, move the readers, remove — three steps.** A removal or a
   narrowing comes only after the installation's "accepts at least" was
   raised past the last app that read the old shape. Until K1 exists nothing
   can raise that floor, so until then nothing is removed or narrowed.
2. **A function keeps its meaning for a caller that does not send a new
   parameter.** A new parameter has a default that reproduces the old
   behaviour. A changed signature is a new function, not a changed one.
3. **No second meaning.** A column or a status value is never given a
   second meaning; a new meaning is a new column or a new value.
4. **An object the app writes whole is merged on the server, never
   replaced.** An older app writing back an object must not delete keys it
   does not know.
5. **Tolerant reading.** Everything read from a server tolerates what it
   does not know: an unknown feature, business kind, status, part of a
   proposal. Tolerant means one of three words, stated per reader:
   - **refuse** — the whole thing is rejected with a named reason;
   - **ignore** — the unknown part is dropped, the known part is used;
   - **show generically** — the unknown value is displayed as what it is
     (an unlabelled state, the frozen text), never as a guess.
   A fourth behaviour is **not allowed**: *default silently* — reading an
   unknown or missing value as a known one (an unknown status read as
   `draft`, an unknown version read as 1). A reader that must fall back
   falls back to a state that asserts nothing (`unreviewed`, `unknown`).
   The enforcement is K3 (#3730); this record names the rule.
6. **A migration states its effect on apps**, on its own line beside the
   risk line (section 4).
7. **Everything stored or exchanged with a version of its own names it**,
   and its reader says what it does with a higher one (section 5).
8. **Optional fields a reader drops are not a filter.** A search filter, a
   limit or a permission is not optional for an older app: a server that
   cannot be filtered by an older app says so rather than ignoring the
   parameter (decided on #3553).

### 4. The line every migration carries
Next to `-- risk:` (second line, AGENT_RULES) the file carries one line:

```
-- apps: additive
-- apps: needs app at least N
-- apps: breaks apps below N
```

`N` is a compatibility number. `breaks apps below N` raises "accepts at
least" in the same file. `additive` is the default claim and is the one a
reviewer checks against rules 2 to 4. The line is **required from the next
migration after this record**; earlier migrations are classified by the
consumer-contract comparison, not by a header. It is **not yet enforced**:
the lint beside `test/lint/migration_version_marker_test.dart` is K4
(#3731), and so is the comparison that proves the last released app's
calls still exist with the meaning it expects (the two committed copies of
`assets/instance/contract.txt`, at the release tag and at master).

### 5. Everything that has a version of its own
Measured in the code on master `55fc2cd68`; each row's *field* is the wire
or file key that carries the version, and *reader* is what the code does
with a different one. To re-measure: search the hand-written Dart under
`lib/` and `packages/` for wire keys that contain `version`. Refuse,
ignore and show generically are as defined in section 3, rule 5.

| What | Field | File (reader) | A higher version | A missing or unreadable one |
|---|---|---|---|---|
| the schema the app is built against | `requiredSchemaVersion` | `lib/core/instance/schema_compatibility.dart` | server newer: `ahead`, ignores what it does not know | server without the function: `behind`; no answer: `unknown`, never blocks |
| the server's catalogue (routines, constraints, triggers) | none; one digest per line | `assets/instance/contract.txt`, generated by the database job | not read by any app; compared by CI only | n/a |
| the instance bundle | none; the ordered migration files | `assets/instance/bundle.json`, built by `tool/build_instance.dart`, pinned by `test/lint/instance_bundle_test.dart` | n/a | n/a |
| a feature | the `WorkspaceFeature` enum, the manifest and the server's `feature_registry()` | `lib/features/workspace/domain/feature_manifest_*.dart`, generated into SQL by `feature_registry_sql.dart` | not read by a version; a stored flag over the registry default decides (`feature_registry_sql.dart`) | a missing stored flag takes the registry default |
| a feature's assessment | `schemaVersion` of the stored assessment | `lib/features/workspace/domain/feature_lifecycle.dart` | **show generically**: another version reads as `unreviewed` | `unreviewed`; an unknown lifecycle reads as `active` |
| a feature's operation classes | `featureOperationSince` (a schema number) | `lib/features/workspace/domain/feature_operation.dart` | n/a | a feature without an entry claims nothing |
| the public network protocol and each operation | `protocol_versions`, per operation `versions`, request header `x-deskilo-operation: <id>@<version>` | `contracts/public_network/operations.json`, `lib/core/public_network/public_network_negotiator.dart`, `public_network_codec.dart` | **refuse**: no common version is `versionUnsupported`; the server refuses a version it does not support; a required term the codec does not know is `unknown required term`. The unknown-value semantics are stated in the contract file and are not restated here | an unlabelled request means the operation's `unlabelled` version; a server without roles is read as combined |
| the assistant's operations | `version` of `deskilo.mcp.operations` | `contracts/mcp/operations.json`, generated into `lib/core/mcp/mcp_contract.g.dart` (`mcpContractVersion`) | compiled in: no reader of a higher version exists | n/a |
| a person's bookings page from another installation | `schema_version` | `lib/features/reservations/domain/my_reservations.dart` | **refuse** on any difference, lower or higher (`incompatible`); an unreadable single item is counted in `unreadable`, never guessed | refused (the integer is required) |
| a booking intent kept on the device | `schema_version`, stamped with the built-against number | `lib/features/reservations/domain/booking_intent.dart` | not compared: it is stored, not checked | **default silently** to 0 for a missing or non-integer value; an entry missing a required field is dropped. The stored number is not used to decide anything. |
| the direct-message and inbox pages | `schema_version` | `lib/features/directory/domain/personal_message_directory.dart`, `inbox_sources.dart` | **refuse** on anything but 1 | refused |
| the accounting source snapshot | `version` | `lib/features/money/domain/accounting_source_snapshot.dart` | **refuse** on anything but 1 | refused |
| a line's frozen facts | `version` | `lib/features/money/domain/invoice_line_text.dart`, `presentation/settlement_texts.dart` | **show generically**: the caller prints the frozen label | the same |
| a commercial line snapshot | `version` | `packages/deskilo_invoice_model/lib/src/commercial_line_snapshot.dart` | **refuse**: `CommercialLineUnsupported(unknownVersion)`; an unknown supply is refused too | refused as malformed |
| a business kind's profile | `profile_version`, `profile_digest` | `lib/features/workspace/domain/business_kind.dart` | not compared | **default silently** to 1 with an empty digest (a server from before 0834). The digest is empty, so a review against it cannot be taken for another; K3's list |
| a workspace template | `schema_version`, `template_version`, the server's `supported_schema_versions` and `status` | `lib/features/workspace/domain/workspace_template.dart`, `template_inspection.dart` | the server decides: `unsupported_version` is read as a status; any status the app does not know reads as `unknown` | **default silently** to 1 for both versions. Not allowed by rule 5; K3's list. |
| a workspace export | `format_version` and `schema_version` | written by `lib/features/workspace/domain/workspace_export_bundle.dart` | **there is no reader in the app** | n/a |
| a person's export | `format` and `version` | `lib/features/me/domain/personal_export.dart` | **refuse** (`malformed`) | refused |
| a report layout file (XML) | root `schema`, `version` | `lib/features/money/domain/report_layout_file.dart` | **refuse** (`unsupportedVersion`) | refused |
| a report design file (JSON) | `version` | `lib/features/money/domain/report_design_file.dart` | **refuse** (`unsupportedVersion`) | refused |
| a workspace file (XML) | `version` on `deskilo-workspace` | `lib/features/workspace/domain/workspace_xml_part2.dart` | **refuse** (`unsupportedVersion`) unless in `WorkspaceXmlSchema.supportedVersions` | refused (the attribute is required) |
| a BI visual | `metricVersion` (1..99) | `lib/features/workspace/domain/bi_report_visual.dart` | outside the range: the visual is dropped (**ignore**) | the visual is dropped |
| the accountant CSV | `format_version` | written by `lib/features/money/domain/accountant_handoff.dart` | no reader in the app | n/a |
| a recorded task guide and package | `schema_version`, `action_contract_version`, `package_version` | `lib/features/task_recorder/guide/guide_codec.dart`, `package/task_package.dart`, `package/storyboard_review.dart` | **refuse** above the app's own number; an older one is read | refused |
| the support bundle and its evidence | `version`; `schema_version` of the evidence | `lib/core/diagnostics/support_bundle.dart` (written), `support_evidence.dart` (read) | the evidence reader returns nothing on anything but 1 (**ignore**: the evidence is unavailable) | the same |
| a setup journey, a quote draft, a local setup step | `version` | `setup_journey.dart`, `customer_quote.dart`, `setup_step_draft.dart` | **not a format version**: an edit counter used as an optimistic lock (`p_expected_version`). Never read as a catalogue version | n/a |

What this table does **not** contain, because it does not exist in the
code today: a **catalogue version of a stored setup journey** (the journey
stores answers and an edit counter, not the catalogue they answered), a
**recipe** with a version, a **versioned proposal**, and a **compatibility
number**. The first three arrive with the studio (v3) and are rows of this
table from the day they land; the fourth with K1.

Three policies are in the code today: refuse on any difference, degrade to
a safe reading, and default silently. The third is not allowed (rule 5):
the rows marked so are the list K3 converts. The rows that refuse on any
difference (a bookings page, the inbox pages, the accounting snapshot)
keep doing so: an exact match is the contract of a page the app does not
tolerate in part.

### 6. The v2.2 producers
Each of these adds a shape an older app meets. Each reuses a contract above
rather than getting a global number; the versions that exist today:

| Producer | What exists today | Version carrier |
|---|---|---|
| commercial lines with a frozen snapshot (#4162) | the snapshot reader | `version` in the snapshot, refuse on another |
| a standalone invoice from a source (#4165) | the command interface `StandaloneInvoiceCommands`, `lib/features/money/domain/standalone_invoice.dart` | none of its own; its wire shape is a function (rule 2) |
| a sent or accepted quote revision (#4166) | `revision` and `draft_version` on `QuoteRevision`, `lib/features/money/domain/customer_quote.dart` | `revision` is a content revision; `draft_version` an edit counter that reads as 1 when missing, which K3 lists |
| an optional billing-purpose binding (#4164) | does not exist yet in `lib/` or `supabase/migrations/` | an optional parameter with a default (rule 2) |
| Me's business finance projection per installation (#4167) | does not exist yet | the personal export's `version` governs a stored copy; a live read has none yet |
| stock receipts, movements and returns (#4161, #4171, #4172) | receiving commands in `lib/features/stock/` | none of their own: server functions, rules 2 and 3 |

A new producer adds its own row to section 5 in the same pull request.

### 7. Where each concept lives today
- built against, and the comparison `compareSchema`: `lib/core/instance/schema_compatibility.dart`
- reading an installation's number: `lib/core/backend/schema_version.dart`
- the gate: `lib/app/schema_gate.dart`
- the instance doctor: `lib/core/instance/instance_doctor.dart`
- per-feature "since": `lib/features/workspace/domain/feature_operation.dart`
- the feature manifest and the server's feature registry: `lib/features/workspace/domain/feature_manifest_*.dart`, `feature_registry_sql.dart`
- the server's catalogue: `assets/instance/contract.txt`
- the instance bundle: `assets/instance/bundle.json`
- the promise to operators: `docs/guides/OPERATIONS.md`, "Version compatibility". This record replaces that table's reasoning; the table now points here and says what is supported today

## Consequences
- Nothing changes at runtime. The leaves build it in order: K1 (#3726)
  the installation's floor and the app's compatibility number; K2 (#3729)
  what each feature needs; K3 (#3730) the tolerant-reading lint and the
  rows marked silent above; K4 (#3731) the `-- apps:` lint and the proof
  from the last released app; K5 (#3732) the release train looking at the
  installation and the support window.
- The support window (how long an app version stays accepted, including the
  slowest store) is a parameter of the installation, not a constant (K5).
  The first floor above "lowest" waits a support window after the first
  app that reads the floor is available on a channel.
- Out of scope: how many members use an app that cannot show a feature (the
  device's app version is a privacy decision first), automatic application
  of migrations to production, and downgrades.
