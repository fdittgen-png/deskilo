# DesKilo Wiki

**DesKilo** is a free, privacy-first, open-source app for small self-organized coworking communities: visual desk booking, the community money layer and a private-by-default social network of spaces, mobile-first, libre — self-hostable, or used on the reference deployment (and its shared directory) operated by Florian DITTGEN. It runs on Android (Play), iOS/iPadOS (TestFlight), desktop (macOS, Windows) and in the browser — one identical app, live-synced across every device.

Every feature serves at least one of four goals (the *feature filter*):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, a backend a community hosts itself or shares on the reference deployment operated by Florian DITTGEN.
4. **Belong to a network, not a silo** — one personal account across spaces, a shared directory to find them, private conversations, and visibility each person chooses.

## User documentation

The user guide and the setup guide are published on the **guide site**, not in this wiki — five languages each, with a section per screen, an audience filter and search. They are also bundled in the app as its help (Settings → Help).

| Guide | Audience | English | Français | Deutsch | Español | Italiano |
|---|---|---|---|---|---|---|
| User guide | Members, administrators, owners, operators | [User guide](https://fdittgen-png.github.io/deskilo/guide/en.html) | [Guide utilisateur](https://fdittgen-png.github.io/deskilo/guide/fr.html) | [Benutzerhandbuch](https://fdittgen-png.github.io/deskilo/guide/de.html) | [Guía de usuario](https://fdittgen-png.github.io/deskilo/guide/es.html) | [Guida utente](https://fdittgen-png.github.io/deskilo/guide/it.html) |
| Setup guide | Future owners | [Setup guide](https://fdittgen-png.github.io/deskilo/guide/setup-en.html) | [Guide de démarrage](https://fdittgen-png.github.io/deskilo/guide/setup-fr.html) | [Einrichtungsanleitung](https://fdittgen-png.github.io/deskilo/guide/setup-de.html) | [Guía de puesta en marcha](https://fdittgen-png.github.io/deskilo/guide/setup-es.html) | [Guida di avvio](https://fdittgen-png.github.io/deskilo/guide/setup-it.html) |

- **The user guide** covers what DesKilo is and how to start, then every screen by audience: getting started, reserving, collaborating, settings and privacy, money, owner set-up, people and billing, tax and invoicing, and advanced topics (the two sides of a space, deployment, your own server, assistants, the task recorder).
- **The setup guide** shows how to build a coworking space: what is possible and what is necessary, the order, features and roles, notifications, reports, keeping the configuration consistent, and a four-week learning path.
- Every screenshot is taken from the demo workspace (*Atelier du Marché*, all people and figures invented) in the language of the guide.

## Developer pages

| Page | Audience | Content |
|---|---|---|
| [Architecture](Architecture) | Developers | Stack, feature-first layout, state management, the Supabase data model, security (RLS + RPCs), feature flags, online payments, i18n, platforms |
| [Technical reference](Technical-Reference) | Developers | Versions and floors, every dependency and why, the architecture, the server, the patterns, all quality gates, the release trains, the standards implemented, the ADR index |
| [Implementation](Implementation) | Developers / contributors | Repo layout, conventions, codegen, migrations, testing, CI, feature-gating checklist, how to build and run on every platform |

## Key references in the repository

- Product specification: [`docs/SPECIFICATION.md`](https://github.com/fdittgen-png/deskilo/blob/master/docs/SPECIFICATION.md)
- Architecture Decision Records: [`docs/decisions/`](https://github.com/fdittgen-png/deskilo/tree/master/docs/decisions)
- Contribution rules: [`CONTRIBUTING.md`](https://github.com/fdittgen-png/deskilo/blob/master/CONTRIBUTING.md)
- SQL schema, RLS, and RPCs: [`supabase/migrations/`](https://github.com/fdittgen-png/deskilo/tree/master/supabase/migrations)

## License

AGPL-3.0-or-later © 2026 Florian DITTGEN — free for associations, collectives and individuals; a company that modifies it publishes its changes or buys a commercial licence (ADR 0031). Sibling project of [Sparkilo / tankstellen](https://github.com/fdittgen-png/tankstellen).
