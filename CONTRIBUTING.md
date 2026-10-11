<div align="center">

# Contributing to DesKilo

**Spaces, a floor plan to book, a fair account for every member — free software, built in the open.**

[README](README.md) &nbsp;·&nbsp; [Wiki](https://github.com/fdittgen-png/deskilo/wiki) &nbsp;·&nbsp; [Implementation page](https://github.com/fdittgen-png/deskilo/wiki/Implementation) &nbsp;·&nbsp; [User guide](https://fdittgen-png.github.io/deskilo/guide/en.html) &nbsp;·&nbsp; [Specification](docs/SPECIFICATION.md)

</div>

Thanks for helping. The project follows the same working methodology as its sibling [tankstellen/Sparkilo](https://github.com/fdittgen-png/tankstellen). The binding rules live in [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md); this page is the way in.

## Ways to help

| You want to | Start here |
|---|---|
| Try the app and report what you find | Open the [demo workspace](https://fdittgen-png.github.io/deskilo/), then file a [bug report](https://github.com/fdittgen-png/deskilo/issues/new/choose) |
| Test on a phone | [Android closed test](https://play.google.com/apps/testing/de.deskilo.app) or the [iPhone beta on TestFlight](https://testflight.apple.com/join/RgFX9zBe) |
| Suggest a feature | A feature-request issue; read [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) for what the product is for and [`docs/product/CAPABILITIES.md`](docs/product/CAPABILITIES.md) for what is shipped |
| Fix a bug or build a feature | The issue-first flow below |
| Translate or proofread | [Translations](#translations) |
| Improve the guides | [Documentation](#documentation) |
| Run your own instance | The [setup guide](https://fdittgen-png.github.io/deskilo/guide/setup-en.html) and the [user guide](https://fdittgen-png.github.io/deskilo/guide/en.html) |

## Workflow

1. **Issue first.** No code without a GitHub issue (templates: bug, feature request, epic). Work larger than one PR is split into finite checkpoints stated in the issue. Ready, Done and the closure rules are in [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md#ready-done-and-closure).
2. **Branch off `master`** with a type prefix: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/`, `ci/`, `perf/`, `style/`. One concern per branch, short-lived.
3. **Conventional commits**: `type(scope): imperative subject under 72 chars, no trailing period`.
4. **Open a PR** with the template. Keep it **under 400 lines** excluding generated files; split if larger. Link the issue: `Refs #NN` for a partial PR, `Closes #NN` only when the whole acceptance is met.
5. **Squash-merge only**, once the required checks are green.

Forbidden: direct commits to `master`, force-push to `master`, `--no-verify`, amending pushed commits.

Only one branch at a time touches a shared registry (feature flags, migrations, permissions, validation domains). A migration takes the number master's latest plus one at push time. The details are in the rules file and on the [Implementation page](https://github.com/fdittgen-png/deskilo/wiki/Implementation).

## Hard rules

1. **No hard-coded user-facing strings.** Everything goes through ARB / `AppLocalizations`; English (`en`) is canonical.
2. **Issue-first development** (above).
3. **Clean codegen before push.** After touching a freezed class or a `@riverpod` annotation, run `dart run build_runner build --delete-conflicting-outputs` from clean and commit the generated files.
4. **Locale key parity.** Every locale carries every key; CI gates on it.
5. **The setup questionnaire never lags the app.** A change to a configurable parameter updates `web/setup.html` (field, XML export, XML import) in the same PR.
6. **Every functionality ships behind a `WorkspaceFeature` flag**, for the lifetime of the project. Switched off, it degrades honestly: entry points disappear, stored data stays.

The coding rules (Riverpod for shared state, no `print`, `AppRadius` tokens, UTC timestamps, locale-aware formatting, no third-party tracking, no GPL dependencies) are in [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## Before you push

Run these locally and see them green:

```bash
dart analyze --fatal-infos            # exactly what CI runs
flutter test test/lint                # every lint and registry pin
flutter test test/<the folders your change touches>
dart run tool/preflight.dart --list   # names the generators your change implicates
```

Then run only the generators `--list` names and commit their output; every generated file has a drift gate in CI. The **full test suite runs in CI**, not locally; docs-only changes need only the lint and doc tests. Use the Flutter version the README pins, and format only files you created.

A claim about the database (RLS, a definer function, a trigger) is proved in the database with a pgTAP file under `supabase/tests/database/`.

## Testing

TDD pyramid: about 70% unit, 20% widget, 10% integration. That is the intended shape, not a measured one; `dart run tool/test_inventory.dart` prints what the suite actually is. Bug fixes start with a failing test that fails for the same reason the app fails. Fakes are preferred over mocks. Interactive screens carry accessibility assertions (tap-target guideline). Widget structure is tested, not platform-baselined golden images.

## Translations

DesKilo speaks five languages: **English (canonical), French, German, Spanish and Italian**. A new or changed string needs all five translations in the same PR.

- Strings live in `lib/l10n/` (ARB files and per-feature fragments under `lib/l10n/_fragments/`); never write a literal in a widget.
- The key-parity test fails CI if any locale lacks a key that `app_en.arb` has.
- The setup questionnaire has its own five files under `web/setup_l10n/`; regenerate `web/setup_l10n.js` with `dart run tool/build_setup_l10n.dart`.
- The user guides exist in all five languages; a native proofreader is as welcome as a developer.

## Documentation

Guides and help are part of the change, not a follow-up: a user-facing behaviour change updates the guide chapters (five languages under `docs/guide/user/`, anchored per object) and the generated `assets/help` text in the same PR. Do not state counts of migrations, feature flags, tests or routes in prose; name the command that prints them (`dart run tool/project_scale.dart`). Decisions worth keeping become an ADR in [`docs/decisions/`](docs/decisions/). Product intent is in [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md).

## Architecture in one paragraph

Feature-first: `lib/features/<name>/{data,domain,presentation,providers}` with a strict `core/`. `domain/` is pure Dart; `presentation/` never imports `data/` directly. The backend is Supabase (Postgres with row-level security, Edge Functions). More on the [Implementation page](https://github.com/fdittgen-png/deskilo/wiki/Implementation) and the [Architecture page](https://github.com/fdittgen-png/deskilo/wiki/Architecture).

## Security and privacy

The repository has no `SECURITY.md` yet. Do not publish exploit details in a public issue; ask the maintainer for a private channel through the GitHub profile of the repository owner. The threat model is in [`docs/security/THREAT_MODEL.md`](docs/security/THREAT_MODEL.md) and the data handling in [`PRIVACY.md`](PRIVACY.md).

## Conduct

There is no separate code of conduct file. Be courteous, assume good faith, and keep discussion on the issue or PR it concerns.

## License

By contributing you agree your contributions are licensed under the [GNU AGPL-3.0-or-later](LICENSE), and you sign off each commit with a [Developer Certificate of Origin](https://developercertificate.org/) line, `Signed-off-by: Your Name <you@example.com>`, which `git commit -s` adds. Add the SPDX header `// SPDX-License-Identifier: AGPL-3.0-or-later` to new source files.

The sign-off matters because of the dual licence: a commercial exception can only be sold by the holder of the copyright, so a contribution whose provenance is unrecorded cannot be included in one. See [ADR 0031](docs/decisions/0031-agpl-with-a-commercial-exception.md).
