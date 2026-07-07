# Contributing to DesKilo

Thanks for helping! The project follows the same working methodology as its sibling [tankstellen/Sparkilo](https://github.com/fdittgen-png/tankstellen).

## Workflow

- **Issue first.** No code without a GitHub issue. Work larger than one PR becomes an **Epic** with a validated breakdown.
- Branch off `master`: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/`, `ci/`, `perf/`, `style/`.
- **Conventional commits**: `type(scope): imperative subject under 72 chars, no trailing period`.
- One concern per branch, short-lived (1–3 days). **PRs under 400 lines** (excluding generated files) — split if larger.
- Every change is a PR; squash-merge only; link the issue (`Closes #NN`).
- Forbidden: direct commits to `master`, force-push to `master`, `--no-verify`, amending pushed commits.

## Hard rules

1. **No hard-coded user-facing strings** — everything through ARB / `AppLocalizations`, English (`en`) is canonical; FR, DE, ES, IT are maintained launch locales.
2. **Issue-first development** (see above).
3. **Clean codegen before push** — regenerate freezed/riverpod artifacts from clean and commit them.
4. **Locale key parity** — every locale must carry every key; CI gates on it.

Full rules for humans and AI agents: [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## Testing

TDD pyramid: ~70% unit / 20% widget / 10% integration. Bug fixes start with a failing test that fails for the same reason the app fails. Fakes preferred over mocks. Accessibility assertions (tap-target guideline) on interactive screens.

## Architecture

Feature-first: `lib/features/<name>/{data,domain,presentation,providers}` with a strict `core/`. `domain/` is pure Dart. `presentation/` never imports `data/` directly. Decisions are recorded as ADRs in [`docs/decisions/`](docs/decisions/).

## License

By contributing you agree your contributions are licensed under the [MIT License](LICENSE). Add the SPDX header `// SPDX-License-Identifier: MIT` to new source files.
