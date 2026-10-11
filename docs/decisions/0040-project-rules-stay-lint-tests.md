# ADR 0040 — Project rules stay lint tests; the analyzer carries the language rules

**Status:** accepted · **Date:** 2026-10-11 · **Refs:** #2389, #2381

## Context
The code review of #2381 measured 50 analyzer rules beyond `flutter_lints`
against master and asked two questions: which of them to turn on, and
whether the project's own rules (`no_free_function_commands`,
`no_nullable_l10n`, the layering, the file budgets, the ratchets), which
are regex lint tests under `test/lint/`, should move to `custom_lint`
plugins.

## Decision
1. **The analyzer carries the language rules.** Every rule of the review
   is on except the three below, with its sites fixed (`dart fix --apply`
   file by file, never on a directory, never with `dart format`). A rule
   whose existing sites cannot be fixed mechanically without changing an
   API (`avoid_positional_boolean_parameters`) is on for new code; each
   kept site carries `// ignore: <rule> — #2389, <why>`, and
   `test/lint/ignore_budget_test.dart` counts them down.
2. **Not enabled, by decision:**
   - `public_member_api_docs` (8 042 sites): the repository documents the
     *why* where it is not obvious, not every member.
   - `prefer_expression_function_bodies`: style only.
   - `avoid_classes_with_only_static_members`: all 31 of its sites are
     already `abstract final class` namespaces (`Currencies`,
     `WorkspaceTime`, `AppSnack`, …), the Dart 3 idiom the review asked
     for. The rule does not recognise it, so turning it on would force
     flattening the namespaces into top-level functions.
   - `one_member_abstracts` and `unnecessary_await_in_return` are
     deprecated rules in the pinned SDK.
3. **Project rules stay lint tests**, not `custom_lint` plugins. A lint
   test runs in the suite CI already runs, needs no plugin host (the
   analyzer already hosts `riverpod_lint`, and a second plugin slows every
   `dart analyze`), prints the offending lines, and can hold a ratchet —
   a count that only goes down — which a lint rule cannot.
   `dart analyze --fatal-infos` stays exactly what CI runs.

## Consequences
- A new rule is turned on in one PR, with all of its sites fixed or
  recorded under its issue number.
- `test/lint/ignore_budget_test.dart` holds three counts: every
  `// ignore:` in `lib/`, those naming no issue, and the kept positional
  bools.
- A project rule that a real lint could check cheaper is reconsidered
  case by case, in its own ADR.
