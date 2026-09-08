# Technical reference

Everything the app is made of, why, and where to look. Facts here are
taken from the repository, not from memory: versions from `pubspec.yaml`
and the workflows, gates from `test/lint/`, decisions from
`docs/decisions/`. Companion pages: [Architecture](Architecture) (how the
pieces fit) and [Implementation](Implementation) (how to build and
contribute).

## Versions and floors

| | |
|---|---|
| Flutter | **3.44.9**, pinned in every workflow (`FLUTTER_VERSION`) and enforced by `flutter_pin_test` |
| Dart SDK | `^3.11.5` |
| Android | `minSdk`/`targetSdk`/`compileSdk` follow the Flutter defaults of that pin |
| iOS / iPadOS | **15.0** floor (`ios/Podfile`) |
| Desktop | macOS (DMG) and Windows (MSI) |
| Web | Flutter web, published to GitHub Pages on demand |
| Licence | **0BSD** — the app, its assets and its migrations; the embedded Roboto faces are Apache-2.0 |
| Size of the thing | 190 migrations · 98 feature flags · 59 routes · 369 test files |

## The stack, and why each piece is there

**State and structure**

| Package | Why |
|---|---|
| `flutter_riverpod` 3 · `riverpod_annotation` · `riverpod_generator` | every provider is generated from an annotated function; no global singletons, and a widget test overrides any seam |
| `freezed` · `json_serializable` | immutable domain models with value equality; a model is never mutated, only copied |
| `go_router` 17 | one route registry, pinned by `route_registry_test`; every gated route redirects on its feature flag |
| `flex_color_scheme` | the theme, light and dark, from one seed |

**Backend and transport**

| Package | Why |
|---|---|
| `supabase_flutter` | Postgres, auth, realtime and storage; **every write goes through an RPC**, never a table |
| `dio` | the HTTP client for what is not Supabase (payment providers, e-invoice platforms) |
| `hive` · `shared_preferences` | per-device state: the active workspace, dismissed hints, the demo switch |

**Documents and money**

| Package | Why |
|---|---|
| `pdf` | every printed document — invoices, letters, reports, badges, QR sheets |
| `liquify` | the Liquid dialect the report designer's bands and layouts are written in |
| `xml` | e-invoices (CII, UBL), the space file, VAT declarations, SAF-T |
| `intl` | dates, numbers and currencies in the reader's locale and the workspace's format |

**Devices**

| Package | Why |
|---|---|
| `qr_flutter` · `flutter_zxing` | space QR codes and the scanner |
| `nfc_manager` | RFID/NFC badges and seat tags |
| `flutter_local_notifications` · `deskilo_push` · `app_badge_plus` · `windows_taskbar` | reminders and pings, with a transport-free push twin for the libre build |
| `file_selector` · `path_provider` · `share_plus` · `url_launcher` | import, export, share |

**Help and tooling**

`markdown_widget` renders the bundled guide; `image` (dev) is the
screenshot pipeline; `visibility_detector` (dev) keeps the guide's
table of contents honest in tests.

## Architecture in one page

- **Feature-first**: `lib/features/<feature>/{domain,data,presentation,providers}`.
  Cross-feature reuse lives in `lib/core/`.
- **Domain purity**: nothing in `domain/` imports Flutter or the
  localizations — that is what lets `tool/report.dart` render an invoice
  from a command line, and `layering_test` is what keeps it true.
- **Presentation never imports data**: a screen talks to a repository
  interface through a provider (`layering_test` again).
- **One repository interface per feature**, with a Supabase implementation
  and an in-memory fake the whole test suite runs on.
- **Feature flags**: every functionality is behind a `WorkspaceFeature`,
  for its whole life, with a `requires` graph; the registry is pinned.
- **Five languages**, always: `lib/l10n/_fragments/<topic>_<lang>.arb`
  merged by `tool/build_arb.dart`; English is canonical; a bare string
  literal in a widget fails `no_hardcoded_strings_test`.

## The server

- **Postgres with row-level security on every table.** A client reads
  through policies and writes through `security definer` RPCs — the
  matrix of policies lives in `docs/security/SUPABASE_RLS_MATRIX.md`.
- **Migrations are numbered, immutable and harnessed.** Before any
  migration is applied, its DDL runs inside a transaction that ends with
  `raise exception 'HARNESS …'` — everything rolls back, the message
  carries the assertions, and impersonation (`set_config('request.jwt.claims', …)`)
  proves what each role may do. An applied file is never rewritten; a
  correction is a new migration.
- **System columns on every table**: `created_datetime`,
  `modified_datetime`, `company_id`, `site_id`, `created_by_user`,
  `modified_by_user`, stamped by a trigger the client cannot forge
  (ADR 0018).
- **Edge functions** for what must not touch a device: `send-e-invoice`,
  `send-push`, `send-whatsapp`, `badge-signin`, `create-payment-order`
  and the Stripe, Mollie and PayPal webhooks.
- **The instance bundle** (`assets/instance/bundle.json`) carries every
  migration and edge function, so the in-app wizard can build a new
  instance from scratch.

## Patterns, and where to read one

| Pattern | Where |
|---|---|
| Value object | `SystemColumns`, `VatRate`, `Money` — immutable, equal by value |
| Null object | `SystemColumns.none` for a row the server never stamped |
| Registry + lint | features, routes, permissions, report kinds, placeholders, help anchors |
| Snapshot | an invoice freezes its lines, parties and VAT breakdown at issue |
| Anchored patch | a migration rewrites a long function by asserted anchor, never by retyping it |
| Capability token | `set_config('deskilo.deploying', …)` lets one RPC pass another's guard for one transaction |
| Copy job | the database returns `{from, to}` pairs and the client copies the storage objects |
| Observer | `TraceProviderObserver` traces every provider failure; `SystemColumns.onBreach` reports an inconsistent row |
| Guarded action | `runGuarded` — one wrapper that traces the start, the end and the failure of every mutation |

## Quality gates

31 lint suites in `test/lint/`, each protecting one promise:

| Gate | Promise |
|---|---|
| `feature_registry` · `route_registry` · `report_kind_registry` · `help_anchor` · `system_columns` | a registry and the code that reads it cannot drift |
| `l10n_completeness` · `no_hardcoded_strings` | five languages, no bare literal |
| `layering` · `file_length` · `no_inline_border_radius` | the shape of the code |
| `no_silent_catch` · `no_wall_clock` | an exception is always traced; time is always injected |
| `spdx_headers` · `adr_format` | provenance and decisions |
| `setup_html` · `config_reachable` | every parameter is reachable in the app *and* in the questionnaire |
| `fdroid_frozen` · `fdroid_reproducible` · `foss_flavour` · `manifest_permissions` · `android_reach` · `platform_checks` | the libre build and the platform contracts |
| `play_listing` · `play_availability` · `privacy_policy_version` · `contrast` | the store and accessibility |
| `instance_bundle` · `workflow_pins` · `flutter_pin` | the bundle and the toolchain match the repository |

CI runs analyze with `--fatal-infos`, the l10n drift gate, the full suite
with coverage (**a floor that may only go up**), and a build.

## Release

`release-train.yml -f track=beta` fans out to every platform at once:
Play closed track, TestFlight external, the web build, the macOS DMG and
the Windows MSI, plus a report job. The web publish is opt-in
(`web.yml -f deploy=true`). F-Droid builds from a frozen recipe with a
transport-free push package.

## Standards the app implements

| Domain | Standard |
|---|---|
| E-invoicing | **EN 16931** semantic model; **CII** (Factur-X) and **UBL** syntaxes; VATEX exemption codes; business rules BR-S, BR-E, BR-O, BR-AE, BR-G enforced at export |
| VAT | **Directive 2006/112/EC** — categories, exemptions, reverse charge (art. 196), place of supply for immovable property (art. 47), tax point and prepayments (art. 63–66) |
| Accounting exports | **FEC** (France), **SAF-T**, **DATEV** |
| Post | **NF Z 10-011** address block and window-envelope geometry |
| Identifiers | ISO 3166-1 alpha-2, ISO 4217, IBAN/BIC, SIREN/SIRET, RNA, VIES VAT-id syntax |
| Accessibility | 48 dp touch targets, contrast pinned by test, no colour-only state |

## Decisions

The 18 ADRs in `docs/decisions/`, newest first: system columns (0018),
cash-basis exigibility (0017), reverse charge (0016), the VAT compliance
review (0015), identity on the profile (0014), positioned report layouts
(0013), F-Droid via a FOSS push package (0012), notifications first with
FCM (0011), e-invoice transmission (0010), the 0BSD relicence (0009),
percentage bands for billing v2 (0008), five locales (0007),
quota-and-overage billing (0006), the grid floor-plan model (0005), the
first licence (0004), no Firebase or GMS (0003), Supabase as the backend
(0002), and the Flutter + Riverpod stack (0001).

## Where to look

| | |
|---|---|
| What the product must do | `docs/SPECIFICATION.md` |
| The rules an agent must obey | `docs/AGENT_RULES.md` |
| The schema, policies and RPCs | `supabase/migrations/` |
| The guides | `docs/wiki/`, compiled into the app by `tool/build_help.dart` |
| The screenshots | `docs/media/source/` (originals) and `docs/wiki/images/` (what the guides link) |
