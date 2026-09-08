# Architecture

DesKilo is a Flutter app backed by Supabase. The client is feature-first and fully typed; the server is an RLS-protected Postgres where **every multi-user write goes through a SECURITY DEFINER RPC** so business invariants live next to the data.

## Stack

| Layer | Choice | Why (ADR) |
|---|---|---|
| UI framework | Flutter (pinned stable), Material 3 via `flex_color_scheme` | One codebase for Android, iOS, macOS, Windows (ADR 0001) |
| State | Riverpod 3 **with codegen** (`@riverpod` / `@Riverpod(keepAlive: true)`) | Compile-safe providers, no manual provider wiring (ADR 0001) |
| Models | `freezed` immutable data classes | Value semantics, exhaustive `sealed` matching |
| Routing | `go_router` with a `StatefulShellRoute` bottom-nav shell | Declarative redirects encode role/feature gating (see *Feature flags*) |
| NFC | `nfc_manager` behind an injectable `NfcUidReader` seam | Card-UID reads for badges; Android-only, degrades gracefully |
| Backend | **Supabase** — Auth, RLS Postgres, RPCs | Multi-user source of truth, self-hostable to keep the libre promise (ADR 0002) |
| Local storage | Hive (encrypted) + `shared_preferences` | Offline read cache, active-workspace choice |
| Networking | `supabase_flutter` (PostgREST + GoTrue); `dio` where raw HTTP is needed | |
| i18n | ARB, EN canonical + FR/DE/ES/IT | Every user-facing string translatable, lint- and CI-enforced (ADR 0007) |
| QR | `qr_flutter` (render) + `flutter_zxing` (scan) | Libre, Google-services-free scanning (ADR 0003) |
| Push | a swappable `deskilo_push` package + `flutter_local_notifications` | Store builds use FCM; the libre flavour swaps in `deskilo_push_foss` (ADR 0011, ADR 0012) |

Forbidden outright by ADR 0004: third-party tracking and GPL dependencies.
**Google Play Services and Firebase are flavour-scoped, not forbidden**
(ADR 0003 as amended by ADR 0012): the app depends on the local package
`deskilo_push`, and the F-Droid build swaps in `deskilo_push_foss`, which
implements the same interface with no Google dependency at all. That
swap is audited on every pull request by *CI · F-Droid no-GMS audit*, so
the libre promise is a test result rather than an intention.

## Client layout (feature-first)

```
lib/
  app/            # DeskiloApp, router, shell (bottom bar, app bar)
  core/           # cross-cutting: theme tokens, storage, notifications,
                  # push (FCM connector), trace logger, shared UI
  l10n/           # ARB sources (app_en.arb canonical) + generated localizations
  features/
    auth/         # email+password sign-in/up (Supabase Auth)
    workspace/    # workspace CRUD, onboarding, invites, members admin,
                  # availability rules, feature flags, XML import/export
    plan/         # the live floor plan + time scroller, accessories
    editor/      # owner grid editor (levels → offices → desks → seats)
    reservations/ # Reserve hub, series, week view
    calendar/     # month/week/day views of own reservations
    events/       # event feed + confirmation protocol, validation settings
    members/      # member directory (status, WhatsApp, reservation chips)
    money/        # ledger, statements, billing, packages, services, PDF export
    kiosk/        # wall-tablet mode: locked plan view + badge-driven actions
    help/         # in-app help, compiled from the wiki user guides
    profile/      # settings, profiles (multi-workspace), developer screen
```

Each feature keeps the same internal shape: `domain/` (freezed models + a pure-Dart repository interface), `data/` (the Supabase implementation), `providers/` (Riverpod codegen), `presentation/` (screens + widgets). Tests replace the `data/` layer with fakes — **fakes over mocks** — via `standardTestOverrides()` in `test/helpers/mock_providers.dart`.

## State management pattern

- Repositories are exposed as `keepAlive` providers (`workspaceRepositoryProvider`, …).
- Derived state is expressed as async providers that `watch` upstream ones; e.g. `currentWorkspace` recomputes from `myWorkspaces` + the persisted `ActiveWorkspaceId`, and everything workspace-scoped (`workspaceMembers`, `enabledFeatures`, `adminInviteCode`, …) watches `currentWorkspace`, so **switching profiles re-derives the whole app state with no extra plumbing**.
- Role gating in the UI reads `myMember` (the caller's membership row) — but the UI is never the enforcement layer; RLS is.

## Backend model

### Core tables (migration 0001+)

- `profiles` — 1:1 with `auth.users`, created by trigger on signup.
- `workspaces` — one coworking community; `invite_code` doubles as the human-readable workspace ID and the **member invite**.
- `members` — a user's participation in a workspace: `is_admin`, `is_owner` booleans (roles are additive), `status` (`active`/`paused`/`pending`/`exited`), subscription percentage.
- `invitations` — **single-use personal invitations** (0051): one code, one role, one expiry, one redemption. This replaced the static per-workspace admin secret of 0030, whose `workspace_admin_invites` table is **dropped** — a forwarded admin code must not mint admins forever. `workspaces.invite_code` stays the open member-level walk-in handle (the printed QR and the human-readable workspace ID). Since 0052 every join lands as a **pending** membership that owner/admins validate through the same quorum as payments and expenses; a pending member sees only the workspace name until then.
- Floor plan: `levels` → `offices` → `desks` → `seats` (0003), seat blocking (0021), accessories (0022/0023).
- Booking: `reservations` + conflict-checked RPCs (0005), booking rules & series (0006), availability/open weekdays/closures (0013), granularity incl. minute slots (0025/0032), half-day walk-up (0026), reservation moves (0033), quota enforcement + extra-half-day requests (0031).
- Money: ledger/payments (0008), expenses (0009), service catalog & consumption (0014/0016), percentage subscriptions with fee bands (0015), payment method & instructions (0019/0020), accessory supplements (0024), per-member over-consumption policy (0041), day packages + self-serve buy (0042).
- **Online payments — live** (0044/0045/0047/0048): `payment_intents` tracks each provider order; `payment_credentials` holds the per-workspace provider secrets in a **deny-all table** (RLS enabled, deliberately *zero* policies — only service-role Edge Functions and owner `SECURITY DEFINER` RPCs touch it, and secret *values* are never returned to any client, only key names via `payment_credentials_status`). Settlement goes through the idempotent `settle_online_payment` RPC keyed on `(provider, order_id)`. See *Online payments* below.
- Events & confirmation protocol (0007), quorum validation (0017), solo-admin auto-respond (0011), validated role changes (0035).
- Push endpoints (0012), feature flags (0018), XML floor-plan import/export (0027/0034), profile presence & WhatsApp (0028/0029/0033).
- Plan visuals: level background photos (0036), resizable illustration images (0037), member avatars (0038), desk opacity (0040); owner-guarded workspace reset (0039).
- Kiosk mode (0043): `members.is_kiosk`, hashed badge tokens (`member_badges`), and the stateless `kiosk_act` RPC that lets a wall tablet act *as* the badge's member without any session on the device.
- RFID/NFC badges (0046): `member_badges.kind` (`qr` | `nfc`), `register_nfc_badge` stores the card UID as a SHA-256 hash; the kiosk feeds a tapped card's UID into the same `kiosk_act` path as a scanned QR.
- Per-member reservation cap (0044): owners/admins set how many **open** reservations a member may hold in total (never their own row), enforced server-side. Distinct from the **overlapping-window allowance** of 0119 below — one bounds the size of the backlog, the other how many bookings may run at the same moment.
- Bookable spaces beyond the seat: whole levels (0050), whole offices (0057), whole desks (0059), each with its own validation path; series over spaces (0065).
- Badges, continued: self-service enrollment (0053), kiosk identify (0054), revocation that deletes the hash (0055), per-badge scope and kiosk revert (0056). Co-owner role (0058).
- **Invoicing (0060–0068)** — `invoices` holds an *immutable* document: its lines are **derived** from the period's tracked data at issue time, then frozen with a SHA-256 `signature` over the whole content, plus a `parties` snapshot so an issued document keeps saying what it said. Corrections never mutate: `replaces_invoice_id` forms a void/replacement chain (0061), and a matched invoice cannot be replaced. Also: derived lines (0062), running balance (0063), an optional detail annex of ledger movements and attendance (0064), reminders (0066), and matching against payments — payment-linked, so *paid* is definitive (0067/0068).
- **E-invoicing and tax (0069–0073)** — the seller's legal identity is declared rather than guessed (`vat_regime`, `vat_id`, `legal_id`, `tax_exemption_reason`, structured address; `profiles.country_code`/`vat_id` for the buyer), because EN 16931's `BR-CO-26` makes a seller identifier mandatory and the regime decides the whole tax mapping (0069). A payment carries the day the money moved and the month it settles, distinct from the audit stamp (0070). `einvoice_credentials` is a second **deny-all** table for the transmission provider's token (0071), and VAT rates + their grant hardening close the set (0072/0073).
- **The booking contract lives in one function (0116–0122).** `enforce_booking_rules` is the single chokepoint every creation path calls — `create_reservation`, `kiosk_act`, `update_reservation` — so a rule written once binds the app, a QR/NFC scan and the wall kiosk alike. It owns: the advance horizon, the minimum and maximum duration, the granularity shape arms (half-day, full-day, minute grids; `hours` deliberately matches none), the past-day guard and its `allow_past_bookings` escape, the walk-up-must-start-today guard, the **same-day rule** (`local_end > ts_midnight` is refused, so nothing crosses midnight while an evening walk-up ending exactly at midnight stays legal), the four-mode outside-hours gate, and finally `assert_workspace_open`. Guards were **moved** into it rather than copied — the point is that exactly one implementation of each exists, which is what closed the kiosk-parity gap (#637).
- **One outside-hours policy, four answers (0118/0120).** `booking_rules.outside_hours_mode` ∈ `off | walkup_only | free | charged`, resolved once with a read-time legacy fallback (`grid_within_hours = true` ⇒ `walkup_only`) and no data migration. Enforcement uses the wider *touches-outside* predicate so spill is refused under the strict modes; **billing keeps the narrower entirely-outside predicate** (`window_outside_working_hours`, feeding `reservation_counts_for_usage` → `assert_member_quota` and `member_statement`). That asymmetry is deliberate: a window touching the working hours at all is an ordinary counted booking.
- **Two independent caps (0119/0121).** `member_simultaneous_allowance()` bounds bookings that **overlap in time** (workspace number, default 1; a per-member override wins), enforced in `enforce_one_place`, `check_in_reservation` and `kiosk_act`. Separately, `request_reservation_deletion` carries the owner-configured auto-validation exception, whose two switches are genuinely independent since 0121 — the admin arm excludes owners, because every owner also carries `is_admin`. An auto-settled request is born **confirmed**, with a `decided_by_system` decision row and `payload.auto_validated`, so it never pings a validator about a closed question.

### What came after the booking contract (0123–0190)

The list above stops at 0122 because that is where the *booking* story
ends. Seven systems were built on top of it, and each is worth naming
because each introduced an invariant the rest of the schema now relies
on.

- **Conversations (0125–0130, 0146).** One thread implementation behind
  every surface — a profile, the directory, the inbox — with realtime,
  read receipts, and reference links (`[res:…]`, `[space:…]`) that turn
  a message into a jump. Backfilled rather than migrated twice.
- **Money made governable (0131–0151).** Finance permission gates,
  payment reminders with a level lock, price negotiations, expense
  schedules and repartition, invoice kinds, the settlement fold, and
  usage records as first-class rows. `0144_money_validation_parity` and
  `0149_validation_integrity` exist because a validation domain that
  behaves differently from its siblings is a bug, not a feature.
- **Identity (0152–0161).** Personal information on the profile
  (ADR 0014) so a document can name its buyer properly, then **managed
  members**: a person can be created, booked for and invoiced before
  they have an account, and the profile is handed over later by a bound
  invitation that goes through the ordinary join validation.
- **Numbering and sites (0164–0171).** Number sequences as a format with
  adopters, several sites under one organisation, per-site
  registrations and documents.
- **VAT as an ERP models it (0156, 0157, 0170, 0172, 0182).** Fiscal
  **groups** say what a supply is, the **treatment** says what the
  counterparty makes of it (reverse charge, ADR 0016), and **rate
  versions** carry validity dates. A rate change adds a version; every
  document already issued keeps the version frozen on it. This is the
  reason the catalogue stores a group on a service rather than a
  percentage.
- **System columns (0183, 0184; ADR 0018).** Six technical columns —
  `created_datetime`, `modified_datetime`, `company_id`, `site_id`,
  `created_by_user`, `modified_by_user` — on **every** table, maintained
  by the core and not by any caller. A `zz_`-prefixed trigger stamps
  them (the prefix matters: triggers fire in name order, so it runs
  after the guards), `ensure_system_columns(table)` adds them to a new
  table, and a lint refuses a table that lacks them. `invoices_immutable`
  subtracts `system_column_names()` from both row snapshots, so
  housekeeping does not count as mutating a frozen document.
- **Environments and deployment (0160, 0179, 0185–0190).** A workspace
  has an `environment` and a twin. `deployable_entities()` is a registry
  of what can travel; `export_entities` reads one side,
  `preview_deployment` says what would change, `deploy_entities` writes,
  and `deployments` records who, when, which direction, which entities
  and what the target held before — which is what makes
  `rollback_deployment` exact. A deployment always writes **the side the
  caller stands on**, and the capability is carried in a transaction-local
  token (`deploying_touches()`), so ordinary guards can refuse a write
  that a deployment is allowed to make without either of them knowing
  about the other. Floor plans are **merged**, never replaced (0188);
  payment instructions and design images travel as their own entities
  (0189, 0190).

### The permission and validation catalogues

`WorkspacePermission` is a flat enum of 23 permissions asked through one
server function, so a revoked permission is revoked everywhere at once —
the screen hides the control and the RPC refuses anyway.
`0180_permission_catalog_nine` and `0181_validation_domains_six` are the
migrations that made both catalogues data rather than scattered
conditionals, which is what let the role matrix become a screen.

### Documentation as a subsystem

The guides are not a folder of prose. `docs/wiki/*.md` is compiled by
`tool/build_help.dart` into `assets/help/<lang>.md` plus
`assets/help/<lang>.anchors.json`; an HTML comment above a heading
(`<!-- anchor: user.money.legal.escompte -->`) becomes an id that a help
symbol in the app can jump to. `HelpAnchor` is the shared vocabulary,
and three lints hold the whole thing together: every anchor resolves in
every language that carries its guide, no symbol points into a guide the
five languages do not all have, and the number of symbols without an
anchor may only go down.

### Online payments

Four providers — **PayPal** (Orders v2), **Stripe** (Checkout), **Mollie** (Payments API), and **Wero** (offered *through* Mollie with `method=wero`) — behind one architecture:

- `supabase/functions/create-payment-order` starts an order: it reads the workspace's `payment_credentials` row first and falls back to function env vars, records a `payment_intents` row, and returns the provider's approval URL. A `{action:'config'}` probe reports which providers are ready and which fields are missing (surfaced on the in-app developer screen).
- One webhook function per provider family (`paypal-webhook`, `stripe-webhook`, `mollie-webhook`) runs with `verify_jwt` off — authenticity comes from **the provider's own signature verification** (PayPal verify-webhook-signature, Stripe signing secret, Mollie re-fetch). Each resolves the workspace from the intent, verifies, then settles via `settle_online_payment` (idempotent, so replays are harmless). The Mollie webhook matches intents of provider `mollie` *or* `wero`.
- The client never sees a secret: the owner writes credentials through `set_payment_credentials` (blank field = keep existing), reads back only key *names* + non-secret fields (`return_url`, `env`), and can `clear_payment_provider`.
- Webhook endpoints to register in the provider dashboards (PayPal and Stripe only — Mollie's is passed per payment): `https://<project-ref>.supabase.co/functions/v1/paypal-webhook` and `…/stripe-webhook`. The step-by-step dashboard walkthrough lives in the [User Guide](User-Guide).

### Security model

Three ideas carry the whole design:

1. **Default-deny RLS.** Every table has row level security enabled; there are deliberately *no* insert policies on core tables — writes happen through `SECURITY DEFINER` RPCs (`create_workspace`, `join_workspace`, reservation RPCs, …) that validate invariants transactionally.
2. **Role helpers as SQL functions.** `is_member_of(ws)`, `is_admin_of(ws)`, `is_owner_of(ws)` are `SECURITY DEFINER` so policies can use them without recursion. Membership reads are scoped to co-members; member-row updates (roles!) and workspace updates are **owner-only**.
3. **Invariants live in triggers.** Example: `protect_last_owner` makes it impossible to demote/remove the last active owner of a workspace, no matter which path the write takes.

Role-scoped invites (0030) follow the same philosophy: the role granted on join is derived **from which secret code matched** (`workspaces.invite_code` → member, `workspace_admin_invites.code` → admin), never from a client-supplied parameter, and no owner-granting code path exists at all.

### Concurrency

Walk-up check-in and reservation creation are **atomic RPCs** with conflict checks at confirmation time — availability is never decided against a possibly-stale client view (the #1 failure mode of booking systems).

## Feature flags (per-workspace modules)

`WorkspaceFeature` + `featureManifest` (`features/workspace/domain/workspace_feature.dart`) form a declarative registry: every feature has a `defaultOn` and its enum name is the jsonb key in `workspaces.feature_flags`. `resolveEnabledFeatures` starts from the defaults and applies boolean overrides, ignoring unknown keys so old and new clients coexist. Most features default **on**; `adminSeatBlocking`, `accessorySupplements`, and `onlinePayments` default **off** because they change money or permissions.

**The gating rule: enable a feature and *all* of its surfaces appear; disable it and *none* remain.** Every feature-linked surface is gated at **two layers** with the same providers:

1. the entry point (settings tile, tab, button) checks `enabledFeaturesSync.contains(feature)`, and
2. the route guards with a `featureEnabled(...)` redirect in the router — so deep links and bookmarks bounce too.

The router's `refreshListenable` watches `enabledFeaturesProvider`, so toggling a feature (or switching workspaces) re-evaluates every redirect immediately. The master **Features** screen is deliberately *not* feature-gated — it must always be reachable to switch a module back on.

## Invites & deep links

Invite QR codes encode `deskilo://join?role=<user|admin>&code=<CODE>` (`InviteUriCodec` in `features/workspace/domain/invite_uri.dart`). The in-app scanner accepts this URL form *and* legacy raw-code QRs, and ignores unrelated QR content. The `role` parameter is informational — the server resolves the actual role from the code, and since 0051 an admin-bearing code is a **personal, single-use, expiring** invitation minted by an owner rather than a standing workspace secret. The same `deskilo://` scheme carries the OAuth callback back into the app on every platform, which is why it is registered in the Android manifest, the iOS `CFBundleURLTypes`, and the Windows installer's registry keys.

## Internationalization

- `app_en.arb` is canonical; FR/DE/ES/IT ship with full key parity (CI gate).
- No hard-coded user-facing strings — lint-ratcheted; every string goes through `AppLocalizations` with an English fallback literal.
- Dates, numbers and currency always render through locale-aware `intl` formatting; the workspace **country** drives the default currency.

## Platforms

Single codebase for all targets. Platform-specific behavior degrades gracefully:

- **Push** is Android-only — `PushConnector` returns `false` elsewhere and
  the app stays on local notifications.
- **Desktop** (macOS/Windows) runs the full booking/ledger app; the macOS sandbox needs the network-client, camera, and user-selected-file entitlements (see the runner in `macos/`). Windows ships as a WiX-built **MSI** (`windows/installer/deskilo.wxs`, built by the `windows-msi` workflow).
- **F-Droid is supported and maintained**, through the libre flavour
  above: *CI · F-Droid no-GMS audit* proves the flavour carries no Google
  dependency, and *Publish · F-Droid release APKs* ships the signed
  binaries F-Droid reproduces against. (An earlier note in this file said
  F-Droid support had been dropped; ADR 0012 reversed that, and the
  workflows are the evidence.)

  The route in is **reproducible build, not F-Droid signing**: the recipe
  in `fdroiddata` MR !47409 carries `binary:` per ABI pointing at the
  release assets plus `AllowedAPKSigningKeys` with our certificate
  fingerprint, and the build path is pinned on both sides
  (`/home/runner/work/deskilo/deskilo`) because Dart's AOT output embeds
  the directory it compiled in. The publishing job builds each ABI from a
  clean `build/`, builds arm64 a second time, and **refuses to publish if
  the two differ outside `META-INF`** — so what F-Droid verifies against
  is a binary we have already proved reproducible.

## Shared building blocks

Cross-surface concepts have exactly one implementation: `PlanCanvas` (+ `PlanCanvasMetrics`) is the floor-plan host for the Plan tab, the Reserve hub, and the kiosk; `seat_occupancy.dart` derives occupant labels, seat states, and presence dots; `LevelChipRow` is the level selector; `runGuarded` is the traced-failure wrapper every mutating call site uses; `linkLauncherProvider` is the one (test-capturable) external-link seam; `SheetShell` the modal-form scaffold; `centsToMajor`/`parseCentsInput` the money-input helpers.

## Design system

Material 3, three themes (light / dark / signature blend), brand color burnt orange `#C2410C`. `AppRadius` tokens (4/8/12/16/24) — no inline border radii, lint-enforced. Seat states use a muted, colorblind-safe palette and are never conveyed by color alone (icons/patterns too, guarded by accessibility tests).
