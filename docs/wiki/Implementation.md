# Implementation

How the DesKilo repository is organized, built, tested, and shipped. The methodology is inherited 1:1 from the tankstellen/Sparkilo project.

## Repository layout

```
android/                  # Android runner (Play + F-Droid flavors)
ios/                      # iOS runner
macos/                    # macOS desktop runner
windows/                  # Windows runner + WiX MSI authoring (installer/deskilo.wxs)
assets/fonts/             # Roboto, embedded into PDF bills (base-14 fonts can't encode €)
docs/
  SPECIFICATION.md        # the product spec (source of truth for behavior)
  wiki/                   # source of the GitHub wiki pages (this site)
  decisions/              # ADRs 0001..0008
  design/                 # design system
  guides/                 # e.g. RELEASING.md
fastlane/ metadata/       # store metadata per locale
lib/                      # the app (see Architecture page)
supabase/
  migrations/             # 0001..0043 — schema, RLS, RPCs (numbered, immutable)
  functions/              # Edge Function scaffolding (online payments)
test/                     # unit + widget tests, fakes in test/helpers/
integration_test/         # end-to-end flows
tool/ tools/ scripts/     # repo tooling
```

## Conventions (hard rules)

- **Issue-first**: no code without a GitHub issue; work larger than one PR becomes an Epic with a validated breakdown.
- **GitHub Flow**: branch off `master`, conventional commits (`feat(scope): …`), one concern per branch, **every change is a PR < 400 lines** (excluding generated), squash-merge, `Closes #NN`, no direct commits to master.
- **No hard-coded user-facing strings** — ARB only, lint-ratcheted; the key-parity CI gate fails if any locale misses a key.
- **Clean codegen before push** — generated files (`*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`) are committed and must be regenerated, never hand-edited.
- **TDD pyramid 70/20/10** (unit/widget/integration), coverage gate, **fakes over mocks**, failing test before any bug fix, twin-bug audit (grep for the same pattern elsewhere), producer + consumer ship together.
- **SPDX header** (`// SPDX-License-Identifier: 0BSD`) in every file.

## Building & running

Prerequisites: Flutter (pinned stable), Dart ≥ 3.11.

```bash
flutter pub get
flutter gen-l10n                                     # localizations
dart run build_runner build --delete-conflicting-outputs   # riverpod/freezed/json codegen
```

| Target | Command |
|---|---|
| Android (debug) | `flutter run -d <device>` |
| Android APK | `flutter build apk` (per-ABI splits in release CI) |
| iOS | `flutter run -d <iphone>` / TestFlight via fastlane |
| macOS | `flutter run -d macos` · release: `flutter build macos`, app at `build/macos/Build/Products/Release/DesKilo.app` |
| Windows | `flutter build windows` · MSI: `gh workflow run windows-msi.yml -f ref=master` (WiX v5 on CI; artifact `DesKilo-<version>-windows-msi`, attached to releases on `v*` tags) |

The macOS runner is sandboxed; entitlements already include the network client (Supabase), camera (QR scan), and user-selected file access (XML import/export, PDF save).

## Backend / migrations

- Migrations are numbered SQL files in `supabase/migrations/`, applied in order to the hosted reference project (and by self-hosters). They are **immutable once applied** — fixes are new migrations.
- Local development is possible with the Supabase CLI (`supabase start`), but the reference deployment is hosted Supabase (decided 2026-07-07).
- Pattern to follow when adding tables: enable RLS immediately, add select policies with the role-helper functions, keep writes behind `SECURITY DEFINER` RPCs, and `revoke execute … from public, anon` on every new function (see migration 0004).

## Testing

```bash
flutter analyze          # zero tolerance
flutter test             # full suite (700+ tests)
flutter test test/features/<feature>/   # one feature
```

- Widget tests pump the whole `DeskiloApp` with `ProviderScope(overrides: standardTestOverrides(...))` — fakes for auth, workspace, reservations, money, notifications live in `test/helpers/mock_providers.dart`. Fakes mirror server behavior including RLS visibility (e.g. `FakeWorkspaceRepository.adminInviteCode` only answers for owners).
- Accessibility is tested (`meetsGuideline(androidTapTargetGuideline)`), so every new tappable affordance needs a big-enough target **and its own test that taps it**.
- Server SQL semantics are documented in the migration files; client tests assert against the fake seam.

## CI

Every push/PR runs: **analyze · l10n key-parity gate · full test suite · coverage**. Additional workflows: `dev-apk` sideload build, `android-boot` emulator smoke, `play-internal` / `play-listing` (Google Play), `ios-testflight`, and `windows-msi` (Windows build + MSI packaging; also runs on PRs touching `windows/**`).

Branch protection: direct pushes to `master` are blocked; PRs need green CI; squash-merge only; head branches auto-delete.

## Release

- Semver + annotated tag after the release PR merges; release notes generated from PR titles.
- Android: Play (internal → closed → open → production) + a Google-services-free F-Droid flavor audited by script.
- iOS: TestFlight via fastlane (owner-held App Store Connect secrets).
- Desktop: Windows ships as an MSI from the `windows-msi` workflow (per-release asset on `v*` tags); the macOS channel is still an open decision (spec §12).

## Adding a feature — checklist

1. File the issue (or Epic + children if > 1 PR).
2. Branch `feat/<slug>` off master.
3. Write the failing test first.
4. Model in `domain/` (freezed), seam in the repository interface, Supabase impl in `data/`, provider, screen.
5. New strings → all five ARB files → `flutter gen-l10n`.
6. New tables/RPCs → numbered migration with RLS + revokes; update the fake repository to mirror the server contract.
7. `flutter analyze && flutter test` green locally, then PR with the template (What/Why/Testing/Completeness checklist).
