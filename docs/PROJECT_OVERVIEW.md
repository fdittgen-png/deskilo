<!-- SPDX-License-Identifier: 0BSD -->

# DesKilo — complete project reference

**Generated 2026-07-31, revised 2026-08-01** from the state of `master`, the live reference Supabase project, and the GitHub repository configuration.

This is a *derived* document: it consolidates what is spread across `README.md`, `docs/SPECIFICATION.md`, `docs/AGENT_RULES.md`, `docs/wiki/`, `docs/decisions/`, `docs/guides/RELEASING.md`, the ten CI workflows, the platform runners and the Supabase schema. Where those sources disagree with the code or the live systems, the discrepancy is recorded in **[§17 Known gaps and stale documentation](#17-known-gaps-and-stale-documentation)** rather than silently reconciled — the originals remain the sources of truth for their own areas.

---

## Table of contents

1. [What DesKilo is](#1-what-deskilo-is)
2. [Repository at a glance](#2-repository-at-a-glance)
3. [Domain model](#3-domain-model)
4. [Feature inventory](#4-feature-inventory)
5. [Client architecture](#5-client-architecture)
6. [Backend architecture (Supabase)](#6-backend-architecture-supabase)
7. [Online payments](#7-online-payments)
8. [Invoicing and e-invoicing](#8-invoicing-and-e-invoicing)
9. [Internationalization](#9-internationalization)
10. [Design system](#10-design-system)
11. [Development best practices](#11-development-best-practices)
12. [Testing](#12-testing)
13. [CI on GitHub](#13-ci-on-github)
14. [GitHub repository configuration](#14-github-repository-configuration)
15. [Distribution channels](#15-distribution-channels)
16. [Release process](#16-release-process)
17. [Known gaps and stale documentation](#17-known-gaps-and-stale-documentation)

---

## 1. What DesKilo is

A free, privacy-first coworking community app: **visual desk booking plus the community money layer**, mobile-first and libre. It is the sibling of [Sparkilo/tankstellen](https://github.com/fdittgen-png/tankstellen) and inherits that project's stack, conventions, and CI toolchain nearly 1:1.

**Repository:** `github.com/fdittgen-png/deskilo` (public, created 2026-07-07)
**Application ID / bundle ID:** `de.deskilo.app`
**License:** 0BSD (BSD Zero Clause) © 2026 Florian DITTGEN — ADR 0009, superseding MIT (ADR 0004)
**Version:** `0.1.0+1` in `pubspec.yaml` (CI overrides the build number at publish time)

### The leitmotiv

Every feature must serve at least one of three goals. A proposal serving none is pushed back on before any code is written — the feature-request issue template makes this a required checkbox.

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data, works on F-Droid.

### Market position

Seatsurfing (GPL, web) is the strongest open-source desk-booking tool but has no billing/membership model. Nadine covers coworking billing but is an aging Django web suite. On F-Droid the niche is empty. DesKilo's differentiator is the combination: visual booking **plus** the community money layer, mobile-first, libre.

### Founding constraints

- **No Google Play Services, no Firebase, no third-party tracking, no GPL dependencies** (ADR 0003, ADR 0009). Enforced in CI by `scripts/audit_no_gms.sh`, which greps `pubspec.yaml`, `pubspec.lock` and all three Gradle files for `firebase|google_mobile_ads|google_sign_in|com.google.gms|com.google.firebase|google_mlkit|play_core|in_app_review|com.google.android.play` and exits non-zero on any hit.
- **Self-hostable backend** — Supabase is open source; `BackendConfig` accepts `--dart-define=SUPABASE_URL=…` / `SUPABASE_KEY=…` at build time.
- **Every user-facing string translatable**, English canonical (ADR 0007).

---

## 2. Repository at a glance

```
android/                Android runner (Play + F-Droid — one flavor, GMS-free)
ios/                    iOS runner + fastlane (Fastfile, Appfile, Matchfile)
macos/                  macOS desktop runner (sandboxed, entitlements)
windows/                Windows runner + WiX v5 MSI authoring (installer/deskilo.wxs)
web/                    Flutter web target (GitHub Pages deploy, opt-in)
assets/
  fonts/                Roboto — embedded in PDF bills (base-14 fonts cannot encode €/−)
  help/                 in-app help, compiled from the wiki by tool/build_help.dart
  icon/                 launcher + splash artwork
  pdf/                  sRGB output intent (PDF/A-3 requirement for Factur-X)
distribution/whatsnew/  Play "what's new" text
docs/
  SPECIFICATION.md      the product spec (source of truth for behavior)
  AGENT_RULES.md        binding rules for humans and AI assistants
  PROJECT_OVERVIEW.md   this document
  decisions/            ADRs 0001–0010
  design/               DESIGN_SYSTEM.md, payments-integration.md
  guides/               RELEASING.md
  security/             SUPABASE_RLS_MATRIX.md
  wiki/                 source of the GitHub wiki (Architecture, Implementation,
                        Home, _Sidebar + user guides in EN/FR/DE/ES/IT + images)
fastlane/metadata/
  android/<locale>/     Play listing text + images (en-US, de-DE, fr-FR, es-ES, it-IT)
  ios/<locale>/         App Store listing text + review information
metadata/de.deskilo.app.yml   fdroiddata recipe DRAFT
lib/                    the app — 293 Dart files
supabase/
  migrations/           0001–0073 — schema, RLS, RPCs (numbered, immutable)
  functions/            5 Edge Functions (Deno)
test/                   unit + widget tests, fakes in test/helpers/
integration_test/       end-to-end flows (app_boot_test.dart etc.)
tool/                   build_arb.dart, build_help.dart, store_assets/
tools/                  upload_to_play.py, upload_listing.py
scripts/                audit_no_gms.sh, gen_app_icon.py, sign_and_notarize_macos.sh
.github/                10 workflows, 3 issue templates, PR template
```

### Current scale

| Metric | Value |
|---|---|
| Dart source files (`lib/`) | 293 |
| Test files (`test/` + `integration_test/`) | 161 |
| Test cases (`flutter test`) | 1 013 (1 011 green + [2 date-dependent failures](#c-two-date-dependent-tests-fail-from-2026-08-01--new)) |
| SQL migrations in the repo | 73 (`0001` … `0073`) |
| Supabase Edge Functions | 5 |
| ARB translation keys per locale | 944 × 5 locales |
| ARB fragment groups | 38 |
| Files carrying an SPDX 0BSD header | 470 |
| go_router routes | 34 |
| Toggleable per-workspace features | 21 |
| GitHub Actions workflows | 10 |

### Toolchain

| Tool | Pinned version |
|---|---|
| Flutter | **3.41.9** stable (`FLUTTER_VERSION` in every workflow; `srclibs: flutter@3.41.9` in the F-Droid recipe) |
| Dart SDK constraint | `^3.11.5` |
| Java / JDK | 17 (temurin on CI; `JavaVersion.VERSION_17` source/target) |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| Ruby (fastlane) | 3.3 |
| fastlane | `~> 2.227` |
| WiX toolset | 5.0.2 (v7+ requires accepting the Open Source Maintenance Fee EULA) |
| Xcode | `latest-stable` on `macos-15` runners |
| Python (Play tooling) | 3.12 |

---

## 3. Domain model

Conceptual model from `docs/SPECIFICATION.md §3`, as realized in migrations 0001–0073.

| Concept | Meaning |
|---|---|
| **Workspace** | One coworking community: name, address, **country** (drives default currency and formats), time zone, opening hours, closure days, booking rules, subscription levels, fee bands, feature flags. `invite_code` doubles as the human-readable workspace ID and the member invite. |
| **Level** | A floor of the workspace. May carry a background photo (0036) and resizable illustration images (0037). |
| **Office** | A room on a level; may be flagged *bookable as a whole* (0057). |
| **Desk** | A piece of furniture inside an office, drawn on the grid; has an opacity setting (0040). |
| **Seat** | **The bookable unit** — a fixed **6-squares-wide × 4-squares-deep** slot on a desk edge with an orientation (which side the person sits on). ADR 0005. |
| **Chair / accessories** | Attribute set of a seat (type + amenities: ergonomic chair, standing desk, monitor, dock, window seat). Filterable when searching. Priced accessories carry a per-half-day supplement (0022–0024). |
| **Member** | A user's participation in a workspace: `is_admin` / `is_owner` / co-owner booleans (roles are **additive**), `status` (`active`/`paused`/`exited`), `subscription_pct`, `is_kiosk`. |
| **Reservation** | Seat (or whole office, or whole level) + member + start + end. States: *reserved → checked-in → completed*, or *cancelled*, or *released* (no-show). May belong to a **series**. |
| **Series** | A recurrence rule (pattern + start + end). Max length configurable per workspace. |
| **Check-in / Check-out** | Timestamps on a reservation. A spontaneous walk-up check-in *atomically* creates a reservation starting now. |
| **Event** | The unifying auditable record: reservation, payment, expense, service-charge, adjustment and role-change events. Every event has an *actor* and a *subject*; actor ≠ subject triggers the confirmation protocol. |
| **Ledger** | Per member, per workspace: charges (subscription, overage, services, accessories, packages), credits (approved expenses, payments, adjustments), running balance, monthly statements. |
| **Invoice** | An immutable, signed document derived from the month's tracked data (0060–0073). Not the ledger — a snapshot of it. |

### Roles

| Role | Rights |
|---|---|
| **Worker** (member) | Belongs to the community, has a subscription percentage, checks in/out, reserves, submits expenses, sees and manages **their own** events and ledger. |
| **Administrator** | A worker with extra rights: manages events (reservations, payments, expenses) **for anybody**, configures booking rules, approves expenses. Cannot alter the physical workspace. |
| **Owner** | Everything an admin can do, plus: create/edit the workspace, define subscription levels and fee bands, manage roles, workspace-level settings. A workspace has ≥ 1 owner; the last owner cannot be removed, only transferred. A **co-owner** role exists since 0058. |
| **Kiosk** | A wall-tablet pseudo-member (`members.is_kiosk`, 0043) that acts *as* a badge's member without any session on the device. |

One user account can belong to several workspaces; the app scopes everything to the **active workspace** and re-derives all state when you switch (see §5).

---

## 4. Feature inventory

### Booking and presence

- **Visual floor plan** — the active level rendered as a grid map (offices → desks → seats), color-coded by state, pinch-zoom and pan, level switcher, amenity filter. State is **never conveyed by color alone** (icons/patterns too).
- **Time scroller** — a horizontal timeline attached to the plan; dragging it re-renders seat occupancy at the selected moment. "Now" returns to live view. A seat × day **week view** complements it.
- **Walk-up check-in** — tap a free seat; start = now, end = workspace default; reservation + check-in created atomically. Capped at a later reservation's start if one exists.
- **Reservation check-in** — presence-enforced (#408, migration 0077): allowed only inside `[start − 15 min, end)` — never ahead of the window, never after the reservation ended — checked server-side and mirrored in the UI. Admins/owners can check in a member who is physically present (gated by the bookForOthers feature). Reminder notification and **no-show auto-release** (default 30 min after start) remain on the roadmap.
- **Check-out** — manual, or automatic at reservation end / closing time. Check-out truncates `ends_at` to `now()` so the seat frees immediately.
- **Reservations** — punctual and series (daily, weekdays, weekly-on-selected, every N weeks, monthly), half-day / full-day / minute-granularity slots per workspace rule, open-weekday and closure-day aware, from the Reserve hub, the plan, or the calendar. Series conflicts are surfaced as **exceptions** to resolve, never silently partial.
- **Whole-office booking** (0057) and **level reservations** (0050) for meeting-room-style booking.
- **QR check-in** — printable per-seat QR codes; scanning opens that seat's check-in sheet.
- **Booking rules engine** — advance-booking horizon, max series duration, min/max duration, max concurrent future reservations, per-member reservation cap (0044), cancellation deadline, check-in window / no-show release, opening hours, closure days, approval-required resources.

### Community and roles

- **Members directory** — who's in, custom status text, reservation chips (checked-in / reserved now / next upcoming), one-tap WhatsApp, workspace group link, presence dots, avatars (0038).
- **Roles and invites** — owner / co-owner / admin / member. Invitations are **role-bound QR codes** encoding `deskilo://join?role=<user|admin>&code=<CODE>`; the server derives the granted role **from which secret code matched**, never from the client parameter, and no owner-granting code path exists at all. Personal, single-use invitations (0051) and member-join validation (0052) layer on top.
- **Events space and confirmation protocol** — a filterable, time-sorted, auditable feed. Anything an admin does *for somebody else* stays **pending** until that person confirms. Pending reservations tentatively block the seat; pending *deletions* do not free it. 48 h reminder; 7-day auto-confirm — except deletions of another person's reservation and ledger debits, which **auto-expire** instead.
- **Quorum validation** (0017) — per-workspace, per-event-type policies: `required_count`, `admins_may_validate`, `eligible_admin_ids`, `owner_required`. `event_decisions` is the per-validator audit trail; auto-confirm fills only the *remaining* quorum and is recorded as a `system` decision so the trail never has gaps.

### Money

- **Percentage subscriptions** (ADR 0008) — a member's membership is an integer **percentage 1–100**. The owner curates the offered levels (presets 25/50/75/100, plus owner-defined levels, plus an optional free-value option).
- **Fee bands** — `(from_pct, to_pct]` inclusive-upper, contiguous and non-overlapping covering 1–100 (enforced by a DB constraint trigger). The band gives the monthly `fee_cents` and the `overage_fee_cents` per half-day.
- **Entitlement** — 100 % = every half-day the workspace offers that month. Included half-days = `ceil(open_days × 2 × pct / 100)`, where `open_days` = days matching `booking_rules.open_weekdays` minus that month's `closure_days`. Usage beyond that bills at the band's overage rate.
- **Ledger** — charges (subscription, overage, services, accessory supplements, packages) and credits (approved expenses, payments, adjustments), with a running balance.
- **Statements** — computed, not stored; sectioned as subscription · services · open positions · payments/credits · balance. **Open positions** = still-pending events for the period, listed separately from posted lines.
- **Priced services** (0014/0016) — owner-curated catalog; consumption self-reported by the member or recorded by an admin, landing as a pending event that posts on confirmation.
- **Day packages** (0042) with self-serve buy.
- **Community expenses** (0009) — a member buys something for the space, an admin approves (self-approval disallowed), the amount is credited against their next statement.
- **Live online payments** — PayPal, Stripe, Mollie, Wero (see §7).
- **Immutable signed invoices** with PDF export, void/replacement chain, invoicing hub with payment-linked matching, EN 16931 / Factur-X e-invoicing, VAT management (see §8).

### Operations

- **Kiosk mode** (0043) — a wall tablet in locked plan view; badge-driven actions via the stateless `kiosk_act` RPC, with a confirm step. Badges are **QR or NFC/RFID** (0046); the card UID is stored **only as a SHA-256 hash**, never raw. Self-service badge enrollment (0053), kiosk identify (0054), badge revocation with hash deletion (0055), badge scope + kiosk revert (0056).
- **Workspace portability** — the whole floor-plan configuration exports/imports as **XML** (0023/0027/0034).
- **Owner-guarded workspace reset** (0039).
- **Feature flags** — 21 per-workspace toggleable modules (see §5).
- **Notifications** — local check-in reminders plus **UnifiedPush** (Google-services-free) for pending confirmations; Android-only, degrading to local notifications elsewhere.
- **In-app help** — compiled from the wiki user guides by `dart run tool/build_help.dart` into `assets/help/`, offline on every platform.
- **Developer screen** — traced failures per domain (`runGuarded` wraps every mutating call site), payment-config probe, local-only trace log.
- **Social sign-in** — Google, Microsoft, Apple, Facebook via Supabase Auth, with `deskilo://auth-callback` deep-link return on every platform.

---

## 5. Client architecture

### Stack

| Layer | Choice | Rationale (ADR) |
|---|---|---|
| UI framework | Flutter 3.41.9 stable, Material 3 via `flex_color_scheme` ^8.1.0 | One codebase for Android, iOS, macOS, Windows, web (0001) |
| State | **Riverpod 3 with codegen** — `flutter_riverpod` ^3.0.3, `riverpod_annotation` ^4.0.2 | Compile-safe providers, no manual wiring (0001) |
| Models | `freezed` ^3.0.0 + `json_serializable` ^6.9.0 | Value semantics, exhaustive `sealed` matching |
| Routing | `go_router` ^17.3.0 with a `StatefulShellRoute` bottom-nav shell | Declarative redirects encode role/feature gating |
| Backend client | `supabase_flutter` ^2.15.4 (PostgREST + GoTrue); `dio` ^5.10.0 for raw HTTP | Multi-user source of truth (0002) |
| Local storage | `hive` ^2.2.3 (encrypted) + `shared_preferences` ^2.5.5 | Offline read cache, active-workspace choice |
| i18n | ARB via `intl` ^0.20.2, EN canonical + FR/DE/ES/IT | Lint- and CI-enforced (0007) |
| QR | `qr_flutter` ^4.1.0 (render) + `flutter_zxing` ^2.3.0 (scan) | Libre, GMS-free (0003) |
| NFC | `nfc_manager` ^4.2.1 behind an injectable `NfcUidReader` seam | Android-only, degrades gracefully |
| Push | `unifiedpush` ^6.2.0 + `flutter_local_notifications` ^22.0.1 | No Firebase/GMS (0003) |
| PDF | `pdf` ^3.12.0 (pure Dart) + `path_provider` | Deliberately **not** the `printing` package — it pulls platform channels not needed here |
| XML | `xml` ^6.6.1 | Floor-plan export/import + UBL/CII e-invoices |
| Files | `file_selector` ^1.1.0 (rides the Storage Access Framework on Android), `share_plus` ^13.2.0, `web` ^1.1.1 for browser downloads |
| Links | `url_launcher` ^6.3.1 behind the test-capturable `linkLauncherProvider` seam |
| Help rendering | `markdown_widget` ^2.3.2+8 |
| Time | `timezone` ^0.11.1 |

**Dev dependencies:** `flutter_lints` ^6.0.0, `build_runner` ^2.4.15, `freezed`, `json_serializable`, `riverpod_generator` ^4.0.2, `riverpod_lint` ^3.1.3, `mocktail` ^1.0.4, `integration_test`, `flutter_launcher_icons` ^0.14.4, `visibility_detector` ^0.4.0+2.

### Layout — feature-first with a strict `core/`

```
lib/
  main.dart
  app/            DeskiloApp, router (+ router.g.dart), boot, boot_splash,
                  app_initializer, theme, shell/ (bottom bar, app bar)
  core/           backend/ cache/ country/ files/ format/ links/ locale/
                  nfc/ notifications/ presence/ push/ scan/ share/ storage/
                  theme/ time/ trace/ ui/
  l10n/           app_en.arb (canonical) + fr/de/es/it, _fragments/, generated
  features/
    auth/         email+password and social sign-in (Supabase Auth)
    workspace/    workspace CRUD, onboarding, invites, members admin,
                  availability rules, feature flags, XML import/export
    plan/         the live floor plan + time scroller, accessories
    editor/       owner grid editor (levels → offices → desks → seats)
    reservations/ Reserve hub, series, week view
    calendar/     month/week/day views of own reservations
    events/       event feed + confirmation protocol, validation settings
    members/      member directory
    money/        ledger, statements, billing, packages, services, invoices,
                  VAT, e-invoicing, PDF export
    kiosk/        wall-tablet mode
    help/         in-app help compiled from the wiki
    profile/      settings, profiles (multi-workspace), developer screen
```

Each feature keeps the same internal shape:

- `domain/` — freezed models + a **pure-Dart** repository interface. No Flutter, no Supabase.
- `data/` — the Supabase implementation of that interface.
- `providers/` — Riverpod codegen.
- `presentation/` — screens + widgets.

**`presentation/` never imports `data/`** — it goes through `providers/`. Enforced as a hard rule.

### State management pattern

- Repositories are exposed as `keepAlive` providers (`workspaceRepositoryProvider`, …).
- Derived state is expressed as async providers that `watch` upstream ones. `currentWorkspace` recomputes from `myWorkspaces` + the persisted `ActiveWorkspaceId`; everything workspace-scoped (`workspaceMembers`, `enabledFeatures`, `adminInviteCode`, …) watches `currentWorkspace`. **Switching profiles re-derives the whole app state with no extra plumbing.**
- Role gating in the UI reads `myMember` — but **the UI is never the enforcement layer; RLS is.** Client role checks are cosmetic.

### Feature flags — the gating rule

`WorkspaceFeature` (21 values) + `featureManifest` in `features/workspace/domain/workspace_feature.dart` form a declarative registry. Each enum name is the jsonb key in `workspaces.feature_flags`; `resolveEnabledFeatures` starts from the registry defaults and applies boolean overrides, **ignoring unknown keys so old and new clients coexist**.

`FeatureManifestEntry.requires` expresses a **hierarchy**: a feature is only effective while its whole prerequisite chain is enabled. The Features screen renders children indented under their parent, and `effectiveFeatures` drops orphans — so switching a parent off removes its whole subtree without erasing the owner's stored child choices.

| Feature | Default | Requires |
|---|---|---|
| `calendarTab`, `eventsTab`, `moneyTab` | on | — |
| `services` | on | `moneyTab` |
| `accessorySupplements` | **off** | `moneyTab` |
| `onlinePayments` | **off** | `moneyTab` |
| `invoicing` | on | `moneyTab` |
| `adminInvoicing` | **off** | `invoicing` |
| `pdfExport`, `seriesBooking`, `bookForOthers`, `pushNotifications` | on | — |
| `adminSeatBlocking` | **off** | — |
| `levelBooking` | **off** | — |
| `adminLevelAssign` | **off** | `levelBooking` |
| `kioskMode`, `nfcBadges`, `membersDirectory`, `whatsappIntegration`, `spaceQrCodes`, `coOwner` | see manifest | see manifest |

**The gating rule: enable a feature and *all* of its surfaces appear; disable it and *none* remain.** Every feature-linked surface is gated at **two layers**:

1. The entry point (settings tile, tab, button) checks `enabledFeaturesSync.contains(feature)`.
2. The route guards with a `featureEnabled(...)` redirect in `app/router.dart` — so deep links and bookmarks bounce too.

The router's `refreshListenable` watches `enabledFeaturesProvider`, so toggling a feature (or switching workspaces) re-evaluates every redirect immediately. **The master Features screen is deliberately *not* feature-gated** — it must always be reachable to switch a module back on.

`/services`, `/payment-config`, `/nfc-config` and `/accessories` are the reference implementations. Every new gated surface needs a widget test for **both** the hidden entry point and the bounced deep link.

### Routes

34 routes: `/auth` `/onboarding` `/plan` (+ `level/:levelId`) `/reserve` `/calendar` `/events` `/pending` `/money` `/billing` `/invoices` `/invoice-register` `/services` `/members` `/directory` `/editor` `/settings` `/workspace-settings` `/workspace-code` `/features` `/availability` `/validation` `/accessories` `/payment-config` `/einvoice-config` `/legal-identity` `/vat` `/nfc-config` `/kiosk` `/kiosk-gate` `/scan-join` `/profiles` `/linked-accounts` `/help` `/developer`.

### Shared building blocks

Cross-surface concepts have **exactly one** implementation:

| Building block | Role |
|---|---|
| `PlanCanvas` + `PlanCanvasMetrics` | the floor-plan host for the Plan tab, the Reserve hub, and the kiosk |
| `seat_occupancy.dart` | derives occupant labels, seat states, presence dots |
| `LevelChipRow` | the level selector |
| `runGuarded` | the traced-failure wrapper every mutating call site uses |
| `linkLauncherProvider` | the one (test-capturable) external-link seam |
| `SheetShell` | the modal-form scaffold |
| `centsToMajor` / `parseCentsInput` | the money-input helpers |

### Platform degradation

Single codebase for all targets; platform-specific behavior degrades gracefully.

| Target | Notes |
|---|---|
| **Android** | Full app. `minSdk`/`targetSdk`/`compileSdk` from the Flutter toolchain. Core library desugaring on (needed by `flutter_local_notifications` scheduled notifications). R8 with keep rules for that plugin's Gson usage — without them release builds crash before the first frame (issue #86). Permissions: `INTERNET`, `CAMERA`, `NFC` (`uses-feature` `required="false"` so non-NFC phones still install). Deep-link intent filter for `deskilo://`. |
| **iOS** | Full app minus UnifiedPush. `NSCameraUsageDescription` set; `ITSAppUsesNonExemptEncryption=false`; `CFBundleURLSchemes` = `deskilo`. Portrait + both landscapes (iPad adds upside-down). |
| **macOS** | Full booking/ledger app, **sandboxed**. Release entitlements: `app-sandbox`, `network.client` (Supabase), `device.camera` (QR), `files.user-selected.read-write` and `files.downloads.read-write` (XML import/export, PDF save). Debug adds `allow-jit` and `network.server`. |
| **Windows** | Full app, shipped as a WiX-built **MSI** with a per-machine install into `Program Files\DesKilo`, a Start-menu shortcut, and an HKLM registration of the `deskilo://` protocol handler (the OAuth callback needs it — Windows learns it from the installer the way Android learns it from the manifest). |
| **Web** | Booking/ledger works. **NFC badges and camera QR scanning are guarded off** (`kIsWeb`); an export downloads through the browser instead of landing in a Downloads folder (`file_saver_web.dart`). |
| **Push** | UnifiedPush is Android-only — `PushConnector` returns `false` elsewhere and the app stays on local notifications. |

---

## 6. Backend architecture (Supabase)

The server is an **RLS-protected Postgres where every multi-user write goes through a `SECURITY DEFINER` RPC**, so business invariants live next to the data.

**Reference deployment:** hosted Supabase, EU `eu-central-1`, project ref `zwzbynivewivvjmripeb`. The URL and publishable key are committed in `lib/core/backend/backend_config.dart` **by design** — both are publishable, RLS is the security boundary (ADR 0002). Self-hosters override with `--dart-define`.

### The three security ideas

1. **Default-deny RLS.** Every table has row level security enabled. There are deliberately **no insert policies on core tables** — writes happen through `SECURITY DEFINER` RPCs (`create_workspace`, `join_workspace`, the reservation RPCs, …) that validate invariants transactionally.
2. **Role helpers as SQL functions.** `is_member_of(ws)`, `is_admin_of(ws)`, `is_owner_of(ws)` are `SECURITY DEFINER` with a pinned `search_path`, so policies can consult `members` without recursion and clients cannot spoof them.
3. **Invariants live in triggers.** `protect_last_owner()` makes it impossible to demote or remove the last active owner, no matter which write path is taken.

Role-scoped invites (0030) follow the same philosophy: the granted role is derived from **which secret code matched** (`workspaces.invite_code` → member, `workspace_admin_invites.code` → admin), never from a client parameter.

### Secrets tables get *zero* policies

`payment_credentials` (0047) and `einvoice_credentials` (0071) enable RLS and add **no policies at all**. Only service-role Edge Functions and owner `SECURITY DEFINER` RPCs reach them, and the status RPCs return key *names*, never values. This is the shape to follow for anything secret.

### Concurrency

Walk-up check-in and reservation creation are **atomic RPCs** with conflict checks at confirmation time. Availability is never decided against a possibly-stale client view — the category's #1 failure mode. Hard invariants:

- **No double-booking**: `btree_gist` exclusion constraints on `(seat_id, tstzrange)` and `(office_id, tstzrange)` for active statuses. The walk-up race cannot commit twice.
- **Guarded deletion**: `on delete restrict` from reservations to seats/offices/members — the editor must resolve reservations first.
- `assert_seat_not_blocked` is an internal helper with EXECUTE revoked from all API roles, called from `create_reservation`, `admin_create_reservation_for` and per-instance in `create_series` (blocked instances land in the skipped report).

### Migration map

Migrations are numbered SQL files applied in order. They are **immutable once applied** — fixes are new migrations.

| Range | Content |
|---|---|
| 0001–0004 | Core `profiles` / `workspaces` / `members`, RLS on core tables, floor plan (`levels` → `offices` → `desks` → `seats`), function-grant hardening |
| 0005–0007 | Reservations + conflict-checked RPCs, booking rules & series, events + confirmation protocol |
| 0008–0012 | Plans/ledger/payments, expenses, owner-defined workspace code, solo-admin auto-respond, push endpoints |
| 0013–0020 | Availability (open weekdays, closures), service catalog + consumption, **percentage subscriptions + fee bands**, quorum validation, feature flags, payment method & instructions |
| 0021–0029 | Seat blocking, accessories + supplements billing, XML floor-plan import (v1/v2), booking granularity, half-day walk-up, profile WhatsApp/presence, status text |
| 0030–0035 | Role-scoped invites, quota enforcement + extra-half-day requests, slot granularities, reservation updates/moves, series patterns, role-change validation |
| 0036–0040 | Level background photos, resizable plan images, member avatars, owner-guarded workspace reset, desk opacity |
| 0041–0048 | Overage policy, day packages, **kiosk badges**, reservation limit, **payment intents**, **NFC badges**, **payment credentials** (deny-all), Wero provider |
| 0049–0059 | Invitation template, level reservations, personal invitations, member-join validation, self-service badges, kiosk identify, badge deletion/scope, whole-office booking, co-owner, desk reservations + space validation |
| 0060–0068 | **Invoices**: immutable archive, replacement chain, derived lines, balance, details, space series, reminders, matching, payment-linked matching |
| 0069–0073 | **E-invoicing**: invoice legal identity (EN 16931), payment date + settled month, e-invoice platform credentials, VAT rates, VAT grants hardening |

### Edge Functions (Deno)

| Function | JWT | Purpose |
|---|---|---|
| `create-payment-order` | verified (member's Supabase JWT) | Starts a provider order; `{action:'config'}` probes which providers are ready |
| `paypal-webhook` | **off** | PayPal verify-webhook-signature → `settle_online_payment` |
| `stripe-webhook` | **off** | HMAC signing-secret verification + replay window → `settle_online_payment` |
| `mollie-webhook` | **off** | Re-fetch verification (matches intents of provider `mollie` *or* `wero`) → `settle_online_payment` |
| `send-e-invoice` | verified | Posts an e-invoice document to a provider and records the outcome on `invoice_transmissions` |

Webhooks run with `verify_jwt` off because a payment provider has no Supabase JWT — **authenticity comes from the provider's own signature verification**, not from Supabase auth.

Provider credentials resolve **table-first, env-fallback**, so a single-workspace self-host can configure everything with function env vars alone.

### RLS permission matrix (excerpt)

Full matrix in `docs/security/SUPABASE_RLS_MATRIX.md`. Default-deny: anything not listed is blocked.

| Table | Operation | anon | user | worker | admin | owner |
|---|---|---|---|---|---|---|
| `profiles` | select own / co-member | — | ✅ / — | ✅ / ✅ | ✅ / ✅ | ✅ / ✅ |
| `profiles` | insert | trigger only (`handle_new_user`) ||||
| `workspaces` | select / update / delete | — | — | ✅ / — / — | ✅ / — / — | ✅ / ✅ / ✅ |
| `workspaces` | insert | RPC `create_workspace()` (creator becomes owner) ||||
| `members` | select | — | — | ✅ | ✅ | ✅ |
| `members` | insert (join) | RPC `join_workspace(invite_code)` ||||
| `members` | update roles / delete | — | — | — | — | ✅ |
| Floor plan (levels/offices/desks/seats) | select | — | — | ✅ | ✅ | ✅ |
| Floor plan | insert/update/delete | — | — | — | — | ✅ |
| Seat block/unblock | — | — | — | RPC¹ | RPC |
| Accessories | select / write | — | — | ✅ / — | ✅ / ✅ | ✅ / ✅ |
| Reservations | select | — | — | ✅ | ✅ | ✅ |
| Reservations | create / check-in / cancel | — | — | RPC | RPC | RPC |

¹ Admins only when `feature_flags.adminSeatBlocking = true`; the RPC raises otherwise.

**The auditing rule:** every migration touching a table, policy, or `SECURITY DEFINER` function **must** update this matrix in the same PR and re-run the Supabase security advisors — the advisor result belongs in the PR description.

**Accepted advisor warnings** (do not "fix" these): the linter notes that `authenticated` can execute the `SECURITY DEFINER` RPCs and helper predicates. That *is* the API surface — the RPCs check `auth.uid()`, and the predicates only answer questions about the caller's own memberships.

---

## 7. Online payments

Four providers behind one architecture: **PayPal** (Orders v2), **Stripe** (Checkout — cards/SEPA), **Mollie** (iDEAL, Bancontact, cards…), and **Wero** (offered *through* Mollie with `method=wero`).

### Design principles

1. **The client never holds PSP secrets.** All provider calls happen in Edge Functions. The app only *starts* a payment and *opens a URL*. This keeps the F-Droid build clean — no proprietary payment SDK is linked in; the app opens the provider's hosted approval page in a browser.
2. **The capture is the proof.** A provider-confirmed capture posts a **confirmed** ledger credit directly. It does not go through the two-person confirmation flow — that exists to vouch for *manual* claims; a PSP capture needs no human witness.
3. **Idempotent by capture id.** Webhooks retry; `settle_online_payment` is keyed on `(provider, order_id)` so a credit is posted at most once and replays are harmless.
4. **Opt-in per workspace.** The `onlinePayments` feature flag is **off by default**, and the Edge Function stays inert until its secrets exist. Both must be true for a charge to be possible.

### Flow

```
tap "Pay online"
  → create-payment-order        reads payment_credentials (table-first, env-fallback)
                                creates the provider order
                                inserts a payment_intents row
                                returns the approval URL
  → member pays on the provider's hosted page
  → <provider>-webhook          verifies the provider's own signature
                                resolves the workspace from the intent
                                → settle_online_payment()  → confirmed ledger credit
```

### Credential handling

The owner writes credentials through `set_payment_credentials` (blank field = keep existing) and reads back only key *names* plus non-secret fields (`return_url`, `env`) via `payment_credentials_status`. `clear_payment_provider` removes them. **Secret values are never returned to any client.**

Webhook endpoints to register in the provider dashboards (PayPal and Stripe only — Mollie's is passed per payment):

```
https://<project-ref>.supabase.co/functions/v1/paypal-webhook
https://<project-ref>.supabase.co/functions/v1/stripe-webhook
```

### Operator setup

```bash
supabase secrets set \
  PAYPAL_CLIENT_ID=... PAYPAL_SECRET=... PAYPAL_ENV=sandbox PAYPAL_WEBHOOK_ID=... \
  PAYMENT_RETURN_URL=...
supabase functions deploy create-payment-order
supabase functions deploy paypal-webhook --no-verify-jwt
```

Then flip **Online payments** on for the workspace (owner → Settings → Features). Until the secrets exist, `create-payment-order` returns `not_configured` and the app shows a diagnostics dialog naming the exact missing env vars — no error, no charge.

### Outstanding

- Operator must create the provider account(s) and set the secrets.
- End-to-end sandbox test (sandbox buyer, test capture, webhook replay → exactly one credit).
- Switch to live keys; enable for a pilot workspace.
- Refunds/disputes handling is out of scope for v1.

---

## 8. Invoicing and e-invoicing

### Immutable derived invoices (0060–0068)

An invoice is **derived from the month's tracked data**, then frozen and signed. It is not the ledger — it is a snapshot of it. The chain supports **void/replacement** (an issued document keeps saying what it said; a correction is a new document that points at the old one), PDF download and share, reminders, and an **invoicing hub with payment-linked matching** where *paid = definitive*.

### EN 16931 (ADR 0010)

**The decision: DesKilo produces the document; it does not become a network node.** Becoming a Peppol access point or a French *plateforme agréée* means certificate management, SMP/SML registration, uptime commitments, interoperability testing and per-country legal obligations — a compliance company, not a feature of a coworking app. It would also contradict the "tracking, not processing" line that governs payments (ADR 0006).

The unit of work DesKilo owns is the **semantically correct EN 16931 document**. Every access point and platform accepts EN 16931 UBL or CII and maps it to the national CIUS itself (FatturaPA, FA(3), CIUS-RO, XRechnung, Peppol BIS).

**Three delivery paths, in order of cost to the user:**

1. **Export** — download or share the UBL 2.1 XML from the invoice detail sheet. A routing sheet (`e_invoice_routing.dart`) states, for the workspace's own country, which channel business customers expect, whether a platform sits in the path, and which channel public buyers use. Where the domestic mandate runs on a national syntax (IT, PL, RO) it says plainly that this file is not the one that platform accepts. **Transmission timelines are deliberately absent from the code** — mandate calendars slip every year, and a wrong date shipped in an app is worse than no date.
2. **Provider integration** (built 2026-07-27) — an optional per-workspace connection to one aggregator, shipped as a **generic adapter**: an upload URL, a credential, the header that carries it, the multipart field name. That covers most *plateformes agréées*, Peppol access points and clearance-platform upload APIs, and — unlike a vendor list — it cannot go stale. Credentials live in the deny-all `einvoice_credentials` table (0071); the edge function `send-e-invoice` posts the document and records the outcome on `invoice_transmissions`. The **client** builds the bytes with the same builder the download uses and posts them to the function: the token never reaches a phone, and the document is never rebuilt by a second, divergent code path. Every attempt is logged (accepted / rejected / failed) with a SHA-256 of what left. **Still blocked on a real provider account for an end-to-end test.**
3. **Factur-X hybrid PDF** (built 2026-07-27) — `invoice_cii.dart` (CII D16B, profile `urn:cen.eu:en16931:2017`) plus PDF/A-3 output: `PdfaRdf` metadata with the Factur-X XMP extension, the sRGB output intent as an app asset, and `factur-x.xml` attached with `/AFRelationship /Alternative`. A human sees a PDF, a machine finds the XML; no network at all. **Full PDF/A-3 conformance still needs an external validator** (veraPDF, Mustang, FNFE) — that is the remaining gate before calling it certified.

### Legal identity (0069)

- `workspaces` gains `vat_regime` (`not_subject` | `exempt` | `vat_registered`), `vat_id`, `legal_id`, `tax_exemption_reason`, and structured `street` / `city` / `postal_code`.
- **The regime drives the mapping**: `not_subject` → category `O` with `VATEX-EU-O`, identified by BT-30, no tax scheme. `exempt` → category `E`, rate 0, BT-31 plus a reason (`VATEX-FR-FRANCHISE` in France, free text elsewhere). `vat_registered` → **the export refuses**, because the app does not price VAT per position and a zero-VAT declaration from a VAT-charging seller is a false statement, not a rounding error.
- `profiles` gains `country_code` (BT-55 is mandatory; defaulting it to the workspace's country would silently mis-declare a foreign customer) and `vat_id` (BT-48).
- `invoices` gains a `parties` jsonb **snapshot**, part of the signed content.

### Refuse before exporting

`checkEInvoiceReadiness` runs the fatal rules the app can decide locally and reports them **in the owner's words** — "the company registration number is missing", not "BR-CO-26" — with a direct route to the screen that fixes them. Non-fatal profile gaps (city, post code) warn without blocking. *A file that a receiving platform will silently reject is worse than no file.*

### Accounting export

SAF-T / FEC accounting export and VAT management (0072/0073) round out the money layer.

---

## 9. Internationalization

**English (`en`) is the canonical locale.** French, German, Spanish and Italian ship as maintained launch locales. **944 keys × 5 locales**, full parity.

### The fragment pipeline

Strings live in **38 per-feature fragments** under `lib/l10n/_fragments/<feature>_<locale>.arb`:

`accessories · auth · availability · badges · bill · bill_pdf · billing · calendar · common · consumption · coowner · developer · directory · editor · events · features · help · invite · invoice · joinflow · kiosk · language · level · members · money · plan · profile · profiles · quota · reserve · services · social · space · theme · validation · validation_settings · vat · workspace · workspace_xml`

`dart run tool/build_arb.dart` merges them into the aggregated `lib/l10n/app_<locale>.arb` that `flutter gen-l10n` consumes. **The merge fails on duplicate keys across fragments of the same locale**, so two features can never silently shadow each other's strings.

```bash
dart run tool/build_arb.dart   # merge fragments → app_<locale>.arb
flutter gen-l10n               # always run afterwards
```

### The rules

- **No hard-coded user-facing strings.** Everything goes through `AppLocalizations` with a defensive English fallback literal. Lint-enforced with a ratchet-to-zero baseline.
- **Every new key lands in all five locales in the same PR.**
- **Key parity is a CI gate** — the workflow regenerates the ARB pipeline and fails on any `git diff` in `lib/l10n`.
- Dates, numbers and currency always render through locale-aware `intl` formatting, never raw string formatting. The workspace **country** drives the default currency.
- All timestamps stored UTC; recurring series recur in **workspace-local** time (a 09:00 series stays 09:00 across DST).
- User-generated content (workspace names, expense notes) is not translated.

Store metadata is localized in the same five locales under `fastlane/metadata/android/<locale>/` and `fastlane/metadata/ios/<locale>/` (iOS uses `en-GB` rather than `en-US`).

---

## 10. Design system

Defined once in `lib/app/theme.dart`; tokens in `lib/core/theme/`.

### Brand palette — burnt orange

| Token | Value | Note |
|---|---|---|
| primary | `#C2410C` | muted burnt orange — the brand color |
| primaryContainer | `#F4D8C4` | |
| secondary | `#8A5A33` | warm brown |
| secondaryContainer | `#EBDCC9` | also the app-bar tint |
| tertiary | `#3C6E63` | muted teal — deliberately quotes Sparkilo's tertiary |
| tertiaryContainer | `#CFE3DC` | |
| error | `#B3261E` | |

**Three themes** (`DeskiloTheme`): `light()` (blend 8), `dark()` (`toDark(28)`, blend 22), and the signature orange-forward `warm()` (blend 20, primaryContainer app bar) — the analog of Sparkilo's `eco()`.

### Radius tokens (`AppRadius`)

sm 4 · md 8 · **lg 12 (canonical card/input/button)** · xl 16 (dialogs, sheets, chips) · xxl 24 (hero). **Inline `BorderRadius.circular(n)` is banned** and guarded by a lint test.

### Seat-state palette (`SeatStateColors`)

| State | Light | Dark |
|---|---|---|
| free | `#4F7C44` | `#8BC34A` |
| reserved | `#3B6FA0` | `#7FB2E5` |
| occupied | `#BE7C1E` | `#E8B04E` |
| mine | `#C2410C` | `#FF8A50` |
| blocked | `#6B7280` | `#9CA3AF` |

Hues sit on the blue↔orange axis plus lightness contrast (deuteranopia/protanopia-aware). **State is never conveyed by color alone** — the floor plan pairs every state with an icon or pattern.

### Rules

- All colors come from `Theme.of(context).colorScheme` or the token classes — **no inline `Color(0x…)` in feature code**.
- Typography: Material 3 defaults (`useMaterial3Typography`), no custom fonts.
- SnackBars float; inputs use outline borders.
- **Accessibility**: WCAG-conscious color coding, minimum tap targets (`meetsGuideline(androidTapTargetGuideline)` asserted in tests), screen-reader labels on all floor-plan elements.

### App icon

`flutter_launcher_icons` from `assets/icon/icon_full.png`, with an adaptive Android icon (background `#D32F2F`, foreground + monochrome from `icon_foreground.png`) and `remove_alpha_ios: true`.

---

## 11. Development best practices

The methodology is inherited 1:1 from tankstellen/Sparkilo. `docs/AGENT_RULES.md` is binding for **humans and AI assistants alike**.

### HARD RULES (four, non-negotiable)

1. **No hard-coded user-facing text.** Every string goes through ARB / `AppLocalizations` with a defensive English fallback. English is canonical; FR/DE/ES/IT are maintained — every new key needs all five translations in the same PR. Lint-enforced with a ratchet-to-zero baseline.
2. **Never develop without a GitHub issue.** Work larger than one PR or touching multiple subsystems becomes an **Epic** with a maintainer-validated breakdown *before* implementation starts.
3. **Clean codegen before push.** After touching any freezed class or `@riverpod` annotation: `dart run build_runner build --delete-conflicting-outputs` from clean; commit the generated files; **zero drift on push**.
4. **Locale key parity.** The key-parity gate fails CI if any locale is missing keys vs. `app_en.arb`.

### Coding rules

- No `print` — use `debugPrint`.
- No `catch (_) {}`. Every `catch (e)` is `catch (e, st)` with the stack trace logged.
- No inline `BorderRadius.circular(n)` — use `AppRadius` tokens.
- No `setState` for shared state — Riverpod providers only; `@riverpod` codegen, no manual `Provider`/`StateProvider`.
- `presentation/` never imports `data/` — go through `providers/`. `domain/` is pure Dart.
- After `await` in widget code: `if (!context.mounted) return;`.
- No magic strings/numbers in business logic — constants class + a pinning test.
- Dates, numbers, currency: locale-aware formatting only (`intl`).
- All timestamps stored UTC; recurring series recur in workspace-local time.
- No GMS, no Firebase, no third-party tracking, no GPL dependencies.
- **SPDX header** `// SPDX-License-Identifier: 0BSD` in every new source file.

**Lint configuration** (`analysis_options.yaml`): `package:flutter_lints/flutter.yaml` + the `riverpod_lint` analyzer plugin, plus `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`, `require_trailing_commas`. `flutter analyze` runs over `lib` **and** `test` with **zero tolerance**.

### Git rules

- Branch off `master`. Prefixes: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/`, `ci/`, `perf/`, `style/`.
- **Conventional commits**: `type(scope): imperative subject under 72 chars, no trailing period`.
- One concern per branch, short-lived (1–3 days).
- **Every change is a PR under 400 lines** (excluding generated files) — split if larger.
- Squash-merge only; link the issue (`Closes #NN`); head branches auto-delete.
- **Forbidden**: direct commits to `master`, force-push to `master`, `--no-verify`, amending pushed commits.

### Backend rules

- Migrations are numbered SQL files, **immutable once applied** — fixes are new migrations.
- Pattern for a new table: enable RLS immediately, add select policies using the role-helper functions, keep writes behind `SECURITY DEFINER` RPCs, and `revoke execute … from public, anon` on every new function.
- **Secrets tables get zero policies.**
- Every migration touching a table, policy or `SECURITY DEFINER` function updates `SUPABASE_RLS_MATRIX.md` in the same PR and re-runs the security advisors; the advisor result goes in the PR description.
- Update the **fake repository** to mirror the new server contract in the same PR.

### Adding a feature — the checklist

1. File the issue (or Epic + children if > 1 PR).
2. Branch `feat/<slug>` off `master`.
3. **Write the failing test first.**
4. Model in `domain/` (freezed) → seam in the repository interface → Supabase impl in `data/` → provider → screen.
5. New strings → all five ARB fragments → `dart run tool/build_arb.dart && flutter gen-l10n`.
6. New tables/RPCs → numbered migration with RLS + revokes; update the fake repository.
7. If the surface belongs to a `WorkspaceFeature`: gate it at **both** layers and add a widget test for the hidden entry **and** the bounced deep link.
8. `flutter analyze && flutter test` green locally, then PR with the template.

### Building and running

```bash
flutter pub get
dart run tool/build_arb.dart && flutter gen-l10n      # localizations
dart run build_runner build --delete-conflicting-outputs   # riverpod/freezed/json
```

| Target | Command |
|---|---|
| Android (debug) | `flutter run -d <device>` |
| Android APK | `flutter build apk` |
| Android AAB | `flutter build appbundle --release --build-number=<n>` |
| iOS | `flutter run -d <iphone>` / TestFlight via fastlane |
| macOS | `flutter run -d macos` · release: `flutter build macos` → `build/macos/Build/Products/Release/DesKilo.app` |
| Windows | `flutter build windows` · MSI: `gh workflow run windows-msi.yml -f ref=master` |
| Web | `flutter build web --release --base-href /deskilo/` |

---

## 12. Testing

### The pyramid

**70 % unit / 20 % widget / 10 % integration.** 1 013 test cases across 161 files.

Run `flutter test` **bare**. Piping it (`| tail`, `| grep`) yields the pipe's exit code, not the suite's, so a red run reads as green.

```bash
flutter analyze                        # zero tolerance, lib + test
flutter test                           # full suite
flutter test test/features/<feature>/  # one feature
flutter test --coverage                # + coverage/lcov.info
flutter test integration_test -d <device>   # on-device e2e
```

### Rules

- **Bug fixes start with a failing test** that fails for the *same reason the app fails* — calling the exact method the failing UI calls.
- **Twin-bug audit before closing**: grep for the same anti-pattern elsewhere; fix all occurrences in one PR.
- **Producer + consumer ship together** — never merge the reader half of a feature without the writer.
- If a fix adds an affordance (button, banner), **a test must tap it**.
- **Structural widget tests only** — no platform-baselined golden PNGs.
- **Fakes over mocks** for the service layer; `mocktail` only for widget-level callbacks.
- Accessibility assertions (`meetsGuideline(androidTapTargetGuideline)`) on interactive screens — every new tappable affordance needs a big-enough target *and its own test that taps it*.

### The fake seam

Widget tests pump the whole `DeskiloApp` with `ProviderScope(overrides: standardTestOverrides(...))`. Fakes for auth, workspace, reservations, money and notifications live in `test/helpers/mock_providers.dart` and **mirror server behavior including RLS visibility** — e.g. `FakeWorkspaceRepository.adminInviteCode` only answers for owners. Server SQL semantics are documented in the migration files; client tests assert against the fake.

### Coverage gate

CI enforces **≥ 45 % line coverage**, computed from `coverage/lcov.info` by summing `LF:`/`LH:` records.

---

## 13. CI on GitHub

Ten workflows in `.github/workflows/`. All pin `FLUTTER_VERSION: "3.41.9"`.

### `ci.yml` — the gate on every push and PR

Runs on push to `master` and on every pull request. Concurrency group `ci-${{ github.ref }}`, cancel-in-progress on PRs only. `ubuntu-latest`, 20-minute timeout.

1. `flutter pub get`
2. **No-GMS audit** — `bash scripts/audit_no_gms.sh` (ADR 0003)
3. **l10n gate** — `dart run tool/build_arb.dart && flutter gen-l10n`, then `git diff --exit-code -- lib/l10n`. Any drift fails with an actionable error naming HARD RULE #4.
4. **Analyze** — `flutter analyze` (lib + test)
5. **Tests with coverage** — `flutter test --coverage`
6. **Coverage gate** — fails below 45 %

### `android-boot.yml` — release-launch aliveness on a real emulator

Triggered by pushes to `master` touching `lib/main.dart`, `lib/app/**`, `lib/core/**`, `android/**`, `pubspec.*`, `integration_test/**`, or the workflow itself; also dispatchable.

Builds the **R8-shrunk release APK**, installs it on an API-34 `pixel_6` `x86_64` emulator, clears logcat, launches with a deterministic `adb shell am start -W -n de.deskilo.app/.MainActivity`, sleeps 15 s, and asserts `adb shell pidof de.deskilo.app` — the exact issue-#86 failure mode (release builds crashing before the first frame because R8 stripped `flutter_local_notifications`' Gson usage), proven to catch it. KVM is enabled for hardware acceleration; the **AVD snapshot is cached** (`avd-34-pixel6`), cutting later runs from ~8–10 min to ~2 min. The full logcat is uploaded as an artifact on any outcome.

> The debug integration test was deliberately dropped from CI — a second Gradle build plus a JIT app on a software-rendered emulator blew two job timeouts. `integration_test/app_boot_test.dart` remains for on-device runs.

### `dev-apk.yml` — sideload build

Dispatch-only, takes a `ref`. Runs the No-GMS audit, builds a **debug-signed** `arm64` APK, uploads it as an artifact (14-day retention). Debug-signed on purpose: fine for sideloading, blocked from store upload by design.

### `play-internal.yml` — Google Play publishing

**Scheduled daily at 16:00 UTC** and dispatchable with a `track` choice (`internal` / `alpha` / `beta` / `production`) and optional `release_notes`. Concurrency group `play-internal`, never cancelled.

- **Wall-clock monotonic build number**: `1000000 + (now_epoch - 1751760000) / 60` — minutes since 2025-07-06 UTC on a 1 M base. Strictly monotonic across runs *and workflows* (iOS uses the identical scheme), unique per minute, ~4 000 years of headroom under Android's `2147483647` cap. This is what stops parallel workflows leapfrogging and tripping Play's no-downgrade rule.
- Restores the upload keystore from `ANDROID_KEYSTORE_BASE64` into `android/app/upload-keystore.p12` and writes `android/key.properties`; **deletes both in an `if: always()` step**.
- Builds a signed AAB, uploads it as an artifact (30-day retention).
- Uploads to Play via `tools/upload_to_play.py` (resumable upload with retries, per-locale changelogs from `fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt` with fallback notes).
- Pushes an annotated tag `vX.Y.Z+<versionCode>` so every shipped build maps back to a commit (`contents: write`).
- **Degrades honestly**: without `PLAY_STORE_SERVICE_ACCOUNT_JSON` the upload is skipped with a loud warning and the AAB is still attached.

### `play-listing.yml` — store listing sync

Dispatch-only with a `dry_run` boolean. **Fails loudly** if `PLAY_STORE_SERVICE_ACCOUNT_JSON` is missing. Runs `tools/upload_listing.py`, which updates title / short / full description for every locale and re-uploads the icon, feature graphic and any `images/phoneScreenshots/*.png`. The service-account key is cleaned up in an `if: always()` step.

### `ios-testflight.yml` — signed IPA → TestFlight

Dispatch-only (macOS minutes bill at 10× Linux), `macos-15`, 45-minute timeout. Four modes via boolean inputs:

| Input | What it runs |
|---|---|
| `create_app: true` | `fastlane create_app_record` — registers the bundle id and reports what App Store Connect holds |
| `sync_certs: true` | `fastlane match_sync_appstore` — write-mode match, `force: true` so entitlement changes are picked up |
| `upload_metadata: true` | `fastlane upload_metadata` — listing text only, five locales, never submits for review |
| *(default)* | `fastlane release_testflight` — match → build → pilot |

Key mechanics, each earned from a real failure:

- **Newest stable Xcode** (`maxim-lobanov/setup-xcode@v1`, `latest-stable`) — Apple rejects TestFlight uploads built with SDKs older than the current major.
- **CocoaPods reinstalled under the active Ruby** — `ruby/setup-ruby` switches Ruby and the system pod's `GEM_HOME` no longer matches, producing "CocoaPods is installed but broken".
- **A dedicated unlocked keychain** via `setup_ci` in fastlane's `before_all`. Without it match imports into `login.keychain`, whose password no headless runner knows, and `codesign` puts up a prompt nobody can answer — the job then sits in silence until the timeout. That is exactly how the first TestFlight build died.
- **SSH agent + deploy key** for the certs repo (`webfactory/ssh-agent`); PAT-based clones kept 403ing.
- The same monotonic build number scheme as Play, passed through **Flutter's `--build-number`** flag (the project's `CURRENT_PROJECT_VERSION` is `$(FLUTTER_BUILD_NUMBER)`; `agvtool` does not work here).
- Tags `vX.Y.Z+<build>-ios`; uploads obfuscation symbols as a 90-day artifact.
- CocoaPods cache keyed on `ios/Podfile.lock`.

### `ios-testers.yml` — TestFlight tester management

Dispatch-**only** — this is an outward-facing live App Store Connect mutation that sends a real invitation email. Runs on `ubuntu-latest` (API-only; no build, no match, no Xcode). Inputs: `create_external_group`, `email` (single or comma-separated), `groups`, `role`, `resend`, `first_name`, `last_name`.

Handles **both** tester paths:
- **External groups** — a plain email assignment; the tester needs no Apple account.
- **Internal groups** — internal testers must be App Store Connect *users* first, so the lane invites them via `UserInvitation` scoped to this app only (`all_apps_visible: false`, `provisioning_allowed: false`), then assigns them once they accept.

The lane is defensive in ways that reflect specific production failures: an **account-scoped** tester lookup (the app-scoped one returns nil for a tester who exists on the account but is not yet indexed against this app), separate create-new vs add-existing paths (the bulk endpoint returns 200 with a *per-tester* error rather than raising), a **post-assignment verification re-fetch** before claiming success, a `resend` mode that removes+re-adds (external) or deletes+recreates the pending invitation (internal) because a current member's invite cannot otherwise be re-sent, and a graceful **warn-and-continue** when the API key lacks Users-and-Access permission (an App-Manager-scoped key cannot manage users by design — that is a config limitation, not a transient failure).

The `create_external_group` lane creates a non-internal beta group with `has_access_to_all_builds: true` and optionally a **public link** with a tester cap (default 100) — the TestFlight equivalent of the Play internal-test URL.

### `macos-app.yml` — signed, notarised DMG

Dispatch (`ref`, `sync_certs`), PRs touching `macos/**` / the workflow / the signing script, and `v*` tags. `macos-15`, 60-minute timeout.

**Why notarisation is not optional:** since macOS 15 a downloaded app Apple has not notarised is refused outright, and the old right-click → Open bypass is gone. Without it the DMG is a file people cannot open.

- Fetches the Developer ID certificate via `fastlane match_developer_id` (`platform: "macos"`), `continue-on-error: true`.
- `scripts/sign_and_notarize_macos.sh` signs nested frameworks first and the bundle last, hardened runtime on, submits the DMG to `notarytool`, staples the ticket and asserts `spctl` accepts it — **so a build that would be refused on someone's Mac fails in CI instead**.
- **Degrades honestly**: a PR build (no access to signing secrets from a fork) or a run with no Developer ID certificate still produces a DMG, named `-unsigned.dmg`, with a `::warning::` explaining what the user has to do. *A file called `DesKilo.dmg` that macOS refuses is worse than one that admits what it is.*

> **The Developer ID certificate must be created by the ACCOUNT HOLDER.** An App Store Connect API key cannot mint one — Apple answers *"This operation can only be performed by the Account Holder"*. Create it once in Xcode (Settings → Accounts → Manage Certificates → ＋ → Developer ID Application), then `fastlane match import --type developer_id`.

### `windows-msi.yml` — WiX v5 MSI

Dispatch (`ref`), PRs touching `windows/**` or the workflow, and `v*` tags. `windows-latest`, 45-minute timeout.

- `flutter build windows --release`, then `wix build windows/installer/deskilo.wxs -arch x64 -d ProductVersion=<x.y.z> -d PublishDir=<abs path> -o <msi>`.
- **WiX pinned to 5.0.2** — v7+ requires accepting the Open Source Maintenance Fee EULA (WIX7015), and v5 uses the same v4/v5 authoring schema as `deskilo.wxs`.
- **`PublishDir` must be an ABSOLUTE path.** WiX resolves a `<Files Include>` wildcard relative to the `.wxs`, not the working directory — a repo-relative path silently harvested *nothing*, and every MSI built before that fix was 6 KB of shortcut with no application in it.
- Two guards, because an empty harvest is not an error to WiX: it throws if `deskilo.exe` is missing from the publish dir, and throws if the resulting MSI is under 10 MB.
- Attaches the MSI to the GitHub release on `v*` tags.

### `web.yml` — browser build

Dispatch (`ref`, `deploy`) and PRs touching `.github/workflows/web.yml`, `web/**`, `lib/**` or `pubspec.yaml`. Permissions `contents: read`, `pages: write`, `id-token: write`.

- Runs on PRs so a change that only breaks the browser (a `dart:io` import reaching web code, a plugin with no web implementation) fails there instead of in front of a user.
- **Publishing is opt-in.** `deploy=true` puts the app on the public Pages URL with the committed Supabase URL + publishable key baked in — the same pair every store binary ships (RLS is the boundary). Pages must be enabled once in repo Settings → Pages → Source: GitHub Actions.
- `--base-href` is set to `/<repo>/` for a Pages deploy (assets 404 without it), and `index.html` is copied to `404.html` so reloading a go_router deep link works on a static host.
- The `deploy` job is guarded so it can *never* run on a PR.

---

## 14. GitHub repository configuration

| Setting | Value |
|---|---|
| Repository | `fdittgen-png/deskilo` |
| Visibility | **Public** |
| Created | 2026-07-07 |
| Default branch | `master` |
| License (detected) | BSD Zero Clause License (`0bsd`) |
| Issues | enabled |
| Wiki | enabled (sourced from `docs/wiki/`) |
| Homepage URL | *(not set)* |
| Stars | 1 |
| Branch protection on `master` | **NONE** — see §17 |
| Rulesets | **none** (`[]`) |

### Issue templates

| Template | Labels | Required fields |
|---|---|---|
| **Bug report** (`bug_report.yml`) | `bug` | What happened, steps to reproduce, app version & platform. Optional context prompts for screenshots, workspace setup, role, locale. |
| **Feature request** (`feature_request.yml`) | `enhancement` | Problem, proposal, plus a **leitmotiv checkbox group** — "a feature serving none of these will be pushed back on". |
| **Epic** (`epic.yml`) | `epic`, title prefixed `Epic: ` | Goal (in user-visible terms, linking the spec section), dependency-ordered child-task breakdown, risks/open questions, and a **validation gate checkbox** — children may only be filed after maintainer validation. |

`config.yml` keeps blank issues enabled and links the product specification with "Read the full spec before filing feature requests."

### PR template

A `## What` paragraph, `Closes #`, and a seven-item checklist: linked issue · under 400 lines excluding generated · no hard-coded strings (EN+FR+DE+ES+IT) · clean codegen with zero drift · tests added/updated and bug fixes started from a failing test · `flutter analyze` clean including `test/` · no GMS/Firebase/tracking introduced.

### Labels

Nine GitHub defaults plus three project-specific ones:

| Label | Color | Meaning |
|---|---|---|
| `epic` | `#6F42C1` | Work larger than one PR, with validated breakdown |
| `backend` | `#1D76DB` | Supabase schema, RLS, edge functions |
| `l10n` | `#0E8A16` | Localization / ARB |

### Repository secrets (10 configured)

| Secret | Used by | Purpose |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | `play-internal` | PKCS12 upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | `play-internal` | |
| `ANDROID_KEY_ALIAS` | `play-internal` | alias `upload` |
| `ANDROID_KEY_PASSWORD` | `play-internal` | |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | `play-internal`, `play-listing` | Play Developer API service account |
| `APP_STORE_CONNECT_API_KEY_ID` | iOS/macOS | key `CG5N5AKMH9` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | iOS/macOS | the `.p8`, base64 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | iOS/macOS | team-wide issuer UUID |
| `MATCH_PASSWORD` | iOS/macOS | certs-repo passphrase — **only the owner has this** |
| `MATCH_DEPLOY_KEY` | iOS/macOS | write deploy key `deskilo-ci` on `deskilo-ios-certs` |

**Irreplaceable material** (back it up off-machine):
- `MATCH_PASSWORD` — without it match cannot decrypt `deskilo-ios-certs` and the repo's contents are useless. This is exactly how the 2026-07-09 run failed ("Invalid password passed via 'MATCH_PASSWORD'").
- The App Store Connect `.p8` private key — **Apple will not re-issue it**.
- `~/keystores/deskilo-upload-keystore.*` on the dev Mac — the master copy of the Android upload keystore and its password.

---

## 15. Distribution channels

### 15.1 Google Play

| Item | Value |
|---|---|
| Package | `de.deskilo.app` (bound on first AAB upload) |
| Signing | PKCS12 upload keystore, alias `upload`, 30-year validity, generated with OpenSSL 2026-07-07 |
| Local fallback | builds without `android/key.properties` fall back to debug signing, so `flutter run --release` keeps working |
| Automation | `play-internal.yml` — daily 16:00 UTC + on demand, tracks internal/alpha/beta/production |
| Listing sync | `play-listing.yml` — texts + icon + feature graphic + screenshots |
| Locales | en-US, de-DE, fr-FR, es-ES, it-IT |

**Assets:** `fastlane/metadata/android/en-US/images/icon.png` (512×512, derived from `assets/icon/icon_full.png`) and `featureGraphic.png` (1024×500) live once under `en-US`; F-Droid reads the same paths, and other Play locales fall back to en-US at upload time. Six phone screenshots are present (`phoneScreenshots/01.png`–`06.png`). Regenerate the feature graphic after a brand change with `flutter test tool/store_assets/feature_graphic_test.dart` (it draws the graphic with the canvas API and is not part of the CI test run).

**Owner-only steps Google offers no API for:**
1. Play Console → Create app: name *DesKilo*, App, Free.
2. Grant the publisher service account permission to manage releases for the app (Users & permissions).
3. Internal testing → Testers: create/attach an email list, share the opt-in link.
4. Console-only forms for a production listing: content rating, data safety, contact details.

**Current state:** an alpha draft release has been uploaded; a Play Console 11-task answer sheet is drafted. Play listing review is owner-blocked.

### 15.2 Apple — App Store, TestFlight, macOS

| Item | Value |
|---|---|
| Bundle ID | `de.deskilo.app` |
| Team ID | `C4Y5RDF8P9` |
| Signing | **fastlane match** against DesKilo's own private repo `fdittgen-png/deskilo-ios-certs`, with its own `MATCH_PASSWORD` |
| Certificates | Apple Distribution (App Store) + Developer ID Application (macOS notarisation) — both in the same certs repo |
| Locales | en-GB, de-DE, fr-FR, es-ES, it-IT |
| Categories | `fastlane/metadata/ios/primary_category.txt` / `secondary_category.txt` |
| Review contact | `fastlane/metadata/ios/review_information/` |

**Why a separate certs repo:** sharing tankstellen's was the original plan and is the tidier one, but its passphrase proved unrecoverable, and re-encrypting a repo Sparkilo depends on to fix a DesKilo problem is not a trade worth making. Apple allows three distribution certificates per team, and minting one leaves the existing one alone.

**Bootstrap order (one time):**

```bash
gh secret set MATCH_PASSWORD -R fdittgen-png/deskilo                  # from 1Password
gh secret set APP_STORE_CONNECT_API_ISSUER_ID -R fdittgen-png/deskilo # team-wide UUID
gh workflow run ios-testflight.yml -f create_app=true                 # ASC app record
gh workflow run ios-testflight.yml -f sync_certs=true                 # mint the profile
```

**Per build:**

```bash
gh workflow run ios-testflight.yml
gh workflow run ios-testers.yml -f email=someone@example.com
```

**App record:** `fastlane produce` (lane `create_app_record`) registers the bundle id — but **an App Store Connect API key may NOT create an app record**, whatever its role ("The resource 'apps' does not allow 'CREATE'"). The record is made in the web UI; the lane's job is to tell you whether the one you made points at the right bundle id, listing every app the key can see if it does not. Apple has no equivalent of Play binding a package on first upload, so this must happen before the first `pilot` upload.

**Testers:** internal uploads are instant and reviewless (≤ 100 testers). The current branch (`feat/testflight-external-group`, commit `46a717e`) adds the **external group with a public link** path — external testers need no Apple account at all, at the price of Beta App Review on the first build; every build after that reaches the group directly.

**macOS:** `gh workflow run macos-app.yml -f ref=master` → a signed, notarised, stapled DMG (drag-into-Applications window built with `hdiutil`). See §13 for the honest-degradation behavior and the account-holder certificate constraint.

### 15.3 F-Droid

| Item | Value |
|---|---|
| Recipe | `metadata/de.deskilo.app.yml` — **a DRAFT** |
| License | 0BSD (on F-Droid's allowed-licenses list) |
| Categories | Time, Money |
| Summary | "Coworking community app — desk booking and shared money, libre" |
| Build | `srclibs: flutter@3.41.9`, JDK 17 headless, `flutter build apk --release` |
| Prebuild | `bash scripts/audit_no_gms.sh` — the GMS-free guarantee is asserted inside F-Droid's own buildserver, not just in our CI |
| Auto-update | `AutoUpdateMode: Version`, `UpdateCheckMode: Tags ^v[0-9.]+$` |

**No flavor split is needed** until a Play-only feature appears — the single Android build is already 100 % Google-services-free.

**To submit:** after the first tagged release (`vX.Y.Z`), fill in the four `TODO-first-release` fields (`versionName`, `commit`, `CurrentVersion`, `CurrentVersionCode`) and open a merge request against `gitlab.com/fdroid/fdroiddata`. F-Droid builds from source on their buildserver.

**Caveat carried over from Sparkilo:** sideloaded/F-Droid APKs and Play APKs are signed differently — a device must uninstall one to install the other.

### 15.4 Windows

MSI from `windows-msi.yml`, attached to the GitHub release on `v*` tags. Per-machine install into `Program Files\DesKilo`, Start-menu shortcut, and an HKLM registration of the `deskilo://` protocol handler. `UpgradeCode` `CB5062A7-BF77-4543-B7F1-E88F3FF613F8` is the product's **permanent identity** — never change it, or upgrades stop replacing older installs.

### 15.5 Web

`gh workflow run web.yml -f deploy=true` publishes to GitHub Pages. Opt-in only; Pages must be enabled once in repo settings.

---

## 16. Release process

1. **Bump `version:`** in `pubspec.yaml` (name + code) in the release PR.
2. **Changelog entry** under `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
3. **Tag** `git tag vX.Y.Z` on `master` with a green CI run (semver + annotated tag; release notes generated from PR titles).
4. **Smoke-test**: `gh workflow run dev-apk.yml -f ref=vX.Y.Z`, download the artifact, install on a device.

A `v*` tag automatically triggers `windows-msi.yml` and `macos-app.yml`, attaching the MSI and the DMG to the GitHub release.

Android publishing is separate and continuous: `play-internal.yml` runs daily and tags each shipped build `vX.Y.Z+<versionCode>`. iOS tags `vX.Y.Z+<build>-ios`.

### Current status

Feature-complete for the v1 scope and in dogfooding. Owner-blocked items: iOS secrets in place but the external-group path is new; Supabase social-provider secrets; Play listing review; F-Droid recipe version fields pending the first tagged release.

---

## 17. Known gaps and stale documentation

Discrepancies between the committed documentation and the verified state of the code, the repository configuration, and the live Supabase project. Items marked **FIXED** were corrected on 2026-08-01; the rest are listed so they can be addressed deliberately.

### A. Migration row/file mismatch — *not* drift (corrected 2026-08-01) ✅

An earlier revision of this section claimed two migrations existed in the reference deployment with no file in the repo, and called it schema drift. **That was wrong** — it compared migration *names* without reading the migration *files*. Both cases are deliberate and documented in the file that absorbed them:

| Applied row | Reality |
|---|---|
| `invoice_annex_occurred_on` (`20260727193809`) | Section 4 of `0070_payment_date_and_period.sql`, applied as a separate row. The file's own header says so: *"Applied to staging 2026-07-27 as two migration rows … this file is the single source of truth for a rebuild."* |
| `0051_single_use_invites_member_validation` (`20260722201136`) | An interim draft superseded the same day by `0051_personal_invitations` + `0052_member_join_validation`. `0052`'s header says so, and its section 0 drops the draft's leftovers (`mint_invite_token`, `invite_tokens`). |

Convergence from either state was **verified**, not assumed: `0052` uses `drop policy if exists` before `create policy` for both policies the draft created (`workspaces_select_pending`, `members_select_self`) and `drop … if exists` for its abandoned objects, so a fresh deploy and the hosted project end up identical. `vat_grants_hardening` (`0073`) is applied twice, which is harmless.

**The repo is complete.** The lesson — a migration-row name that does not match a file is not evidence of drift until you have read the file — is now written into `Implementation.md` under *Backend / migrations*.

This does supersede an earlier project note that `0071`/`0072` were unapplied: they are applied, along with `0073`.

### B. Branch protection is documented but does not exist — **FIXED (applied 2026-08-01)** ✅

For three weeks the docs claimed direct pushes to `master` were blocked while the API reported no protection and no rulesets — the rules were honoured by convention alone.

Resolved the durable way, not just the one-click way: the required-check set lives as **data** in `scripts/branch_protection.sh` (verify / apply / show), `apply` was run with the owner's authorization, and `verify` confirms the live configuration matches the committed target. `master` now requires the `analyze · l10n gate · test · coverage` context, blocks force-pushes and deletions, and demands linear history. Strict mode is deliberately off (no merge queue → quadratic CI; serialise merges instead) and `enforce_admins` is off (the solo maintainer keeps an admin escape hatch). An advisory CI step reports drift.

### C. Two date-dependent tests fail from 2026-08-01 — **FIXED (clock seam)** ✅

Resolved by the `clockProvider` seam: `SystemClock` in the app, `FixedClock(kTestNow)` pinned by `standardTestOverrides`, ~50 `lib/` call sites migrated, and `test/lint/no_wall_clock_test.dart` guarding both halves with a shrink-only exempt list. Making `seat_occupancy`'s `now` required (instead of wall-clock-defaulted) surfaced three real presence-dot bugs on Plan, kiosk and the Reserve hub. Original finding kept below for the record.

#### Original finding (2026-08-01, superseded)

`flutter test` on `master` is **1 011 passed / 2 failed** as of 2026-08-01. CI's last run (2026-07-28) was green — these are time bombs that went off at the month boundary, not a regression from any commit:

| Test | Failure |
|---|---|
| `test/features/calendar/calendar_screen_test.dart:74` — *landscape splits the month + controls into a side panel* | asserts the literal `find.text('July 2026')` against a screen that renders the **real** current month |
| `test/features/money/money_screen_test.dart:189` — *a bought package shows as a Day packages bill line (0042)* | `packages-card` not found — the seeded package is bound to the previous period |

Both need their clock pinned rather than their string bumped, or they will fail again on 2026-09-01. **CI will go red on the next push to `master`.**

### D. Counts in the README and wiki — **FIXED** ✅

| Claim | Source | Corrected to |
|---|---|---|
| "30 SQL migrations" | `README.md` §Status | 73 |
| "600+ tests" | `README.md` §Status | 1000+ |
| "740+ tests" | `Implementation.md` | 1000+ |
| "migrations 0001..0048" | `Implementation.md` | 0001..0073 |
| "ADRs 0001..0008" | `Implementation.md` | 0001..0010 |
| Edge Functions listed as 4 | `Implementation.md` | 5 (`send-e-invoice` added) |
| "the macOS channel is still an open decision" | `Implementation.md` §Release | settled — notarised DMG |
| CI section listed 6 of 10 workflows | `Implementation.md` | all 10 |
| `workspace_admin_invites` described as live | `Architecture.md` | dropped by 0051; replaced by single-use personal `invitations` |
| backend table map stopped at 0048 | `Architecture.md` | extended through 0073 (spaces, invoicing, e-invoicing, VAT) |
| feature list missing 5 subsystems | `README.md` | payments, invoicing/e-invoicing, kiosk/RFID, validation quorum, in-app help added |

### E. The specification predates the payments and invoicing work — **FIXED (annotated)** ✅

`docs/SPECIFICATION.md` is the **owner-validated** statement of intent (v1.1, 2026-07-07), so it was annotated rather than rewritten: an amendment block after the preamble, plus inline superseded-notes at §7.4 (payments are live behind an off-by-default flag; the no-SDK constraint that produced the paragraph is intact) and §12 (Windows MSI, macOS notarised DMG, browser target).

The invoicing/e-invoicing chain (0060–0073, ADR 0010) still has **no section of its own** in the spec — the amendment block says so and points at ADR 0010 and the wiki. Writing that section is a product-doc decision for the owner, not a mechanical fix.

### F. `docs/design/payments-integration.md` presented shipped work as a proposal — **FIXED** ✅

§6 opened *"New migration (not yet written — ship with the first live PSP)"* while the document's own status line said implemented. It now states that migration 0045 shipped (extended by 0047/0048) and flags the one deviation from the draft: idempotency is keyed on `(provider, order_id)`, not the capture id, so a provider reporting settlement before a capture id exists still settles exactly once. §8 is retitled as historical.

### G. SPDX headers not fully migrated to 0BSD

ADR 0009 says *"all 350+ SPDX headers"* become `0BSD`. 470 files under `lib/ test/ tool/ tools/ scripts/ supabase/` now carry `0BSD`, but **ten files still declare MIT**:

```
.github/workflows/ios-testers.yml
Gemfile
ios/fastlane/Appfile
ios/fastlane/Fastfile
ios/fastlane/Matchfile
scripts/audit_no_gms.sh
scripts/gen_app_icon.py
tools/upload_listing.py
tools/upload_to_play.py
windows/installer/deskilo.wxs
```

(`docs/decisions/0004-mit-license.md` correctly keeps its MIT reference — it *is* the superseded ADR.) The `LICENSE` file and the F-Droid recipe are correct.

### H. `flutter_launcher_icons` adaptive background is off-brand

`flutter_launcher_icons.yaml` sets `adaptive_icon_background: "#D32F2F"` — a red. The brand primary is burnt orange `#C2410C` (ADR/design system). Possibly deliberate for contrast against the foreground artwork, but it is the one color in the repo that does not come from the token set.

### I. Coverage gate is well below the stated pyramid

CI enforces **≥ 45 %** line coverage while the methodology describes a 70/20/10 TDD pyramid with a "coverage gate". 45 % is a floor that a 1 000-test suite clears comfortably; it is not a meaningful ratchet. Raising it incrementally would make it one.

### J. F-Droid recipe still carries `TODO-first-release`

Four fields (`versionName`, `commit`, `CurrentVersion`, `CurrentVersionCode`) are placeholders. The recipe cannot be submitted until the first `vX.Y.Z` tag exists.

### K. Factur-X conformance is asserted by unit test, not by a validator

ADR 0010 is explicit: the PDF/A-3 structure (part 3, the attachment, the conformance level, the embedded document) is asserted by test, but **full PDF/A-3 conformance still needs an external validator** — veraPDF, Mustang or FNFE. That is the remaining gate before the output can be called certified.

### L. E-invoice provider integration is untested end-to-end

The generic adapter and `send-e-invoice` are built and every attempt is logged with a SHA-256 of what left, but the path is **blocked on a real provider account**. No document has actually reached a Peppol access point or a *plateforme agréée* from this code.

---

*Generated by inspecting the repository, the GitHub API, and the live Supabase project. For behavior, `docs/SPECIFICATION.md` remains authoritative; for rules, `docs/AGENT_RULES.md`; for the release toolchain, `docs/guides/RELEASING.md`.*
