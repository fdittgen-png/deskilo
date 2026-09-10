# Implementation

How the DesKilo repository is organized, built, tested, and shipped. The methodology is inherited 1:1 from the tankstellen/Sparkilo project.

## Repository layout

```
android/                  # Android runner (Play + Android builds)
ios/                      # iOS runner
macos/                    # macOS desktop runner
windows/                  # Windows runner + WiX MSI authoring (installer/deskilo.wxs)
assets/fonts/             # Roboto, embedded into PDF bills (base-14 fonts can't encode €)
docs/
  SPECIFICATION.md        # the product spec (source of truth for behavior)
  PROJECT_OVERVIEW.md     # consolidated reference across all of the below
  wiki/                   # source of the GitHub wiki pages (this site)
  decisions/              # ADRs 0001..0018
  design/                 # design system, payments integration
  guides/                 # e.g. RELEASING.md
  security/               # SUPABASE_RLS_MATRIX.md
fastlane/ metadata/       # store metadata per locale
lib/                      # the app (see Architecture page)
web/                      # browser target (GitHub Pages deploy, opt-in)
supabase/
  migrations/             # 0001..0190 — schema, RLS, RPCs (numbered, immutable)
  functions/              # deployed Edge Functions: create-payment-order,
                          # paypal-webhook, stripe-webhook, mollie-webhook,
                          # send-e-invoice
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
- **The file set is the source of truth for a rebuild; the hosted project's migration *rows* are not.** The two can legitimately differ, and both cases in this repo are documented in the file that absorbed them: a single file may have been applied as several rows (`0070_payment_date_and_period.sql` = rows `payment_date_and_period` + `invoice_annex_occurred_on`), and a superseded interim draft can leave a row behind with no file at all (`0051_single_use_invites_member_validation`, replaced by `0051_personal_invitations` + `0052_member_join_validation`, whose section 0 drops the draft's leftovers). When a draft is superseded this way, the replacing file must be written to converge **from either state** — `drop policy if exists` before `create policy`, `drop … if exists` for the abandoned objects — so a fresh deploy and the hosted project end up identical. Say so in the file header; a name mismatch that is not explained reads as drift.
- Local development is possible with the Supabase CLI (`supabase start`), but the reference deployment is hosted Supabase (decided 2026-07-07).
- Pattern to follow when adding tables: enable RLS immediately, add select policies with the role-helper functions, keep writes behind `SECURITY DEFINER` RPCs, and `revoke execute … from public, anon` on every new function (see migration 0004).
- **Secrets tables get zero policies.** `payment_credentials` (0047) enables RLS and adds *no* policies at all — only service-role Edge Functions and owner RPCs reach it, and the status RPC returns key names, never values. Follow this shape for anything secret.
- Edge Functions are deployed to the hosted project (webhooks run with `verify_jwt` off and authenticate via the payment provider's signature instead). Provider credentials resolve **table-first, env-fallback**, so a single-workspace self-host can configure everything with function env vars alone.

## Feature flags — the gating checklist

When a screen or surface belongs to a `WorkspaceFeature`, gate it at **both** layers (the *enable a feature → get all of it; disable → get none* rule):

1. Hide the entry point: `if (… && features.contains(WorkspaceFeature.x))` in the settings list / tab bar.
2. Guard the route: `featureEnabled(WorkspaceFeature.x)` in its `redirect` in `app/router.dart`.

`/services`, `/payment-config`, `/nfc-config`, and `/accessories` are the reference implementations; the **Features** screen itself must stay ungated. Add a widget test for both the hidden entry and the bounced deep link (see `test/features/profile/settings_sections_test.dart`).

## Testing

```bash
flutter analyze --fatal-infos lib test tool   # infos are fatal in CI too
flutter test                                 # full suite (2600+ tests)
flutter test test/features/<feature>/        # one feature
```

Run `flutter test` **bare**. Piping it (`| tail`, `| grep`) hands you the exit code of the pipe, not of the suite, so a red run reads as green — this has shipped a broken commit more than once.

- Widget tests pump the whole `DeskiloApp` with `ProviderScope(overrides: standardTestOverrides(...))` — fakes for auth, workspace, reservations, money, notifications live in `test/helpers/mock_providers.dart`. Fakes mirror server behavior including RLS visibility (e.g. `FakeWorkspaceRepository.adminInviteCode` only answers for owners).
- Accessibility is tested (`meetsGuideline(androidTapTargetGuideline)`), so every new tappable affordance needs a big-enough target **and its own test that taps it**.
- Server SQL semantics are documented in the migration files; client tests assert against the fake seam.

## CI

Every push/PR runs *CI · Analyze, test & coverage*: **l10n key-parity
gate · analyze · full test suite · coverage gate (≥ 45 %)**. Its job is
named `analyze · l10n gate · test · coverage`, and that job name is the
required status check on `master`.

Fourteen workflows in all, named `<Group> · <what it does>` so the
Actions sidebar sorts into gates, releases, publishes, status queries
and tools — the convention, the table of what exists and the rules are
in `.github/workflows/README.md`, enforced by
`test/lint/workflow_naming_test.dart`.

The one thing to know before renaming anything there: **a workflow name
is free to change, a job name is not.** A job name is a required
status-check context, so renaming one can block auto-merge until branch
protection is updated in lockstep.

`Release · macOS DMG`, `Release · Windows MSI`, `Publish · Web app` and
`CI · F-Droid no-GMS audit` also build on pull requests that touch their
target, so a change that breaks one platform fails there rather than in
front of a user.

Git discipline — branch off `master`, PRs only, green CI before merge, squash-merge, delete the head branch — is **server-enforced since 2026-08-01**, and the configuration lives as data in `scripts/branch_protection.sh` (verify / apply / show) rather than in a console nobody can diff. `master` requires the `analyze · l10n gate · test · coverage` check, blocks force-pushes and deletions, and demands linear history. Strict mode is deliberately **off** (no merge queue → strict makes every merge stale every other open PR, quadratic CI for file-disjoint changes); the corollary is a merge discipline: **serialise merges** rather than arming several at once. `enforce_admins` is off, so the maintainer keeps an admin escape hatch — the rules in `AGENT_RULES.md` still apply to its use. An advisory CI step runs `verify` so drift between the committed target and the live configuration is reported, not discovered.

## Release

- Semver + annotated tag after the release PR merges; release notes generated from PR titles.
- Android: Play (internal → closed → open → production). **F-Droid is
  supported** through the libre flavour (ADR 0012): the app depends on
  `deskilo_push`, and the F-Droid build swaps in `deskilo_push_foss`,
  which has no Google dependency. *CI · F-Droid no-GMS audit* proves it
  on every pull request; *Publish · F-Droid release APKs* ships the
  binaries F-Droid reproduces against. FCM is the push transport for
  store builds only.
- iOS: TestFlight via fastlane (owner-held App Store Connect secrets), internal groups plus an external group with a public link.
- Desktop: Windows ships as an MSI from the `windows-msi` workflow, macOS as a Developer-ID-signed, Apple-notarised, stapled DMG from `macos-app` — both attached to the release on a `v*` tag. (Spec §12 left the macOS channel open; it is settled as notarised direct download.)
- Web: an opt-in GitHub Pages deploy from *Publish · Web app*
  (`-f deploy=true`).
- One dispatch of *Release · Train (all platforms)* with `-f track=alpha`
  puts iOS and Android on the same commit, which is the point of having
  a train at all.

## Adding a feature — checklist

1. File the issue (or Epic + children if > 1 PR).
2. Branch `feat/<slug>` off master.
3. Write the failing test first.
4. Model in `domain/` (freezed), seam in the repository interface, Supabase impl in `data/`, provider, screen.
5. New strings → an ARB fragment per locale in `lib/l10n/_fragments/`,
   then `dart run tool/build_arb.dart && flutter gen-l10n`.
6. New tables/RPCs → numbered migration with RLS + revokes and the six
   system columns (`ensure_system_columns`); **harness it first** — run
   the whole thing inside a rolled-back transaction against the hosted
   project before `apply_migration`. Update the fake repository to
   mirror the server contract.
7. Every functionality goes behind a `WorkspaceFeature`, and
   `web/setup.html` changes in the *same* PR as any parameter.
8. Anything a user can see or configure gets a guide section with an
   `<!-- anchor: … -->`, and the symbol beside it points there.
9. `flutter analyze --fatal-infos lib test tool && flutter test` green
   locally, then PR with the template (What/Why/Testing/Completeness).
