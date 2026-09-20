<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Settings, by whose setting it is

#1307 S1. **Every tile the Settings screen shows today, classified by who
owns the value behind it, with the one screen that edits it.** The regroup
(S3) builds the screen from this table; a tile added later is added here
first.

Verified against master after #1407 (the Advanced section extracted),
2026-09-16. Sources: `lib/features/profile/presentation/screens/settings_screen.dart`,
`widgets/settings_advanced_section.dart`, `widgets/settings_about_section.dart`.
Where a value lives and whether a template may carry it comes from
[`docs/domain/CONFIGURATION_MATRIX.md`](../domain/CONFIGURATION_MATRIX.md)
(#1290): class **D** is never carried, class **B** is.

## The scopes

| scope | the question it answers | edited by | a template may carry it |
|---|---|---|---|
| **My account** | who I am, how the app looks and speaks to me — on every workspace | me | never (D) |
| **My membership** | my standing in *this* workspace | me | never (D/E) |
| **This workspace** | how this space works | holders of the named permission | when the matrix says B |
| **Administration** | running the people and devices of this space | holders of the named permission | only template-safe configuration |
| **Governance** | what the space *is*: environment, deployment, roles | owner, or the explicit permission | no |
| **Advanced** | this device and diagnostics | the device's user; dev tools behind their switch | never |
| **Help & about** | help, privacy, the app itself, sign out | everyone | — |

Gating is by the **permission matrix** (`myPermissionsProvider`, which
already resolves owners to every permission), never by
`isOwner || canAdminister`. Hiding a tile is usability; the server stays the
authority (RLS, `has_permission`).

## Every tile today

"Today's gate" is what the code checks at the time of writing; "target gate"
is what S3 renders from. A tile whose two gates differ is a behaviour
change and is listed again under *Changes S3 makes*.

### My account

| tile | key / route | canonical editor | today's gate | target gate |
|---|---|---|---|---|
| Profiles (switch workspace) | `/profiles` | `profiles_screen.dart` | always | always |
| Photo | `settings-photo` · sheet | photo sheet | a profile exists | same |
| Personal information | `settings-personal-info` · `/settings/personal-info` | `PersonalInfoForm` (the ONE identity form) | `personalInfo` flag | same |
| Address | `settings-address` · dialog | address dialog (when `personalInfo` is off) | `!personalInfo` | same |
| WhatsApp number | dialog | WhatsApp dialog | `whatsappIntegration` flag | same |
| Regional formats | `RegionalFormatsTile` · `/formats` | `formats` screen — `profiles.format_locale / clock / time_zone_mode` | `regionalFormats` flag | same |
| Linked accounts | `settings-linked-accounts` · `/linked-accounts` | linked accounts screen | always | same |
| My badge / badge PIN | `MyBadgeTile`, `BadgePinTile` | the two tiles | active, not a kiosk | same — membership-scoped data, account-shaped control; stays here |
| Language | dialog | `profiles.preferred_locale` + device override | always | **pinned** (see essentials) |
| Theme | dialog | device preference | always | same |
| Navigation style | `settings-navigation` · dialog | personal preference | not on web | same |
| Front camera for scans | `settings-front-camera` | device preference | always | moves to **Advanced** (device) |
| Show help hints again | `settings-restore-hints` | help-hint store (device) | some hint dismissed | same |

### My membership

| tile | key / route | canonical editor | today's gate | target gate |
|---|---|---|---|---|
| Status (present / away…) | dialog | status dialog | always | same |
| Default booking period | `settings-default-period` · dialog | device preference **keyed by workspace** (`PrefsDefaultPeriodStore`) | the workspace offers more than one period | same |
| Payment conditions (read-only) | `settings-payment-terms` · `/settings/payment-terms` | read-only page; changes through validation (#881) | member + `memberPaymentTerms` | same |
| Documents | `settings-documents` · `/documents` | document library | `documents` flag | same |
| Kiosk device (revert) | `settings-kiosk-revert` | revert action | the member is a kiosk | same |
| Members (directory) | `/directory` | — | `membersDirectory` flag | **removed**: Members is a bottom-bar destination (#1306); a second door is a duplicate |

### This workspace

Groups use #1276's vocabulary, the words the template preview shows.

| tile | route | canonical editor | group | today's gate | target gate |
|---|---|---|---|---|---|
| Workspace | `/workspace-settings` | `workspace_settings_screen.dart` — identity, locale, invite template | space | `workspaceSettings` | same |
| Availability | `/availability` | `availability_screen.dart` — hours, closures, booking rules | hours & booking | `workspaceSettings` | same |
| Billing | `/billing` | `billing_screen.dart` — fee bands, packages, subscription levels | pricing & credits | `manageBilling` | same |
| Number sequences | `settings-number-sequences` · `/settings/number-sequences` | number sequences screen | documents & operations | `manageBilling` + flag (in Advanced today) | moves here from Advanced |
| Services | `/services` | services screen | pricing & credits | `manageServices` + `services` | same |
| Accessories | `/accessories` | accessories screen | pricing & credits | `canAdminister` + `accessorySupplements` | **`manageServices`** + flag |
| Payment instructions | `settings-payment-methods` · `/payment-methods` | payment instructions | documents & operations | `manageIntegrations` | same |
| Billing & reports | `settings-billing-reports` · `/invoices` | invoicing hub + report designer | documents & operations | `showAdminSection` + `invoicing` | **`viewFinances`** + `invoicing` |
| Validation rules | `/validation` | validation settings | roles & access | `manageValidation` | same |
| Features | `/features` | features screen (#1327 process overview) | calendar & navigation | `manageConfiguration` | same |
| Wording | `/settings/wording` | wording editor (#1277) | wording | reached from Workspace today | same |

### Administration

| tile | route | canonical editor | today's gate | target gate |
|---|---|---|---|---|
| Members & plans | `/members` | `members_screen.dart` | `showAdminSection` | **`manageMembers`** |
| Online payments | `/payment-config` | payment provider config | `manageIntegrations` + `onlinePayments` | same |
| RFID / NFC badges | `/nfc-config` | NFC config | `operateKiosk` + `nfcBadges` | same |
| Sites | `settings-sites` · `/settings/sites` | sites screen | `manageSites` + `multiSite` (in Advanced today) | moves here from Advanced |
| Workspace ID & QR | `/workspace-code` | workspace code screen | `manageConfiguration` | same |

### Governance

| tile | route | canonical editor | today's gate | target gate |
|---|---|---|---|---|
| Role management | `settings-roles` · `/roles` | roles screen — whoever holds any permission reads the matrix, `manageRoles` edits it (#513) | `showAdminSection` + `roleManagement` | **holds any permission** + flag |
| Deployment | `settings-deployment` · `/deployment` | deployment screen | `showAdminSection` + `deployments` + `deployToDev` + a pair | same minus `showAdminSection` (the permission already implies it) |
| Environment (dev / prod) | `WorkspaceEnvironmentTile` | the tile; owner-only by `set_workspace_environment` | owner (in Advanced today) | moves here from Advanced; still owner-only |

### Advanced — this device

| tile | route | canonical editor | today's gate | target gate |
|---|---|---|---|---|
| Server | `BackendSettingsTile` · `/server` | `backend_screen.dart` — per device, applied at next start (#780) | always | same — device and instance scope, never a workspace group (#1309) |
| Push state | `PushStatusTile` | read-only | always | same |
| Front camera for scans | `settings-front-camera` | device preference | (My account today) | here |
| Developer mode | switch | `workspace/application/set_workspace_dev_mode.dart` | `canAdminister` | same |
| Developer | `/developer` | developer screen | developer mode on | same |
| Demo mode | `settings-demo-mode` | demo store | `demoMode` flag | same until #1372 replaces it |

### Help & about

| tile | route | today's gate | target gate |
|---|---|---|---|
| Help | `settings-help` · `/help` | always | **pinned** |
| Version, author, source, privacy policy, issues, donations | `about-*` | always | privacy **pinned** |
| Sign out | — | always | **pinned** |

## The four essentials

Whatever else a workspace hides, these four stay on a plain member's
Settings, pinned by key in the S3 test: **Sign out**, **Language**,
**Privacy policy**, **Help**.

The association's report asked for *«ne pas donner accès à Réglages»*. It is
read as *no administration clutter for members*: a plain member sees **My
account**, **My membership** and **Help & about** — never an empty
Settings. If the responsable meant it literally, that is a new decision,
recorded in #1307.

## Changes S3 makes

Behaviour, not only order:

1. **Members (directory) leaves Settings** — it is a bottom-bar destination.
2. **Accessories** asks `manageServices` instead of `canAdminister`.
3. **Billing & reports** asks `viewFinances` instead of "owner or admin".
4. **Members & plans** asks `manageMembers` instead of "owner or admin".
5. **Role management** appears for whoever holds any permission — the
   rule the roles screen itself states (#513: any permission reads,
   `manageRoles` edits). Today a delegate who is not owner or admin holds
   permissions and cannot find the matrix that grants them. The screen's
   edit gate is unchanged.
6. **Sites, number sequences, environment** move out of Advanced into the
   workspace groups they configure; Advanced keeps only the device and
   diagnostics.
7. **Front camera** moves to Advanced: it is a device preference.

## Not in S3

- **Provenance chips and resets** (*Product default · From template ·
  Workspace setting*) — S4, after #1276 records template applications.
- **A configurable landing destination** — classified in #1290, not built.
