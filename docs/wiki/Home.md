# DesKilo Wiki

**DesKilo** is a free, privacy-first, open-source app for small self-organized coworking communities: visual desk booking plus the community money layer, mobile-first, libre. It runs on Android (Play), iOS/iPadOS (TestFlight), desktop (macOS, Windows) and in the browser — one identical app, live-synced across every device. Current highlights (v1.0.0): reservations on every granularity (half-days, full days, real hours, minute grids) with owner-set **booking policies**, walk-up booking by QR/NFC scan and whole desk/room/level reservations marked on the plan with the occupant's name, a wall-tablet kiosk mode, an events feed with grouping and member-to-member messaging (in-app and via the workspace's own WhatsApp channel), the community money layer — subscriptions, ledger, invoicing with VAT and EN 16931 e-invoicing, owner-templated report PDFs — and a configurable role → permission matrix.

Every feature serves at least one of three goals (the *feature filter*):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data.

## Pages

| Page | Audience | Content |
|---|---|---|
| [Architecture](Architecture) | Developers | Stack, feature-first layout, state management, the Supabase data model, security (RLS + RPCs), feature flags, online payments, i18n, platforms |
| [Implementation](Implementation) | Developers / contributors | Repo layout, conventions, codegen, migrations, testing, CI, feature-gating checklist, how to build and run on every platform |
| [User Guide](User-Guide) | Members, admins, owners | Complete illustrated walkthrough in English: onboarding, booking, roles & invites, money, online payments & NFC configuration, space QR codes, kiosk mode, settings |
| [Guide utilisateur](Guide-utilisateur) | Membres, admins, propriétaires | Le guide complet en français |
| [Benutzerhandbuch](Benutzerhandbuch) | Mitglieder, Admins, Inhaberinnen | Das vollständige Handbuch auf Deutsch |
| [Guía de usuario](Guia-de-usuario) | Miembros, admins, propietarios | La guía completa en español |
| [Guida utente](Guida-utente) | Membri, admin, proprietari | La guida completa in italiano |

All five user guides are illustrated with real app screenshots (French UI — every screen exists identically in all five languages).

## Key references in the repository

- Product specification: [`docs/SPECIFICATION.md`](https://github.com/fdittgen-png/deskilo/blob/master/docs/SPECIFICATION.md)
- Architecture Decision Records: [`docs/decisions/`](https://github.com/fdittgen-png/deskilo/tree/master/docs/decisions)
- Contribution rules: [`CONTRIBUTING.md`](https://github.com/fdittgen-png/deskilo/blob/master/CONTRIBUTING.md)
- SQL schema, RLS, and RPCs: [`supabase/migrations/`](https://github.com/fdittgen-png/deskilo/tree/master/supabase/migrations)

## License

0BSD (BSD Zero Clause) © 2026 Florian DITTGEN. Sibling project of [Sparkilo / tankstellen](https://github.com/fdittgen-png/tankstellen).
