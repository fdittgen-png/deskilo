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
| Push | UnifiedPush (`unifiedpush`) + `flutter_local_notifications` | No Firebase/GMS anywhere (ADR 0003) |

Forbidden by ADR 0003 / 0004: Google Play Services, Firebase, third-party tracking, GPL dependencies.

## Client layout (feature-first)

```
lib/
  app/            # DeskiloApp, router, shell (bottom bar, app bar)
  core/           # cross-cutting: theme tokens, storage, notifications,
                  # push (UnifiedPush connector), trace logger, shared UI
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
- `members` — a user's participation in a workspace: `is_admin`, `is_owner` booleans (roles are additive), `status` (`active`/`paused`/`exited`), subscription percentage.
- `workspace_admin_invites` — one secret **admin invite code** per workspace (0030), readable by owners only.
- Floor plan: `levels` → `offices` → `desks` → `seats` (0003), seat blocking (0021), accessories (0022/0023).
- Booking: `reservations` + conflict-checked RPCs (0005), booking rules & series (0006), availability/open weekdays/closures (0013), granularity incl. minute slots (0025/0032), half-day walk-up (0026), reservation moves (0033), quota enforcement + extra-half-day requests (0031).
- Money: ledger/payments (0008), expenses (0009), service catalog & consumption (0014/0016), percentage subscriptions with fee bands (0015), payment method & instructions (0019/0020), accessory supplements (0024), per-member over-consumption policy (0041), day packages + self-serve buy (0042).
- **Online payments — live** (0044/0045/0047/0048): `payment_intents` tracks each provider order; `payment_credentials` holds the per-workspace provider secrets in a **deny-all table** (RLS enabled, deliberately *zero* policies — only service-role Edge Functions and owner `SECURITY DEFINER` RPCs touch it, and secret *values* are never returned to any client, only key names via `payment_credentials_status`). Settlement goes through the idempotent `settle_online_payment` RPC keyed on `(provider, order_id)`. See *Online payments* below.
- Events & confirmation protocol (0007), quorum validation (0017), solo-admin auto-respond (0011), validated role changes (0035).
- Push endpoints (0012), feature flags (0018), XML floor-plan import/export (0027/0034), profile presence & WhatsApp (0028/0029/0033).
- Plan visuals: level background photos (0036), resizable illustration images (0037), member avatars (0038), desk opacity (0040); owner-guarded workspace reset (0039).
- Kiosk mode (0043): `members.is_kiosk`, hashed badge tokens (`member_badges`), and the stateless `kiosk_act` RPC that lets a wall tablet act *as* the badge's member without any session on the device.
- RFID/NFC badges (0046): `member_badges.kind` (`qr` | `nfc`), `register_nfc_badge` stores the card UID as a SHA-256 hash; the kiosk feeds a tapped card's UID into the same `kiosk_act` path as a scanned QR.
- Per-member reservation cap (0044): owners/admins set how many simultaneous open reservations a member may hold (never their own row), enforced server-side.

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

Invite QR codes encode `deskilo://join?role=<user|admin>&code=<CODE>` (`InviteUriCodec` in `features/workspace/domain/invite_uri.dart`). The in-app scanner accepts this URL form *and* legacy raw-code QRs, and ignores unrelated QR content. The `role` parameter is informational — the server resolves the actual role from the code.

## Internationalization

- `app_en.arb` is canonical; FR/DE/ES/IT ship with full key parity (CI gate).
- No hard-coded user-facing strings — lint-ratcheted; every string goes through `AppLocalizations` with an English fallback literal.
- Dates, numbers and currency always render through locale-aware `intl` formatting; the workspace **country** drives the default currency.

## Platforms

Single codebase for all targets. Platform-specific behavior degrades gracefully:

- **Push** (UnifiedPush) is Android-only — `PushConnector` returns `false` elsewhere and the app stays on local notifications.
- **Desktop** (macOS/Windows) runs the full booking/ledger app; the macOS sandbox needs the network-client, camera, and user-selected-file entitlements (see the runner in `macos/`). Windows ships as a WiX-built **MSI** (`windows/installer/deskilo.wxs`, built by the `windows-msi` workflow).
- The F-Droid Android flavor is 100% Google-services-free, audited by script.

## Shared building blocks

Cross-surface concepts have exactly one implementation: `PlanCanvas` (+ `PlanCanvasMetrics`) is the floor-plan host for the Plan tab, the Reserve hub, and the kiosk; `seat_occupancy.dart` derives occupant labels, seat states, and presence dots; `LevelChipRow` is the level selector; `runGuarded` is the traced-failure wrapper every mutating call site uses; `linkLauncherProvider` is the one (test-capturable) external-link seam; `SheetShell` the modal-form scaffold; `centsToMajor`/`parseCentsInput` the money-input helpers.

## Design system

Material 3, three themes (light / dark / signature blend), brand color burnt orange `#C2410C`. `AppRadius` tokens (4/8/12/16/24) — no inline border radii, lint-enforced. Seat states use a muted, colorblind-safe palette and are never conveyed by color alone (icons/patterns too, guarded by accessibility tests).
