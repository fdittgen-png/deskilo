# Agent rules (binding — humans and AI assistants)

These rules are version-controlled so a fresh clone sees them. They mirror the sibling project tankstellen/Sparkilo.

## HARD RULES

1. **No hard-coded user-facing text.** Every string goes through ARB / `AppLocalizations` with a defensive English fallback. English (`en`) is the canonical locale — every key must exist there. FR, DE, ES and IT are maintained launch locales: every new key needs all five translations in the same PR. Enforced by a lint test with a ratchet-to-zero baseline.
2. **Never develop without a GitHub issue.** Large work (> 1 PR or multiple subsystems) becomes an Epic with a maintainer-validated breakdown before implementation starts.
3. **Clean codegen before push.** After touching any freezed class or `@riverpod` annotation: `dart run build_runner build --delete-conflicting-outputs` from clean; commit the generated files; zero drift on push.
4. **Locale key parity.** The key-parity test fails CI if any locale is missing keys vs. `app_en.arb`.

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

## Agent tooling (MCP)

The repo ships its own MCP configuration so a fresh clone gets the same tools with no
setup: `.mcp.json` declares the servers, `.claude/settings.json` pre-approves them and
carries the permission allow-list. `.claude/settings.local.json` stays git-ignored for
per-machine opt-ins.

**Dart & Flutter server** (`dart mcp-server`, official, bundled in the Dart SDK). Prefer
it over shelling out — it is the difference between reading a verdict and grepping a
1500-line log:

- `run_tests` instead of `flutter test`. On failure it returns the failing test, expected
  vs. actual and the source location, and nothing else. **Read the text, not `isError`** —
  a failing run still reports `isError: false` and says *"returned a non-zero exit code"*
  in the body. Same trap as a piped exit code.
- `analyze_files` instead of `flutter analyze`; `dart_format`; `pub_dev_search` before
  adding a dependency.
- `resolve_workspace_symbol` / `hover` / `signature_help` instead of grepping for a symbol
  — real analyzer data, not text matching. Each call costs 15–35 s (it spins up an
  analysis server), so plain `grep` still wins for a quick literal search.
- `launch_app` + `get_widget_tree` + `get_runtime_errors` when a question is about what the
  running app actually renders.

Version note: `dart_mcp_server` on pub (1.1.x) needs **Dart ≥ 3.12** and we are on 3.11.5,
so the SDK-bundled 0.1.2+1 is the only route today. When the SDK moves, switch `.mcp.json`
to `dart pub global run dart_mcp_server` for the newer `vm_service` tool and the blocking
analysis call.

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
