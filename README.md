# DesKilo

**Free, privacy-first coworking community app** — visual desk booking plus the community money layer, mobile-first, libre. Android (Play + F-Droid), iOS, Windows, and macOS. Sibling of [Sparkilo](https://github.com/fdittgen-png/tankstellen).

## The leitmotiv

Every feature must serve at least one of:

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data, works on F-Droid.

## What it does

- **Visual floor plan** drawn by the workspace owner in the built-in grid editor (levels → offices → desks → seats); a bookable seat is a 6×4-square slot with a chair, amenities, and optional paid accessories.
- **Tap-to-check-in** on the plan, walk-up or on a reservation; no-show auto-release; a time scroller browses occupancy at any moment, with a seat × day week view.
- **Reservations** — half-day, full-day or flexible granularity (per-workspace rule), open-weekday and closure-day aware, from the Reserve hub, the plan, or the calendar.
- **Members directory** — who's in, custom status, reservation chips (checked-in / reserved now / next upcoming), one-tap WhatsApp, workspace group link.
- **Roles & invites** — owner / admin / member; invitations are role-bound QR codes (member or admin — owner is never invitable), scanned in-app or typed as the workspace ID.
- **Membership plans & billing** — percentage subscriptions with fee bands on a quota + overage model (half-day units); currency from the workspace country.
- **One ledger per member** — subscription charges, overage, service consumption, community-expense credits, recorded payments, monthly statements with paid/unpaid status and PDF bill export.
- **Community expenses & services** — a member buys something for the space, an admin approves, the amount is credited against their next statement; owner-defined service catalog for extras.
- **Events & confirmation protocol** — an auditable event feed; anything an admin does *for somebody else* stays pending until that person confirms.
- **Workspace portability** — the whole floor-plan configuration exports/imports as XML; feature flags let each community switch modules on or off.
- **Notifications** — local check-in reminders plus UnifiedPush (Google-services-free) for pending confirmations.

Full product spec: [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) · architecture, implementation notes and user guides (EN/FR): [project wiki](https://github.com/fdittgen-png/deskilo/wiki).

## Status

Feature-complete for the v1 scope and in dogfooding: 30 SQL migrations, 600+ tests, five locales. Store submissions (Play review, F-Droid recipe, TestFlight) are in preparation; desktop runners (macOS, Windows) are landing. See the [Epics](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+label%3Aepic) for the roadmap.

## Stack (principles)

Flutter · Riverpod 3 (codegen) · freezed · go_router · flex_color_scheme (Material 3) · Hive · Supabase (RLS Postgres, self-hostable) · ARB localization (EN canonical + FR/DE/ES/IT). No Google Play Services, no Firebase, no tracking, no GPL dependencies.

## Languages

English (default) · Français · Deutsch · Español · Italiano — every user-facing string is translatable; contributions for further locales welcome.

## Contributing

Issue-first, PR < 400 lines, conventional commits, TDD. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## License

[0BSD](LICENSE) © 2026 Florian DITTGEN
