# DesKilo Wiki

**DesKilo** is a free, privacy-first, open-source app for small self-organized coworking communities: visual desk booking plus the community money layer, mobile-first, libre. It runs on Android (Play + F-Droid), iOS, and desktop (macOS, Windows).

Every feature serves at least one of three goals (the *feature filter*):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data, works on F-Droid.

## Pages

| Page | Audience | Content |
|---|---|---|
| [Architecture](Architecture) | Developers | Stack, feature-first layout, state management, the Supabase data model, security (RLS + RPCs), i18n, platforms |
| [Implementation](Implementation) | Developers / contributors | Repo layout, conventions, codegen, migrations, testing, CI, how to build and run on every platform |
| [User Guide](User-Guide) | Members, admins, owners | Complete walkthrough in English: onboarding, booking, roles & invites, money, settings |
| [Guide utilisateur](Guide-utilisateur) | Membres, admins, propriétaires | Le guide complet en français |

## Key references in the repository

- Product specification: [`docs/SPECIFICATION.md`](https://github.com/fdittgen-png/deskilo/blob/master/docs/SPECIFICATION.md)
- Architecture Decision Records: [`docs/decisions/`](https://github.com/fdittgen-png/deskilo/tree/master/docs/decisions)
- Contribution rules: [`CONTRIBUTING.md`](https://github.com/fdittgen-png/deskilo/blob/master/CONTRIBUTING.md)
- SQL schema, RLS, and RPCs: [`supabase/migrations/`](https://github.com/fdittgen-png/deskilo/tree/master/supabase/migrations)

## License

MIT © 2026 Florian DITTGEN. Sibling project of [Sparkilo / tankstellen](https://github.com/fdittgen-png/tankstellen).
