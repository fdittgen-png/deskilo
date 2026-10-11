# DesKilo Wiki

**DesKilo** is a free, privacy-first, open-source app for small self-organized coworking communities: visual desk booking, the community money layer and a private-by-default social network of spaces, mobile-first, libre — self-hostable, or used on the reference deployment (and its shared directory) operated by Florian DITTGEN. It runs on Android (Play), iOS/iPadOS (TestFlight), desktop (macOS, Windows) and in the browser — one identical app, live-synced across every device.

Every feature serves at least one of four goals (the *feature filter*):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, a backend a community hosts itself or shares on the reference deployment operated by Florian DITTGEN.
4. **Belong to a network, not a silo** — one personal account across spaces, a shared directory to find them, private conversations, and visibility each person chooses.

## Pages

| Page | Audience | Content |
|---|---|---|
| [Architecture](Architecture) | Developers | Stack, feature-first layout, state management, the Supabase data model, security (RLS + RPCs), feature flags, online payments, i18n, platforms |
| [Technical reference](Technical-Reference) | Developers | Versions and floors, every dependency and why, the architecture, the server, the patterns, all 31 quality gates, the release trains, the standards implemented, the ADR index |
| [Configuring the space](Admin-Configuration-Guide) | Owners | Every parameter the questionnaire asks, the master data, the floor plan — including how to turn photographs of the room into a plan image with an AI |
| [Configurer l'espace](Admin-Configuration-Guide.fr) | Propriétaires | Le guide de configuration en français : chaque paramètre du questionnaire, les données de référence, le plan des locaux |
| [Den Bereich einrichten](Admin-Configuration-Guide.de) | Inhaberinnen | Der Konfigurationsleitfaden auf Deutsch: jeder Parameter des Fragebogens, die Stammdaten, der Raumplan |
| [Configurar el espacio](Admin-Configuration-Guide.es) | Propietarios | La guía de configuración en español: cada parámetro del cuestionario, los datos maestros, el plano |
| [Configurare lo spazio](Admin-Configuration-Guide.it) | Proprietari | La guida di configurazione in italiano: ogni parametro del questionario, i dati di base, la piantina |
| [The technical side](Admin-Technical-Guide) | Administrators | Documents and the report designer, e-invoicing, accounting exports, integrations, instances, the trace |
| [Le côté technique](Admin-Technical-Guide.fr) | Administrateurs | Les documents et le concepteur de rapports, la facturation électronique, les exports comptables, les intégrations, les instances, le journal |
| [Die technische Seite](Admin-Technical-Guide.de) | Administratoren | Die Dokumente und der Berichts-Entwerfer, die E-Rechnung, die Buchhaltungsexporte, die Integrationen, die Instanzen, das Protokoll |
| [La parte técnica](Admin-Technical-Guide.es) | Administradores | Los documentos y el diseñador de informes, la facturación electrónica, las exportaciones contables, las integraciones, las instancias, el registro |
| [La parte tecnica](Admin-Technical-Guide.it) | Amministratori | I documenti e il progettista dei report, la fatturazione elettronica, le esportazioni contabili, le integrazioni, le istanze, il registro |
| [Environments: dev and prod](Environments-Guide) | Owners | Why a pair, creating it, who may deploy, what travels and what never does |
| [Environnements : dev et prod](Environments-Guide.fr) | Propriétaires | Pourquoi une paire, comment la créer, qui peut déployer, ce qui voyage et ce qui ne voyage jamais |
| [Umgebungen: Dev und Prod](Environments-Guide.de) | Inhaberinnen | Warum ein Paar, wie man es anlegt, wer deployen darf, was reist und was nie |
| [Entornos: dev y prod](Environments-Guide.es) | Propietarios | Por qué una pareja, cómo crearla, quién puede desplegar, qué viaja y qué nunca |
| [Ambienti: dev e prod](Environments-Guide.it) | Proprietari | Perché una coppia, come crearla, chi può distribuire, che cosa viaggia e che cosa mai |
| [Implementation](Implementation) | Developers / contributors | Repo layout, conventions, codegen, migrations, testing, CI, feature-gating checklist, how to build and run on every platform |

## User documentation

The user guide and the setup guide are published on the **guide site**, not in this wiki — five languages each, with a section per screen, an audience filter and search:

| Guide | Audience | English | Français | Deutsch | Español | Italiano |
|---|---|---|---|---|---|---|
| User guide | Members, admins, owners | [User guide](https://fdittgen-png.github.io/deskilo/guide/en.html) | [Guide utilisateur](https://fdittgen-png.github.io/deskilo/guide/fr.html) | [Benutzerhandbuch](https://fdittgen-png.github.io/deskilo/guide/de.html) | [Guía de usuario](https://fdittgen-png.github.io/deskilo/guide/es.html) | [Guida utente](https://fdittgen-png.github.io/deskilo/guide/it.html) |
| Setup guide | Future owners | [Setup guide](https://fdittgen-png.github.io/deskilo/guide/setup-en.html) | [Guide de démarrage](https://fdittgen-png.github.io/deskilo/guide/setup-fr.html) | [Einrichtungsanleitung](https://fdittgen-png.github.io/deskilo/guide/setup-de.html) | [Guía de puesta en marcha](https://fdittgen-png.github.io/deskilo/guide/setup-es.html) | [Guida di avvio](https://fdittgen-png.github.io/deskilo/guide/setup-it.html) |

The user guide covers what DesKilo is, how to start a space, then every screen by audience — getting started, reserving, collaborating, settings and privacy, money, owner set-up, billing, tax and invoicing, advanced topics. The setup guide shows how to build a coworking space: what is possible and what is necessary, the order, features and roles, notifications, reports, keeping the configuration consistent, and a four-week learning path. Every screenshot is taken from the demo workspace (*Atelier du Marché*, all people and figures invented) in the language of the guide. The same guides are bundled in the app as its help (Settings → Help).

## Key references in the repository

- Product specification: [`docs/SPECIFICATION.md`](https://github.com/fdittgen-png/deskilo/blob/master/docs/SPECIFICATION.md)
- Architecture Decision Records: [`docs/decisions/`](https://github.com/fdittgen-png/deskilo/tree/master/docs/decisions)
- Contribution rules: [`CONTRIBUTING.md`](https://github.com/fdittgen-png/deskilo/blob/master/CONTRIBUTING.md)
- SQL schema, RLS, and RPCs: [`supabase/migrations/`](https://github.com/fdittgen-png/deskilo/tree/master/supabase/migrations)

## License

AGPL-3.0-or-later © 2026 Florian DITTGEN — free for associations, collectives and individuals; a company that modifies it publishes its changes or buys a commercial licence (ADR 0031). Sibling project of [Sparkilo / tankstellen](https://github.com/fdittgen-png/tankstellen).
