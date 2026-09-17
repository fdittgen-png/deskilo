# DesKilo

**Bookings, memberships and shared finances for community-run coworking spaces.**

DesKilo helps small coworking communities answer three everyday questions: **Where can I work? What do I owe? Who needs to approve this?** It connects a visual floor plan with membership allowances, member balances, shared expenses and approval workflows, so the people running the space can keep daily activity and its financial consequences together.

Built for independent spaces, associations and member-run collectives that want control over their rules and data. Open source under the permissive **0BSD license**, with a Flutter app and a backend you can run on your own Supabase instance. Currently in **beta and active dogfooding**.

[![Quality checks](https://github.com/fdittgen-png/deskilo/actions/workflows/quality.yml/badge.svg?branch=master)](https://github.com/fdittgen-png/deskilo/actions/workflows/quality.yml)
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

[Explore the illustrated user guide](docs/wiki/User-Guide.md) · [Configure a workspace](docs/wiki/Admin-Configuration-Guide.md) · [Releases](https://github.com/fdittgen-png/deskilo/releases) · [Roadmap](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+is%3Aopen+label%3Aepic)

## What your community can do

| Need | What DesKilo brings together |
|---|---|
| **Find and book a place** | Visual floor plans, live occupancy, reservations, recurring bookings, check-in/out, opening hours and closure rules. |
| **Manage membership fairly** | Membership plans, usage quotas, day packages, overage rules and per-member settings. |
| **Understand the money** | A ledger per member connecting subscription charges, extra usage, approved community expenses, recorded payments and statements. |
| **Share responsibility** | Roles, invitations, member confirmations and configurable approval quorums, with an event history of decisions. |
| **Prepare documents** | Invoices and corrections, VAT configuration, PDF statements and reports, and customizable document layouts. |
| **Run the space your way** | A floor-plan editor, workspace modules with declared dependencies, configuration import/export and multiple workspace profiles. |

For example, a member can reserve a desk, consume their allowance and see the resulting charges in their statement. When that member buys supplies for the space, an approved expense can credit their account. Administrators and members follow the same records and confirmation workflow.

Additional modules include a members directory, messaging, QR/NFC check-in and kiosk workflows, local reminders and push notifications. Availability depends on the workspace's configuration, device capabilities and connected services.

**Languages:** English · Français · Deutsch · Español · Italiano. UI translations and bundled in-app help are maintained in these five languages.

## Try it

Android is distributed through a **closed test**, and iPhone through **TestFlight**. The buttons above lead to those testing channels; access depends on tester enrollment and availability. Windows and macOS build and release workflows are also included; see [Releases](https://github.com/fdittgen-png/deskilo/releases) for published packages.

The **web app is the live application** and requires sign-in and workspace access. Its current *Demo mode* blurs selected displayed fields while continuing to use the connected workspace and allowing real actions. Evaluate it with a dedicated development workspace or your own test instance.

The [illustrated user guide](docs/wiki/User-Guide.md) lets you explore the workflows before setting up an account. The [setup questionnaire](https://fdittgen-png.github.io/deskilo/setup.html) helps a community prepare its booking, membership and governance rules.

## Current maturity

DesKilo has substantial implemented functionality and is being refined through dogfooding. It is best suited today to communities willing to run a pilot, verify their own workflows and contribute feedback. Public store releases, integration validation, usability and operational hardening remain active work.

Some capabilities need particular care when planning a pilot:

| Area | Current scope |
|---|---|
| **Membership and financial records** | The code includes billing rules, member ledgers, reconciliation, invoice history and database invariants. This is community management software; accounting acceptance needs validation for the operator's own use. |
| **Online payments** | Provider integration code exists for Stripe, PayPal, Mollie and Wero, including hosted checkout and webhook handling. CI runs the real order handler against a local provider stub; live provider reliability is still being validated. Confirm the complete payment and reconciliation flow with your provider before relying on it; recorded payments support pilots in the meantime. |
| **Electronic invoicing and accounting exports** | Structured invoice generation and export code is present. Real provider transmission and acceptance by accounting systems need validation for each intended setup; the project makes no certification claim. |
| **Deployment and recovery** | Instance tooling, migration checks and backup/restore procedures are provided. Running a community instance still requires someone responsible for configuration, upgrades and recovery. |

Follow the [open issues](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+is%3Aopen) and [latest quality-check runs](https://github.com/fdittgen-png/deskilo/actions/workflows/quality.yml) for the current state of work and validation.

## Your data and your instance

DesKilo's schema, access policies, server functions and client code are in this repository. A community can use its own hosted Supabase project or operate Supabase itself, and point the app at that backend through **Settings → Advanced → Server**.

The code includes workspace-scoped server permissions, personal-data export and deletion flows, and access-log features. Hosting location, access management, retention and backups depend on the operator's setup. These controls support privacy-conscious operation; compliance depends on how the instance is configured and used.

Store builds use Firebase Cloud Messaging for push notifications. A separate [FOSS build path](docs/guides/fdroid.md) excludes Google services. See the [privacy policy](https://fdittgen-png.github.io/deskilo/privacy.html) for the project's published data-handling information.

There is no software license fee. Hosting, payment processing and other external services may have their own costs.

## Run or develop your own deployment

A working deployment needs the **full Supabase backend**: PostgreSQL and migrations, Auth, Storage, Realtime and the required Edge Functions. Authentication redirects, service credentials and backups also need configuration.

1. Read the [instance guide](docs/wiki/Admin-Technical-Guide.md#instances) for the in-app wizard and command-line tooling. The reference deployment uses hosted Supabase; operating the Supabase platform itself is a separate infrastructure task.
2. Follow [Building & running](docs/wiki/Implementation.md#building--running) for the pinned Flutter setup, localization/code generation and platform build instructions.
3. Connect the client to your instance, configure the workspace, and follow the [operations guide](docs/guides/OPERATIONS.md) for health checks, backup, restore and upgrades.

For a local development backend, the repository supports the Supabase CLI workflow described in [Backend / migrations](docs/wiki/Implementation.md#backend--migrations). Review the [release guide](docs/guides/RELEASING.md) when distributing builds.

## Engineering approach

The client is organized by feature and uses **Flutter/Dart, Riverpod, Freezed, GoRouter and Material 3**. Supabase supplies Auth, PostgreSQL, Storage and Realtime; Edge Functions handle server-side integrations. A shared client keeps the mobile, browser and desktop experiences in one codebase, while platform capabilities and distribution still require their own validation.

PostgreSQL carries core authorization and consistency rules, including booking conflict protection and financial invariants. This gives concurrent clients a shared source of truth and makes the database part of the application that must be tested and upgraded with care.

The [quality workflow](.github/workflows/quality.yml) is configured to exercise:

- Flutter analysis, tests, localization checks and coverage;
- architecture, accessibility and security checks;
- migration replay onto a fresh database and PostgreSQL authorization/invariant tests;
- competing booking requests, financial reconciliation and webhook idempotency;
- a database backup/restore drill.

The [test inventory](docs/testing/TEST_INVENTORY.md), [domain invariants](docs/domain/INVARIANTS.md) and [architecture decisions](docs/decisions/) make that work inspectable. Check the latest CI run for actual results on the current commit.

## Documentation

| Start here | Contents |
|---|---|
| [Project wiki](https://github.com/fdittgen-png/deskilo/wiki) | Product, user and administrator documentation. |
| [User guide](docs/wiki/User-Guide.md) | Illustrated everyday workflows. |
| [Configuration guide](docs/wiki/Admin-Configuration-Guide.md) | Booking rules, memberships, roles and workspace settings. |
| [Technical admin guide](docs/wiki/Admin-Technical-Guide.md) | Reports, integrations and instances. |
| [Architecture](docs/wiki/Architecture.md) | Client structure, backend model and platform choices. |
| [Implementation](docs/wiki/Implementation.md) | Development setup, builds, testing and contribution patterns. |
| [Product specification](docs/SPECIFICATION.md) | Product intent and scope; consult issues and implementation for delivery status. |
| [Operations](docs/guides/OPERATIONS.md) | Instance health, backup, restore and recovery. |

## Contributing

Contributions are welcome in code, testing, translations, documentation and feedback from real coworking communities. Useful bug reports include the app version, platform, relevant workspace rules, reproduction steps and expected behavior, with personal information removed.

Development is issue-first, with focused pull requests, conventional commits and appropriate tests. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [project rules](docs/AGENT_RULES.md) before starting work.

DesKilo is a sibling project of [Sparkilo](https://github.com/fdittgen-png/tankstellen).

## License

[0BSD](LICENSE) © 2026 Florian DITTGEN
