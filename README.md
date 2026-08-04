# DesKilo

**Free, privacy-first coworking community app** — visual desk booking plus the community money layer, mobile-first. Android, iOS, Windows, macOS, and the browser. Sibling of [Sparkilo](https://github.com/fdittgen-png/tankstellen).

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

Feature-complete for the v1 scope and in dogfooding: 73 SQL migrations, 1000+ tests, five locales, five Supabase Edge Functions. Google Play internal testing publishes daily; TestFlight uploads internally; macOS ships a notarised DMG and Windows an MSI on every version tag; the browser build deploys on demand. Still open: the Play production listing review, and an end-to-end e-invoice transmission against a real provider account. See the [Epics](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+label%3Aepic) for the roadmap.

## Stack (principles)

Flutter · Riverpod 3 (codegen) · freezed · go_router · flex_color_scheme (Material 3) · Hive · Supabase (RLS Postgres, self-hostable) · ARB localization (EN canonical + FR/DE/ES/IT). No Google Play Services, no Firebase, no tracking, no GPL dependencies.

## Languages

English (default) · Français · Deutsch · Español · Italiano — every user-facing string is translatable; contributions for further locales welcome.

## Contributing

Issue-first, PR < 400 lines, conventional commits, TDD. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## License

[0BSD](LICENSE) © 2026 Florian DITTGEN
