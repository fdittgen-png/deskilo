# Agent rules (binding — humans and AI assistants)

These rules are version-controlled so a fresh clone sees them. They mirror the sibling project tankstellen/Sparkilo.

## HARD RULES

1. **No hard-coded user-facing text.** Every string goes through ARB / `AppLocalizations` with a defensive English fallback. English (`en`) is the canonical locale — every key must exist there. FR, DE, ES and IT are maintained launch locales: every new key needs all five translations in the same PR. Enforced by a lint test with a ratchet-to-zero baseline.
2. **Never develop without a GitHub issue.** Large work (> 1 PR or multiple subsystems) becomes an Epic with a maintainer-validated breakdown before implementation starts.
3. **Clean codegen before push.** After touching any freezed class or `@riverpod` annotation: `dart run build_runner build --delete-conflicting-outputs` from clean; commit the generated files; zero drift on push.
4. **Locale key parity.** The key-parity test fails CI if any locale is missing keys vs. `app_en.arb`.
5. **The setup questionnaire never lags the app.** Any change to a configurable parameter updates `web/setup.html` — field, XML export, XML import — in the SAME PR. Gated by `test/lint/setup_html_test.dart`; see the section below.

## Coding rules

- No `print` — use `debugPrint`. No `catch (_) {}`. Every `catch (e)` is `catch (e, st)` with the stack trace logged.
- No inline `BorderRadius.circular(n)` — use `AppRadius` tokens.
- No `setState` for shared state — Riverpod providers only; `@riverpod` codegen, no manual `Provider`/`StateProvider`.
- `presentation/` never imports `data/` — go through `providers/`. `domain/` is pure Dart.
- After `await` in widget code: `if (!context.mounted) return;`.
- No magic strings/numbers in business logic — constants class + pinning test.
- Dates, numbers, currency: locale-aware formatting only (`intl`), never raw string formatting. Currency follows the workspace country.
- All timestamps stored UTC; recurring series recur in workspace-local time.
- No third-party tracking, no GPL dependencies (ADR 0009). FCM is the push transport (ADR 0011).

## Feature management (lifetime rule, #502)

- EVERY user-facing functionality ships behind a `WorkspaceFeature` flag — for the lifetime of this project. A new functionality lands with: the enum value, a `featureManifest` entry (defaultOn/requires), `featureXxx`/`featureXxxDesc` l10n keys ×5, `features.contains(...)` gates on its UI surfaces, and the bumped pin in `test/lint/feature_registry_test.dart`.
- Default ON unless the feature is risky or needs owner setup; dependent features declare `requires` so the Features screen explains the chain.
- OFF must degrade honestly: the entry points disappear (and their routes redirect); already-stored data stays untouched.

## Testing rules

- TDD pyramid 70/20/10. Bug fixes: write the failing test FIRST, calling the exact method the failing UI calls.
- Twin-bug audit before closing: grep for the same anti-pattern elsewhere; fix all occurrences in one PR.
- Producer + consumer ship together — never merge the reader half of a feature without the writer.
- If a fix adds an affordance (button, banner), a test must tap it.
- Structural widget tests only — no platform-baselined golden PNGs.
- Fakes over mocks for the service layer; `mocktail` only for widget-level callbacks.

## Git rules

- Branch off `master`; conventional commits; PRs < 400 lines (excluding generated); squash-merge; `Closes #NN`.
- Forbidden: direct commits to `master`, force-push to `master`, `--no-verify`, amending pushed commits.

## The setup questionnaire (`web/setup.html`) — no exceptions

**A change to a configurable parameter is not finished until `web/setup.html` carries it,
in the same PR.** Not "soon", not a follow-up issue. The questionnaire is what a new owner
answers *before* opening the app, it is published at the URL all five guides link to, and
an answer it collects has to be one the app can actually store.

A parameter change therefore lands as one commit touching all of:

1. the domain class (`BookingPolicies`, the feature registry, …) and its settings screen,
2. the five guides + regenerated `assets/help/*.md`,
3. `web/setup.html` — the **field**, the **XML export** and the **XML import**,
4. the jsdom harness that drives the page.

`test/lint/setup_html_test.dart` enforces the mechanical half: every `WorkspaceFeature`
must appear with the registry's own `defaultOn`, every `booking_rules` key the client
writes must be carried by the XML, all four outside-hours modes and every granularity must
be selectable. It fails the build on drift and names the offender — it does not need a
human to notice.

What the gate cannot check is prose. When a rule changes meaning, the questionnaire's
explanatory text and its behaviour matrix have to change with it; that part is on the
author.

**Backward compatibility is part of the contract.** A questionnaire someone exported last
month must still load: keep reading retired keys on import (`grid_within_hours` →
`walkup_only`, `admin-checkout` → `admin-check-out`) even though nothing writes them any
more, and merge stored answers ONTO the defaults so a file written before a field existed
comes back with that field at its default instead of crashing `render()`.

**Publishing is a separate step.** Merging updates the repo copy; the live page only moves
when the web workflow runs with `deploy=true` (or a production release train). A merged
change that is not deployed leaves the guides describing a page that does not match.

## Agent tooling (MCP)

The repo ships its own MCP configuration so a fresh clone gets the same tools with no
setup: `.mcp.json` declares the servers, `.claude/settings.json` pre-approves them and
carries the permission allow-list. `.claude/settings.local.json` stays git-ignored for
per-machine opt-ins.

**Dart & Flutter server** (`dart_mcp_server`, official, by the Dart/Flutter team).
Installed globally — `dart pub global activate dart_mcp_server` — because it cannot be a
dev dependency here: it needs `cli_util ^0.5.0` and `flutter_launcher_icons` pins
`^0.4.1`. `.mcp.json` runs it via `dart pub global run`.

What it is good for:

- `analyze_files` instead of `flutter analyze` — structured, and it blocks until analysis
  is actually complete rather than waiting on a notification that may never arrive.
- `lsp` for real analyzer data instead of grep: `hover`, `signatureHelp`,
  `resolveWorkspaceSymbol`. Each call spins up an analysis server (15–35 s), so plain
  `grep` still wins for a quick literal search.
- `pub_dev_search` before adding a dependency; `pub` for pub commands.
- `dtd` + `vm_service` + `widget_inspector` + `hot_reload` / `hot_restart` +
  `get_runtime_errors` when the question is about what a RUNNING app actually does. This
  is the closest thing to looking at the screen, and it needs no browser extension.

**There is no `run_tests` tool.** Earlier versions had one and this file used to recommend
it; upstream removed it (gone from both the pub 1.1.1 build and the SDK-bundled 0.1.4).
Run tests with `flutter test` — and keep the discipline that already cost this project
once: NEVER pipe it. `flutter test > suite.log 2>&1; echo EXIT=$?` — a pipe masks the exit
code, and a background wrapper once reported success over a suite with seven failures.

**Verified 2026-08-27 against `dart_mcp_server` 1.1.1 — 14 tools.** Probe the server
rather than trusting this list or any README: tool sets move between versions, and a doc
written from release notes is wrong within days. The full set is `analyze_files`, `lsp`,
`pub`, `pub_dev_search`, `read_package_uris`, `rip_grep_packages`, `roots`, `dtd`,
`vm_service`, `widget_inspector`, `hot_reload`, `hot_restart`, `get_runtime_errors`,
`flutter_driver_command`. The `dart-flutter-mcp` skill carries a 30-second stdio snippet
that asks the server for its own list.

The pub build needs **Dart ≥ 3.12**; below that, `dart mcp-server` is the only route. The
two differ by exactly ONE tool — the bundled 0.1.4 has the same thirteen minus
`vm_service`.

**A fresh clone needs one command before this works**, because `.mcp.json` runs a globally
activated binary rather than a project dependency:

```bash
dart pub global activate dart_mcp_server
```

Without it the server simply fails to start. That is the price of the `cli_util` conflict
above; a dev dependency would have travelled with the repo, and cannot.

**Supabase.** The tracked allow-list holds read-only tools only (`list_migrations`,
`list_tables`, `get_advisors`, …). `execute_sql`, `apply_migration` and
`deploy_edge_function` reach the hosted project, so each developer opts in for themselves
in `.claude/settings.local.json`; the allow-list removes a prompt, never a credential.
Project-destructive tools (`pause_project`, `delete_branch`, `reset_branch`,
`create_project`) are explicitly denied.

`execute_sql` is what makes the **rolled-back live-RPC harness** possible: one
`DO $harness$` block, fixtures and `set_config('request.jwt.claims', …)` impersonation at
top level, per-case `begin/exception` subtransactions, and a final
`raise exception 'HARNESS_RESULTS %'` to smuggle the JSON out while aborting everything.
That harness has caught defects no unit test would have — always run it after applying a
migration that changes an RPC.

## Help symbols live in BOTH places (#763)

Every parameter and entry field carries a small help symbol in TWO
places: the app's forms (`HelpDot` / `HelpDotTitle`, lib/core/help/
help_dot.dart, `/help?topic=` jump, gated by `formHelpHints`) and the
setup questionnaire (`helpIcon` in web/setup.html, wiki links). Adding,
renaming or removing a parameter updates BOTH in the same PR — a field
with a symbol on one surface and none on the other is a bug. Topics are
localized l10n getters pinned to guide headings by
test/core/help/help_hint_test.dart.

## Guides & illustrations (#765)

The wiki (`docs/wiki/*.md`) is the SOURCE; `dart run tool/build_help.dart`
regenerates `assets/help/` — never edit the help output directly. Layout
rules for images:

- **One topic-sized image beside the paragraph it explains, each with its
  own one-line italic caption.** No rows of 3+ images sharing a caption.
- **Whole-form stitches** live only inside `<details><summary>…</summary>`
  at their wiki section's end; `build_help` strips details blocks, so the
  in-app help never regains giant image blocks.
- **Every heading a help topic or setup anchor points at is pinned** by
  `test/core/help/help_hint_test.dart` (topics ×5 must match a guide
  heading) and the anchor check against `web/setup.html` — rename a
  heading and the build, not the reader, breaks.
- The five guides stay structurally parallel: same image names, same
  heading skeleton. Verify with per-name `<img` counts when editing.

## Validation domains grow in FOUR places (#767/#769)

A new server-side validation domain (`events_type_check` +
`validation_policies` check) is not finished until the SAME PR carries:
the client card in `validation_settings_screen.dart` (`_cardTypes` — the
price-negotiation domain shipped server-side in #739 and stayed
unconfigurable for weeks because this list lagged), the `DOMAINS` entry
plus feature gate in `web/setup.html`, and the guides' card count/list
×5. The events feed line must give validators what they DECIDE on (a
deviated amount shows the validated amount and the member's reason).

## Printed reports: the window-envelope contract (#873/#874) — no exceptions

Every document the app posts is folded into a DL window envelope. These
millimetres are a **must**, not a preference, and they are measured from
the PAGE edge — never from the document's own margins, because the
envelope ignores those too.

| Zone | Band | Position |
|---|---|---|
| Sender | `header` | 20 mm from the top and left edges; it owns 20→45 mm and no more |
| Recipient | drawn by the engine | 110 mm from the left (FR) or 20 mm (DIN), 45 mm from the top — 50 mm is the outer limit — inside an **85 × 40 mm** aperture |
| Identification | first lines of `body` | resumes at **90 mm**: the word *Facture*, the number, the issue date and the service date |
| Footer | `footer` | **pinned to the bottom of EVERY page**: bank details, seller address, contact |
| Page 2+ | `continuation` | a short strip naming the document — **never** the letterhead again |

**Three zones, always.** Header fixed to page one, body flowing, footer
fixed to every page. A band that flows where it should be fixed is a
defect, not a layout variant.

**Never put anything in 45→90 mm** other than the recipient. That band
is the aperture plus its tolerance; ink there is either invisible in the
envelope or collides with the address.

**The recipient block is mandatory.** A French invoice without the
buyer's name *and address* is non-compliant
([mentions obligatoires](https://www.economie.gouv.fr/entreprises/gerer-son-entreprise-au-quotidien/gerer-sa-comptabilite-et-ses-demarches/mentions-obligatoires-dune-facture-tout-savoir)),
and an empty aperture posts a blank window.

**Prove it on the artefact, never on the code.** Every one of these has
been wrong in a document that was printed, and each time the widget tree
looked right. So:

* `test/features/money/invoice_geometry_test.dart` is the gate — it
  inflates a generated PDF, walks the drawing operators keeping the
  translation stack, and asserts every zone in millimetres.
* `test/features/money/report_probe_test.dart` is the **local probe**:
  run it, paste a workspace's real bands into `_bands`, and it prints
  each zone with a verdict and writes the PDF to
  `build/pdf-conformance/` so it can be opened and folded.
* `lib/features/money/domain/report_conformance.dart` holds the numbers
  once, so the gate and the probe cannot drift apart.

Changing any of these millimetres means changing that file, and the
reason belongs in the commit message.
