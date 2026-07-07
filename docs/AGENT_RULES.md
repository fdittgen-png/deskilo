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
- No Google Play Services, no Firebase, no third-party tracking, no GPL dependencies. The F-Droid flavor must stay 100% GMS-free (audited by script).

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
