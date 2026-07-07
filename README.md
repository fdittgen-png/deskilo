# DesKilo

**Free, privacy-first coworking community app** — visual desk booking plus the community money layer, mobile-first, libre. Android (Play + F-Droid) and iOS. Sibling of [Sparkilo](https://github.com/fdittgen-png/tankstellen).

## The leitmotiv

Every feature must serve at least one of:

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data, works on F-Droid.

## What it does

- **Visual floor plan** drawn by the workspace owner on a square grid (levels → offices → desks → seats); a bookable seat is a 6×4-square slot with a chair and amenities.
- **Tap-to-check-in** on the plan, walk-up or on a reservation; no-show auto-release; time scroller to browse occupancy at any moment.
- **Reservations** — punctual or recurring series, with a per-workspace rules engine (horizons, quotas, cancellation deadlines).
- **Membership plans** — Full / Half / Flex on a quota + overage model (half-day units); currency from the workspace country.
- **One ledger per member** — subscription charges, overage, community-expense credits, recorded payments, monthly statements with paid/unpaid status.
- **Community expenses** — a member buys something for the space, an admin approves, the amount is credited against their next statement.
- **Confirmation protocol** — anything an admin does *for somebody else* stays pending until that person confirms.

Full product spec: [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md).

## Status

Pre-MVP — specification validated, implementation starting. See the [Epics](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+label%3Aepic) for the roadmap.

## Stack (principles)

Flutter · Riverpod 3 (codegen) · freezed · go_router · flex_color_scheme (Material 3) · Hive · Supabase (RLS Postgres, self-hostable) · ARB localization (EN canonical + FR/DE/ES/IT). No Google Play Services, no Firebase, no tracking, no GPL dependencies.

## Languages

English (default) · Français · Deutsch · Español · Italiano — every user-facing string is translatable; contributions for further locales welcome.

## Contributing

Issue-first, PR < 400 lines, conventional commits, TDD. See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

## License

[MIT](LICENSE) © 2026 Florian DITTGEN
