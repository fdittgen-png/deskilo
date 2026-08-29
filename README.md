# DesKilo

**Free, privacy-first coworking community app** — visual desk booking plus the community money layer, mobile-first. Android, iOS, Windows, macOS, and the browser. Sibling of [Sparkilo](https://github.com/fdittgen-png/tankstellen).

[![CI](https://github.com/fdittgen-png/deskilo/actions/workflows/ci.yml/badge.svg)](https://github.com/fdittgen-png/deskilo/actions/workflows/ci.yml)
[![License: 0BSD](https://img.shields.io/badge/License-0BSD-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.9-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-blue.svg)](https://dart.dev)

<p align="center">
  <a href="https://play.google.com/apps/testing/de.deskilo.app">
    <img alt="Join the Android closed test" src="https://img.shields.io/badge/Android%20closed%20test-000000?style=for-the-badge&logo=googleplay&logoColor=white"/>
  </a>
  <a href="https://testflight.apple.com/join/RgFX9zBe">
    <img alt="Join the iPhone beta on TestFlight" src="https://img.shields.io/badge/TestFlight%20beta-000000?style=for-the-badge&logo=apple&logoColor=white"/>
  </a>
  <a href="https://fdittgen-png.github.io/deskilo/">
    <img alt="Open the web app" src="https://img.shields.io/badge/Web%20app-000000?style=for-the-badge&logo=googlechrome&logoColor=white"/>
  </a>
</p>

> **Not yet on the public stores.** Android is in **closed testing** and iPhone on **TestFlight** — the two buttons above are how you get in, and both were checked live. A Google Play *store* badge would 404 today, so there is not one; it goes here the day the listing is public.

## Data protection (GDPR)

DesKilo is built for the EU General Data Protection Regulation, and the store
listings say so.

- **Where:** Supabase, EU region (eu-central-1). No tracking, analytics or ad SDK
  in any flavour; the F-Droid build carries no Google services at all.
- **Who may read what** is enforced on the server (row-level security and
  `has_permission()`), never only in the app: reservations are visible inside a
  workspace; alerts to the people involved and the admins; **messages only to the
  participants of a conversation, whatever their role**; **invoices and payments
  only to the member and holders of the finance permission**.
- **Access log:** every read of a member's finances by someone else is written by
  the server (`data_access_log`, migration 0133) and shown to the subject.
- **Your rights, as buttons** — Settings → Privacy & data: who can see my data,
  who accessed it, export everything (art. 20), leave with erasure (art. 17).
- **Retention:** accounting records (ledger, invoices) stay for the statutory
  period, referenced by id, not by name.
- Policy: https://fdittgen-png.github.io/deskilo/privacy.html

## The leitmotiv

Every feature must serve at least one of:

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data.

## What it does

- **Visual floor plan** drawn by the workspace owner in the built-in grid editor (levels → offices → desks → seats); a bookable seat is a 6×4-square slot with a chair, amenities, and optional paid accessories.
- **Tap-to-check-in** on the plan, walk-up or on a reservation; no-show auto-release; a time scroller browses occupancy at any moment, with a seat × day week view.
- **Reservations** — half-day, full-day or flexible granularity (per-workspace rule), open-weekday and closure-day aware, from the Reserve hub, the plan, or the calendar.
- **Members directory** — who's in, custom status, reservation chips (checked-in / reserved now / next upcoming), one-tap WhatsApp, workspace group link.
- **Roles & invites** — owner / co-owner / admin / member; single-use personal invitations minted by an owner, plus the workspace's own walk-in QR; every join lands pending until it is validated.
- **Membership plans & billing** — percentage subscriptions with fee bands on a quota + overage model (half-day units); currency from the workspace country; day packages and a per-member over-consumption policy.
- **One ledger per member** — subscription charges, overage, service consumption, community-expense credits, recorded payments, monthly statements with paid/unpaid status and PDF bill export.
- **Community expenses & services** — a member buys something for the space, an admin approves, the amount is credited against their next statement; owner-defined service catalog for extras.
- **Online payments** — PayPal, Stripe, Mollie and Wero, opt-in per workspace; the app opens the provider's own hosted page and settles the ledger from a signed webhook, so no payment SDK is ever linked into the build.
- **Invoicing** — immutable signed invoices derived from the month's tracked data, with a void/replacement chain, PDF export, reminders and payment-linked matching; EN 16931 e-invoices as UBL or as a Factur-X hybrid PDF, plus SAF-T/FEC accounting export and VAT management.
- **Kiosk mode** — a wall tablet in locked plan view; members check in by scanning a QR badge or tapping an RFID card, whose credential is stored only as a hash.
- **Events & confirmation protocol** — an auditable event feed; anything an admin does *for somebody else* stays pending until that person confirms, under a per-workspace validation quorum.
- **Workspace portability** — the whole floor-plan configuration exports/imports as XML; feature flags let each community switch modules on or off.
- **Notifications** — local check-in reminders plus FCM push (confirmations, overrules) with the app-icon badge.
- **In-app help** in every language, compiled from the wiki user guides and available offline.

Full product spec: [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) · architecture, implementation notes and user guides (EN/FR): [project wiki](https://github.com/fdittgen-png/deskilo/wiki).

## Status

Feature-complete for the v1 scope and in dogfooding: **123 SQL migrations**, **1 575 tests**, five locales, **eight Supabase Edge Functions**.

**Shipping.** One `release-train.yml` dispatch builds every platform from the SAME commit, so testers on Android and iPhone are never comparing different code: Play **closed alpha** and **TestFlight external** both carry build 1600111. macOS ships a DMG and Windows an MSI on every version tag; the browser build deploys on demand to the Pages URL above.

**Still open.** Play *production* is gated on Google's own rule — twelve testers opted in to the closed test for fourteen continuous days — not on a build. Also outstanding: an end-to-end e-invoice transmission against a real provider account, and the Apple App Store submission. See the [Epics](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+label%3Aepic) for the roadmap.

## Stack (principles)

Flutter 3.44.9 / Dart 3.12.2 · Riverpod 3 (codegen) · freezed · go_router · flex_color_scheme (Material 3) · Hive · Supabase (RLS Postgres, self-hostable) · ARB localization (EN canonical + FR/DE/ES/IT). Firebase Cloud Messaging is the push transport (ADR 0011) and the only Google dependency; no tracking, no analytics, no GPL dependencies.

## Languages

English (default) · Français · Deutsch · Español · Italiano — every user-facing string is translatable; contributions for further locales welcome.

## Contributing

Issue-first, PR < 400 lines, conventional commits, TDD. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## License

[0BSD](LICENSE) © 2026 Florian DITTGEN
