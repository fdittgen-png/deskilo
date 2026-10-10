# Writing the user guide

The user guide is the in-app online help. It is written once per language as **chapter files**,
assembled into the five wiki guides, compiled into `assets/help/` for the app and rendered as a
static site. This page is the contract every chapter follows, so that the five languages read
as one coherent, consistent, harmonious guide.

```
docs/guide/user/NN-<slug>.<lang>.md   the chapters (the only hand-written source)
tool/guide_shots/shots/<chapter>.json  what to photograph for each chapter
docs/wiki/images/<id>.<lang>.b<build>.jpg   the screenshots (generated)
tool/build_user_guide.dart            chapters  -> docs/wiki/User-Guide.md (+ fr de es it)
tool/build_help.dart                  wiki      -> assets/help/<lang>.md   (the in-app help)
tool/guide_shots/capture.mjs          app build -> the screenshots
tool/guide_labels.dart                checks that every **bold label** is a label of the app
```

## Chapters

| file | audience | content |
|---|---|---|
| `01-start` | everyone | what DesKilo is, roles, three paths through the guide, account, account/membership/server/session, the demo, join/create/find a workspace, **Me** and my spaces, profiles, finding your way around, the setup questionnaire |
| `02-reserve` | members | the plan, the booking sheet, series, scan, check in/out, the calendar, saving a booking |
| `03-collaborate` | members, administrators | the members directory, events & confirmations, validation rules, messages, notifications, discover & the public network |
| `04-me-settings` | everyone | personal settings, language & formats, badge, privacy & your data, your own server |
| `05-money` | members, billing administrators | statement, payments, invoices, usage, finance alerts, price negotiation, submitting and approving an expense, the document library as a member |
| `06-owner-space` | owners | editor, workspace ID & QR, availability, features, workspace settings, wording & colours & branding, roles & co-owners, kiosk, badges, the document library, exports & import |
| `07-owner-people-billing` | owners, billing administrators | members & plans, the member's subscription, billing (fee bands, levels, packages, schedule), services & accessories, payment methods & provider, scheduled expenses |
| `08-owner-tax-invoicing` | owners, billing administrators | what the app issues and what stays outside (keep it current), VAT rates & declaration, legal identity & mentions, e-invoicing, report designer & invoice template, the invoicing workflow (month-close, settlement, shared expenses), payment reminders, accountant exports, business analytics |
| `09-advanced` | owners, operators | the two environments, deployment, assistants (MCP), the task recorder and guided tours, the demo workspace, platforms, troubleshooting, glossary |

## One section = one thing a person wants to do

Every `###` section follows this skeleton — same order, same bold words, in every chapter and language:

```markdown
<!-- anchor: user.reserve.plan -->
### Reserve a place on the plan

**Audience:** Member · Administrator · Owner

One or two sentences: the outcome, in the reader's words ("You want to…").

<p><img src="images/user-reserve-plan.en.jpg" width="280"></p>

**Steps**

1. Open [Reserve](app:/reserve) and pick the day at the top.
2. …

**Good to know**

- The rule that is easy to get wrong, or what happens if you do nothing.

**See also:** [Check in and out](help:user.reserve.check-in) · [Series](help:user.reserve.series)
```

Rules:

- **The anchor** is an HTML comment on the line above the heading, `user.<module>.<screen>[.<object>]`, lower case,
  never translated, identical in all five languages. The ids listed at the bottom already exist as help symbols in
  the app: they **must be kept** with exactly this id (the heading text is free, but see *Headings* below). New sections get new
  ids. Section = `###`; chapter = `##` (chapters carry their own anchor too, `user.<module>.overview`).
- **Audience line** — the second line of every section: `**Audience:**` followed by roles separated by ` · `.
  Roles: *Everyone* (all), *Member*, *Administrator*, *Owner*, *Co-owner*, *Billing administrator* (a role
  that holds the "issue invoices / view finances" permissions), *Operator* (who runs the installation). Use the
  role words of the language's table below, and the narrowest honest audience: a section about the plan editor is
  *Owner*, not *Everyone*. The label word per language: en **Audience** · fr **Public** · de **Zielgruppe** ·
  es **Público** · it **Destinatari**.
- **Lead** — plain words about the outcome, never about the mechanism; present tense, "you".
- **Image** — one per section where a screen explains it; `<p><img src="images/<id>.<lang>.jpg" width="280"></p>`.
  Write the *logical* name (no build part): the capture tool adds the build and rewrites the reference. Name = the
  anchor with dots turned into dashes (`user-reserve-plan`); a cut-out of one part is `<id>--<part>`. Never reference a
  file that is not produced by a shot in `tool/guide_shots/shots/`.
- **Steps** — numbered, one action each, verb first, the label exactly as the app shows it, in bold. Link the
  destination with an **app link** `[label](app:/route)` (a route of `lib/app/router.dart`): in the app it opens
  that screen, on the web it opens the live app.
- **Good to know** — at most four bullets: defaults, consequences, limits, permissions. Never an issue number, never
  "since version…", never an internal word (RPC, table, flag). Say *what happens*, not *how it is built*.
- **See also** — `help:` links to other sections (`[text](help:user.x.y)`): the in-app help jumps there, the wiki and the site
  turn them into heading links.
- Prefer prose a new person can follow over reference tables; use a table only for real reference (roles, states).
- Callouts are plain blockquotes that start with a bold word: `> **Tip** …`, `> **Careful** …`. Nothing else.
- Length: a section fits one phone screen of text plus its image. Split rather than scroll.

### Headings

The app's help symbols search the headings of the combined in-app guide for their topic word
(`helpTopic*` and tip topics in the ARB, e.g. *Calendar*, *Working hours*, *Booking policies*). Keep the screen's own name in
the heading (as the app writes it in that language) and `flutter test test/core/help test/lint/help_anchor_test.dart`
tells you if one is lost.

### Words come from the app

Every label you put in bold is a label the reader sees. Take them from `lib/l10n/app_<lang>.arb` (search by
English text, then read the same key in the other language) — never from memory, never translated freely.
`dart run tool/guide_labels.dart --lang <lang> docs/guide/user/<file>` lists the bold terms that are not an app label.
Facts come from the app's source (screens under `lib/features/*/presentation`, `WorkspacePermission`,
`WorkspaceFeature`, the booking rules) — if the app does not do it, the guide does not say it.

Role words per language:

| | Everyone | Member | Administrator | Owner | Co-owner | Billing administrator | Operator |
|---|---|---|---|---|---|---|---|
| en | Everyone | Member | Administrator | Owner | Co-owner | Billing administrator | Operator |
| fr | Tout le monde | Membre | Administrateur·rice | Propriétaire | Copropriétaire | Administrateur·rice facturation | Opérateur·rice |
| de | Alle | Mitglied | Administrator:in | Inhaber | Mitinhaber | Abrechnungsadministrator:in | Betreiber:in |
| es | Todos | Miembro | Administrador/a | Propietario | Copropietario | Administrador/a de facturación | Operador/a |
| it | Tutti | Membro | Amministratore | Proprietario | Comproprietario | Amministratore fatturazione | Operatore |

Tone: warm, direct, short sentences; the second person ("you" / « vous » / « Sie » / « usted » / « Lei »);
no jargon; no exclamation marks; the same scenario in every language, not a word-for-word translation but the same facts,
the same headings, the same anchors, the same image names, the same order.

## Screenshots

Every image is taken from a **built web app** in the **Demo workspace** (*Atelier du Marché* — Ada, Bruno, Chiara
and friends, all invented), **in the language of the guide**, so no real name, address or e-mail can appear.
`tool/guide_shots/capture.mjs` does it; see its header and `tool/guide_shots/README.md`. A shot lists the
persona (`owner`, `admin`, `member`), the view (`phone` default, `tablet`, `desktop`), the steps to get there and
the parts to cut out. Long forms are shot **whole** (the window grows until the form no longer scrolls) and the
guide shows the cut-outs (`parts`) that explain one object. Tips and *Get started* bubbles are clicked away and a
screen is only shot once it stopped loading.

```json
{"shots": [{
  "id": "user-reserve-plan", "persona": "member", "view": "phone",
  "shows": "the floor plan with free, reserved and blocked places",
  "steps": [{"hash": "#/reserve"}],
  "parts": [{"id": "legend", "from": "@planLegendFree", "to": "@planFloor"}]
}]}
```

Steps: `{"hash":"#/route"}` · `{"click":"@arbKey"}` or literal text · `{"at":[x,y]}` · `{"fill":["@label","text"]}` ·
`{"scroll":px}` · `{"press":"Escape"}` · `{"wait":ms}`. `@key` is an ARB key, resolved in the guide's language.
`"full": false` keeps the window size; `"clip": false` writes only the parts.
Run: `PW_DIR=<dir with playwright-core> node tool/guide_shots/capture.mjs --web <build/web> --lang en --chapter 02 --repo .`

The file name is `<id>[--<part>].<lang>.b<commit>.jpg`: the id (screen), the language and the build the shot was
taken from. Re-shooting from a newer build writes the new name, rewrites the guides and removes the old file;
`docs/wiki/images/_shots.json` records build, version and date of every image.

## Anchors to keep

#### `01-start` — anchors that must keep their id (old heading in parentheses)

- `user.profile.profiles` (Profiles)

#### `02-reserve` — anchors that must keep their id (old heading in parentheses)

- `user.reservations.booking-sheet` (The booking sheet)

#### `03-collaborate` — anchors that must keep their id (old heading in parentheses)

- `user.validation.overview` (Validation rules, domain by domain)
- `user.validation.required-count` (Required validations)
- `user.validation.who-may` (Who may validate)
- `user.validation.owner-required` (An owner is required)
- `user.validation.owner-self` (An owner may confirm their own request)
- `user.validation.sequential` (One after another)
- `user.validation.auto-validate-owner` (Auto-validate an owner's own request)
- `user.validation.auto-validate-admin` (Auto-validate an administrator's own request)

#### `04-me-settings` — anchors that must keep their id (old heading in parentheses)

- `user.profile.settings.whatsapp` (Your WhatsApp number)
- `user.profile.settings.status` (Your status line)
- `user.profile.settings.default-period` (Default booking period)
- `user.profile.settings.personal-info` (Personal information)
- `user.profile.settings.address` (Your address)
- `user.profile.settings.vat-id` (Your VAT number)
- `user.profile.settings.payment-terms` (Your payment terms)
- `user.profile.settings.restore-hints` (Restore the hints)
- `user.profile.settings.badge` (Your badge)
- `user.profile.settings.badge-pin` (Your badge PIN)
- `user.profile.settings.language` (App language)
- `user.profile.settings.theme` (Theme)
- `user.profile.settings.navigation` (Navigation style)
- `user.profile.settings.front-camera` (Front camera for scanning)
- `user.profile.settings.regional-formats` (Numbers and dates)
- `user.profile.settings.clock` (Clock)
- `user.profile.settings.device-zone` (Show times in my time zone)
- `user.backend.server` (Your own server)
- `user.backend.how` (How to run your own)
- `user.privacy.visibility` (Who can see my data)
- `user.privacy.export` (Export my data)
- `user.privacy.erase` (Erase my data)
- `user.privacy.consent` (Your data, your rights)

#### `05-money` — anchors that must keep their id (old heading in parentheses)

_none — all ids are new_

#### `06-owner-space` — anchors that must keep their id (old heading in parentheses)

- `user.workspace.code` (The workspace ID)
- `user.workspace.availability.open-weekdays` (Open weekdays)
- `user.workspace.availability.granularity` (Granularity)
- `user.workspace.availability.working-hours` (Working hours)
- `user.workspace.availability.closure-days` (Closure days)
- `user.workspace.availability.policies` (Booking policies)
- `user.workspace.availability.allow-past` (Allow past bookings)
- `user.workspace.availability.admin-checkout` (Administrators may check out)
- `user.workspace.availability.outside-hours` (Outside the opening hours)
- `user.workspace.availability.limits` (Booking limits)
- `user.features.switch` (A feature switch)
- `user.workspace.settings.country` (Country)
- `user.workspace.settings.currency-timezone` (Currency and time zone)
- `user.workspace.settings.language` (Workspace language)
- `user.workspace.settings.address` (Letterhead address)
- `user.workspace.settings.whatsapp-group` (WhatsApp group)
- `user.workspace.settings.invitation-message` (Invitation message)
- `user.workspace.settings.wording` (Wording)
- `user.workspace.settings.colours` (Colours)
- `user.workspace.settings.desk-transparency` (Desk transparency)
- `user.workspace.export.space-xml` (Export the space (XML))
- `user.workspace.export.space-import` (Import the space (XML))
- `user.workspace.export.config-pdf` (Export the configuration (PDF))
- `user.workspace.export.workspace-report` (Workspace report)
- `user.workspace.export.space-qr` (Space QR codes (PDF))
- `user.workspace.export.excel` (Export the data (Excel))
- `user.roles.matrix` (The role matrix)
- `user.badges.nfc` (NFC badge check-in)
- `user.documents.title` (Document title)
- `user.documents.url` (Link)
- `user.documents.provider` (Stored on)
- `user.documents.category` (Category)
- `user.documents.role` (Visible to)

#### `07-owner-people-billing` — anchors that must keep their id (old heading in parentheses)

- `user.members.subscription` (A member's subscription)
- `user.members.overage-policy` (When days run out)
- `user.members.reservation-limit` (Reservation limit)
- `user.members.simultaneous` (Simultaneous reservations)
- `user.members.vat-treatment` (VAT treatment)
- `user.members.negotiation` (Price negotiation)
- `user.members.co-ownership` (Co-ownership)
- `user.members.actions` (The member's actions)
- `user.money.billing.fee-bands` (Fee bands)
- `user.money.billing.band-to` (Up to %)
- `user.money.billing.band-fee` (Monthly fee)
- `user.money.billing.band-overage` (Overage)
- `user.money.billing.levels` (Subscription levels)
- `user.money.billing.level-value` (Level value)
- `user.money.billing.custom-level` (Allow a negotiated value)
- `user.money.billing.packages` (Day packages)
- `user.money.billing.package-new` (New package)
- `user.money.billing.package-name` (Package name)
- `user.money.billing.package-days` (Package days)
- `user.money.billing.package-price` (Package price)
- `user.money.billing.schedule` (Invoice schedule)
- `user.money.services.overview` (A service)
- `user.money.services.name` (Service name)
- `user.money.services.price` (Service price)
- `user.money.services.active` (Active)
- `user.money.payments.provider` (The payment provider)
- `user.money.payments.credentials` (Provider credentials)
- `user.money.payments.methods` (Payment methods)
- `user.money.expenses.schedule` (A scheduled expense)
- `user.money.expenses.what` (What)
- `user.money.expenses.amount` (Amount)
- `user.money.expenses.description` (Description)
- `user.money.expenses.starts-on` (First occurrence)
- `user.money.expenses.every` (Every)
- `user.money.expenses.times` (Number of times)
- `user.money.expenses.ends-on` (Until)

#### `08-owner-tax-invoicing` — anchors that must keep their id (old heading in parentheses)

- `user.money.vat.rates` (Setting the rates)
- `user.money.vat.declaration` (The periodic VAT declaration)
- `user.money.legal.seller-kind` (Organisation type)
- `user.money.legal.legal-form` (Legal form and capital)
- `user.money.legal.registration` (Trade register)
- `user.money.legal.payment-terms` (Payment terms)
- `user.money.legal.late-penalty` (Late-payment penalty)
- `user.money.legal.recovery` (Recovery indemnity)
- `user.money.legal.escompte` (Early-payment discount)
- `user.money.legal.insurance` (Professional insurance)
- `user.money.legal.special-mentions` (Special mentions)
- `user.money.vat.regime` (VAT regime)
- `user.money.vat.number` (VAT number)
- `user.money.vat.account` (VAT account)
- `user.money.vat.exemption-reason` (Reason no VAT is charged)
- `user.money.legal.legal-id` (Company registration number)
- `user.money.legal.address` (Structured address)
- `user.money.einvoice.overview` (The e-invoicing platform)
- `user.money.einvoice.endpoint` (Upload URL)
- `user.money.einvoice.token` (Token or credential)
- `user.money.einvoice.auth-header` (Auth header)
- `user.money.einvoice.file-field` (File field name)
- `user.money.einvoice.uat` (UAT endpoint and token)
- `user.money.einvoice.dev` (Dev endpoint and token)
- `user.money.reports.invoice-template` (The invoice PDF template)
- `user.money.reports.editor` (The report editor)
- `user.money.vat.groups` (VAT groups (#947))
- `user.money.reminders.rules` (Reminder rules)
- `user.money.reminders.automatic` (Automatic reminders)

#### `09-advanced` — anchors that must keep their id (old heading in parentheses)

_none — all ids are new_

## The setup guide (`docs/guide/setup`)

A second guide of the same kind, for the person who is about to **build** a space: what is possible, what is
necessary, in which order, how to do it, and how not to contradict yourself. Same contract as above (skeleton,
audience line, words from the app, five languages identical in structure, screenshots from the demo workspace
in the language of the guide), with these differences:

- Chapter files `docs/guide/setup/NN-<slug>.<lang>.md`, anchors `setup.<chapter>.<topic>` (chapter heading
  `setup.<chapter>.overview`), assembled into `docs/wiki/Setup-Guide.md` (+ `Guide-de-demarrage`,
  `Einrichtungsanleitung`, `Guia-de-puesta-en-marcha`, `Guida-di-avvio`), compiled into the in-app help after the
  user guide and rendered as the second book of the site (`setup-<lang>.html`).
- **It explains the *why*, the *order* and the *consequences*; the user guide explains the clicks.** For every
  how-to-click detail, link the user guide: `[Working hours](help:user.workspace.availability.working-hours)`
  (any `user.*` anchor may be linked; the assembler resolves it across the two guides).
- Section skeleton: the same, with these labelled parts used where they help: **Before you start**, **Steps**,
  **Good to know**, **Result**, **See also**. Add, where a choice exists, a small table *Option · Choose it when ·
  What happens* (real options of the app only).
- A marker for hard-to-undo decisions: a blockquote starting `> **Careful**` that says *what* becomes permanent
  and *when* (e.g. "after the first issued invoice"). Cite only what the code does (see
  `docs/design/owner-setup-research.md`; if a fact is marked there as a doubt, say "check with the owner of the
  installation" or leave it out).
- Roles: sections are for the **Owner** (and *Co-owner*, *Administrator*, *Billing administrator*, *Operator* where
  they act). The tone is a calm mentor's: short, concrete, with one worked example per chapter (the demo
  workspace *Atelier du Marché* and its figures are the running example).
- Legal and tax statements: describe what the app does and which choices the owner confirms with an accountant;
  never certify anything; the app issues invoices in France and Germany only today.
- Screenshots: same runner and spec format. The setup wizard page of the build can be photographed too:
  `{"id": "setup-wizard-identity", "url": "/setup.html?lang={lang}", "view": "phone", "steps": [{"css": "…"}], …}`
  (steps `css`, `eval` and the usual ones; no demo is entered for a `url` shot). Prefer cut-outs (`parts`) that show
  one decision.
- Where a fact differs between the old documents and the code, the code wins; mention nothing you cannot find in
  the code or in `docs/design/owner-setup-research.md`.
