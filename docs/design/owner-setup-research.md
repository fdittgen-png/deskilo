<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Owner setup: research note (facts for the wizard redesign and the owner guide)

Read-only survey of the repository at `/private/tmp/deskilo-userguide`, 2026-10-09. Every claim cites a path
(line numbers where useful). "Verified" means read in code; "doubt" means not settled (section 7).
Migrations are numbered up to 0397.

---------------------------------------------------------------------------------------------------

## 1. The current wizard (`web/setup.html`)

### 1.1 Files and plumbing
- `web/setup.html` (1171 lines): one static page, no build step, no backend, vanilla JS. State object `S`
  (`DEFAULTS`, l.380-401), persisted in `localStorage` key `deskilo-setup-v1` (l.127, `save()` l.428). Also
  stores `-step`, `-mode`, `-lang` keys. Nothing is sent anywhere. `Reset` removes the keys (footer, l.120).
- `web/setup_catalogue.js` (285 lines, GENERATED): `window.SETUP_PROCESSES`, the 9 business processes with
  subprocesses and feature keys. Source: `lib/features/workspace/domain/workspace_process.dart`.
- `web/setup_l10n.js` (6515 lines, GENERATED) by `tool/build_setup_l10n.dart`. Two sources: the app ARB
  (`lib/l10n/app_<locale>.arb`) for feature/permission/validation-domain/country names and descriptions
  (via the `WorkspaceFeature.x => l10n?.key` getters in `feature_names.dart` / `feature_copy.dart`), and
  `web/setup_l10n/setup_{en,fr,de,es,it}.json` (584 keys) for the page's own prose.
- Five languages: `LOCALES=['en','fr','de','es','it']` (l.137). Picked from `?lang=`, then stored choice, then
  `navigator.language`, then English (`pickLocale`, l.141). Language changes what the page SAYS, never what it
  EXPORTS (comment l.131-135; `tool/setup/step_harness.mjs` proves byte-identical XML in 5 locales).
- Gates: `test/lint/setup_html_test.dart` (every `WorkspaceFeature` present, default equals
  `defaultFeatureFlagsForNewWorkspace()`, `REQUIRES` equals `featureManifest.requires`),
  `test/lint/setup_l10n_test.dart` (drift, key parity), `test/lint/setup_runs_test.dart` +
  `tool/setup/step_harness.mjs` (every step builds without throwing, per locale),
  `test/features/workspace/setup_page_contract_test.dart` (app parser accepts what the page emits).
  Rules in `docs/AGENT_RULES.md` l.174-215 ("no exceptions", same PR as any parameter).

### 1.2 Steps, in order (`STEPS`, l.585-921)
12 steps. Step rail with status dots (ok/warn/err/n.a.), a progress bar, "Step n of N", an "expert mode"
checkbox showing all steps on one page (l.112, `setMode`). `?step=<id>&mode=all` deep-links (l.926).

| # | id | What it asks | Applies only if |
|---|---|---|---|
| 1 | identity | name, environment (dev/prod), country (sets currency+time zone), currency, time zone, default language, address, brand colour (#RRGGBB) | always |
| 2 | features | 126 on/off switches grouped in 9 process cards + subprocess subheads; children indented; ticking a child ticks its parents ("also enables" note) | always |
| 3 | availability | open weekdays, booking granularity (8 options; only half/full day unless `workingHours`), day start/boundary/end, hour equivalents, closure dates, booking policies (past bookings, admin check-out, outside-hours mode x4, legend profile, simultaneous), horizon/min/max duration, collapsible behaviour matrix | always (policies need `bookingPolicies`) |
| 4 | plan | levels > offices > desks > seats (counts + seat prefix), desk opacity, whole-space bookable flags + price (needs `levelBooking`), sites (needs `multiSite`) | always |
| 5 | billing ("Subscriptions") | fee bands (from%/to%/fee/overage), subscription levels 25/50/75/80/100, free level, day packages | `moneyTab` |
| 6 | legal | association/company, customer capacity, VAT regime (3), registration no., VAT id, exemption reason, VAT rates (+ country suggestion button), exigibility, invoice + member numbering, VAT period, billing address, 8 invoice mentions, dunning levels/delays/auto, e-invoice platform URL/token/header/field + UAT/dev + customer service (EU only) | `invoicing` |
| 7 | services | services (name/price/VAT), accessory supplements | `services` or `accessorySupplements` |
| 8 | pay | bank scheme by country (SEPA IBAN/BIC; UK; US; CA), PayPal.me, Wero, Lydia, Wise, reference | `moneyTab` |
| 9 | roles | permission matrix for co_owner/admin/member (21 permissions), default validation rule, per-domain rules (21 domains), who validates (scope), auto-validate for reservation deletion | always |
| 10 | members | member rows (name, e-mail, role, subscription %, overage policy, whole-space, simultaneous, limit), invitation text per language, WhatsApp group link | always |
| 11 | summary | every active feature with its configured value, un-tick to switch off, inactive list | always |
| 12 | review | findings per step (ok/warn/err), per-process roll-up, the gate, Export XML | always |

Each step has `why` prose (e.g. `identityWhy`: "The name, the country and the currency decide everything that
follows"), `check()` findings, and `applies()`. Order comment: "a later step only reads answers from earlier
ones" (l.582).

### 1.3 Required-field logic and review
- `REQ` (l.528-539): name, seller street/postal/city always; `vatId` if regime not "not_subject"; `regNumber`
  if company. Field shows a "Required" badge + reason + jump link; same source feeds step dot and export gate.
- `findings()` (l.922) concatenates `check()` of applicable steps. Export is GATED: `exportChecked()` (l.977)
  refuses while any `err` finding exists and jumps to review. Typical errs: no name, bad brand colour, no seats,
  no weekdays, start>=end, boundary outside, min>max, tier gaps / not covering 0-100 %, subscription level not
  covered by a band, missing address/VAT id/VAT rates, invalid IBAN shape, dunning <1, bad e-mail, duplicate
  member e-mail, member level not in offered levels. Warnings: no registration no., no exemption reason,
  `onlinePayments` on, kiosk without badge type, e-invoice URL without token, validators required > possible.

### 1.4 Dependency (REQUIRES) rules
- `REQUIRES` (l.435): 59 child->parent entries, hand-copied from `featureManifest` and pinned by test.
  `on(k)` walks the chain (l.437); `enableWith` ticks the chain (#800); un-ticking a parent leaves child choices
  stored but effective-off (same as `effectiveFeatures`, `workspace_feature.dart` ~l.1352).
- Several steps show "This question is hidden because ..." boxes (`needs()`, `dep()`) linking back to step 2.

### 1.5 Storage and export
- Browser-only (`localStorage`). "Load file" re-reads a previous export (`parseBack`, l.1134), merging onto
  defaults for backward compatibility.
- `exportXml()` (l.1047) writes `deskilo-workspace version="3"`:
  - `<settings name country currency timezone environment brand-color>` with one `<feature key enabled>` per
    feature (126) and `<payment-instruction>`;
  - `<accessories>`; `<floor-plan>` (auto-laid-out levels/offices/desks/seats, fixed grid geometry);
  - `<configuration>` (typed tree, schema v3) ONLY IF the page's `configurationTransfer` switch is on (l.1084);
  - `<setup>` extension (availability, identity, billing, services, legal incl. numbering/mentions/e-invoice
    tokens/reminders/VAT declaration/sites, roles, validation domains, members).
- What the app's importer consumes (Settings -> Workspace settings -> import; `_importXml`,
  `lib/features/workspace/presentation/screens/workspace_settings_screen.dart` l.706-923):
  1. `parseWorkspaceXml` (`lib/features/workspace/domain/workspace_xml.dart`, versions 1,2,3 accepted) reads
     settings, accessories, floor plan, and `<configuration>`; `<setup>` is IGNORED by design
     (`test/features/workspace/setup_page_contract_test.dart` l.3-7).
  2. Plan is validated client-side (editor placement rules), then a destructive confirm dialog: "The current
     floor plan will be deleted and replaced, and the workspace settings will be overwritten. This cannot be
     undone."
  3. `<configuration>` is applied only `if` the TARGET workspace already has `configurationTransfer` effective
     (l.761-764), through RPC `import_workspace_configuration` (migration 0177), BEFORE the plan; never refused
     over reservations.
  4. Floor plan replaced via `import_floor_plan_v3`; refused by the server when reservations exist
     (`kWorkspaceHasReservationsError`); with configuration applied this degrades to "plan kept".
  5. Then country/currency/timezone (`updateWorkspaceLocale`, direct row update), payment instructions, feature
     flags (`setFeatureFlags` full map), brand colour (measured first; refused if unreadable).
  6. Workspace NAME is "deliberately skipped" (comment l.862-863); `environment` attribute is not read by the
     importer (grep: no use in the screen or `workspace_xml.dart` beyond the model).
- What actually reaches the app (from `configurationTree()`, l.995-1046): address/street/postal/city, default
  locale, whatsapp group, desk opacity, invitation templates, VAT regime/id/legal id/exemption, `booking_rules`
  (granularity, weekdays, horizon, durations, work hours, half/full-day hours, policies), subscription levels
  (presets), invoice_legal (mentions, seller kind, capacity, exigibility), dunning rules, fee bands, packages,
  closure days, validation policies (per-domain only), services, VAT rates, sites.
- What only lives in `<setup>` and therefore never reaches the app by import: roles/permission matrix, the
  default validation rule (null event type), members list, invoice and member NUMBER SEQUENCES, VAT declaration
  period, e-invoice URLs/tokens, WhatsApp via `<setup>` copy, whole-space prices and level `bookable` flag (the
  plan export writes only `bookable-as-whole` on offices; prices are not emitted at all, l.1070).
  The guide says the file "creates the settings, accessories and floor plan"
  (`docs/wiki/User-Guide.md` l.388-395), which is accurate; the per-page intro (`setupIntroHtml`) says "the
  `<setup>` section of the same file carries everything else" without saying nothing reads it.

### 1.6 Feature summary and help links
- Summary step (l.822): per active feature a plain-language "Configured: ..." sentence from `cfg` map (about 65
  entries); features without an entry show only name+description. Un-ticking there switches the feature off.
- Help: `HELP` map (l.451-490) maps ~35 keys to `[app location string, GitHub wiki anchor]`; `?` icons beside
  fields; `FEATURE_HELP`; each step has `STEP_HELP`. All link to
  `https://github.com/fdittgen-png/deskilo/wiki/User-Guide#...` (`WIKI`, l.450); the guide link in the header
  uses `GUIDE_URL` (l.172). Doc lint checks the anchors (`doc-check` skill; `test/lint/help_anchor_test.dart`).

### 1.7 UX weaknesses for someone who knows nothing (judged from structure and strings)
1. Features come at step 2, before the person knows what the product does. 126 switches in 9 cards, with
   jargon names ("Technical", "decisionSurface", "validationScopes"). The default is "Core" (45 on) but the page
   never explains Core vs Platform tiers (`FeatureTier`, `workspace_feature.dart` l.411-418).
2. No scenario or template. The app has builtin templates (`association_fr`, `tiny`) and a template picker in
   onboarding (`onboarding_screen.dart`), but the wizard does not use or mention them. No "I run X" starting
   point, no examples, no sample values (placeholders only for brand colour, IBAN-ish fields).
3. Jargon without a glossary: "granularity", "half-day boundary", "overage", "exigibility/VAT falls due",
   "customer capacity", "journal", "date part/reset", "quota", "validation domain", "scope", "e-invoice
   EN 16931/Peppol", "UAT". Explanations exist as hints but are long (e.g. `availOutsideHoursHint`) and
   undefined terms stay undefined.
4. Money/legal steps assume the owner already has a tariff, a VAT status, registration numbers and an
   accountant. No "what is this for / what if I do not know / safe default" path; "Skipping costs nothing"
   (User-Guide) hides that several choices are hard to undo (section 6).
5. Order mixes concerns: availability and plan before billing is fine, but roles and members come last while
   the validation rule warns about validators who are only created in the next step.
6. No preview: the floor plan is a table (no drawing), no sample invoice, no sample member screen, no
   "what the member will see".
7. Progress: a bar and dots exist, but no time estimate, no "essential vs optional" marking, 3 of 12 steps
   conditionally disappear, which makes "Step n of N" change under the user.
8. The import contract is opaque: it says "Import workspace" creates a workspace, but the import REPLACES the
   plan, ignores name and environment, and applies the configuration only if `configurationTransfer` is
   already on in the target (default off, Platform tier, requires `dataExport`). A newcomer will not know to
   switch it on first. The wizard's own default for that switch is off (`FEATURES`, l.294).
9. Several answers are collected but never stored by the app (list in 1.5); roles/members/numbering must be
   re-entered in the app. The page does not say which answers are "kept in the file only".
10. Secrets: warns once in the header (`setupSecretsHtml`) but still provides token fields in the form.
11. Permissions list is 21 of 31 (`PERMS`, l.318; missing `deployToProd`, `deployToDev`, `accessProd`,
    `viewAnalytics`, `useMessages`, `makeReservations`, `viewCalendar`, `viewDirectory`, `viewMyMoney`,
    `viewDocuments`, which are in `workspace_permission.dart`).
12. Consistency checks cover only intra-page logic (tiers, dates, required text); they know nothing about the
    server's issuing refusals (section 3).

---------------------------------------------------------------------------------------------------

## 2. What an owner can configure, and in what order it matters

### 2.1 Features (`lib/features/workspace/domain/workspace_feature.dart`)
- 126 enum values; manifest `featureManifest` (l.459+) with `tier` (core 30 / platform 63 per the manifest
  entries parsed; the exact split of the 126 in the wizard is 45 default-on), `surface`, `defaultOn`,
  optional `requires` (single parent). 59 child links. Parent chain resolved by `effectiveFeatures`,
  `requirementChain`, `dependentFeatures`, `featureFlagsAfterToggle` (turning a child on turns its chain on).
- New workspace flags: `defaultFeatureFlagsForNewWorkspace()` (l.1629): every key written explicitly;
  `core && defaultOn` true, everything else false; `environmentPairs` forced on when a twin is created.
  Existing workspaces never change (#1063).
- Stored in `workspaces.feature_flags`; missing key = registry default (`resolveEnabledFeatures`).
- Switch behaviour: off stops NEW business only (`FeatureOperation.acceptNew/serviceExisting/suspended`,
  `feature_operation.dart`; server `feature_operation_allowed` 0324). Switching off deletes nothing
  (`featuresWhy`).
- Lifecycle/maturity: `feature_lifecycle.dart` (`FeatureMaturity` unreviewed/alpha/beta/stable;
  `FeatureLifecycle` active/deprecated/retired); in code 0 `stable`, 11 `beta` assessments, the rest
  unreviewed; evidence from `docs/product/capabilities.json`. Switching on an experimental feature asks for
  consent (`feature_switch_flow.dart`).

### 2.2 Processes (`workspace_process.dart`, generated `docs/design/process-catalogue.md`)
9 processes, 22 subprocesses: workspaceAccess (people, physicalAccess), spaceManagement (structure,
availability, presentation), reservationsUsage (reservations, attendance), coordination (calendar, decisions,
communication), membershipCommerce (pricing), billingPayments (records, invoicing, collection, expenses, tax),
documentsInformation (documents, reportDesign, privacy), operations (configuration, experience), integrations
(delivery). One business home per feature; `internalCapabilities` has one reserved flag (`siteDocuments`,
no implementation). Gate: `test/lint/process_registry_test.dart` (generated catalogue equals registry).

### 2.3 Templates
- Table `workspace_templates` (0196, library 0199, snapshots 0229, publication 0231, preview/inspection
  0266, exact apply 0282, search 0283, publish-once 0286). Visibility builtin/private/shared/public.
- Builtins: `tiny` (floor plan only, 0196) and `association_fr` (0233, revised 0257): identity defaults,
  tariffs (fee bands, 50 %/100 % levels), credit products (carnets), floor plan (two levels), booking rules
  (half-day, 07:00/13:00/19:00, Mon-Fri, horizon 90 d), closure-day marker (holidays resolved per target),
  lexicon overrides, custom roles (tresorier, secretaire, referent_salle), and a `feature_profile`
  (`base core` + on/off lists, expanded to all flags by `tool/build_builtin_templates.dart`,
  `template_feature_profile.dart`). Reviewable source `supabase/templates/*.json`
  (`supabase/templates/README.md`). Owner-private variants under `supabase/templates/variants/`.
- A template NEVER carries: identity (address, VAT, legal id), payment instructions, sites, invitations,
  document links/design (`_denied` and `_strippedIdentityKeys` in `test/lint/template_contract_test.dart`
  l.52-70). Local needs are named, not guessed: `template_local_slot_catalogue()` (0280): legal_identity
  (required), payment_details (recommended), payment_provider (`onlinePayments`), einvoice_platform
  (`einvoiceCustomerDelivery`), site (`multiSite`).
- Apply is group-based with a change preview; the app creates a workspace from a template in onboarding
  ("Start from", "Sets up: ...", "Empty space"; `onboarding_screen.dart`, ARB keys `onboarding*`).
- Field registry: `template_field_registry.dart` + SQL (`template_field_registry_sql.dart`), gated by
  `test/lint/template_coverage_test.dart` (#1655, "nothing a template could carry stays without a
  disposition") and `config_reachable_test.dart` (#807, every config field named in a presentation file).
  `docs/domain/CONFIGURATION_MATRIX.md` classifies every setting A-F (A config, B template-carried,
  C invariant, D personal, E transactional).

### 2.4 Booking rules / availability
`workspaces.booking_rules` jsonb: granularity (half_day, full_day, hours, minutes_60/30/15/5, flexible),
open_weekdays, work_start/half_boundary/work_end, half/full-day hours, advance_horizon_days, min/max
duration, max_series_days (template), outside_hours_mode (off/free/walkup_only/charged), allow_past_bookings,
admin_check_out, simultaneous_reservations, legend_profile. Domain: `booking_policies.dart`,
`booking_granularity.dart`, `lib/core/time/work_hours.dart`. Closure days: `closure_days`, with optional
public-holiday import (`publicHolidays`, `holidayImport`). Server enforces everywhere (plan, Reserve, QR/NFC,
kiosk): `availabilityWhy`. Readiness requires a time zone, a currency and at least one open weekday
(0307 body, section `region_rules`).

### 2.5 Subscriptions and tariffs
Fee bands by subscription percentage (`fee_bands`, `BillingRules`), offered levels
(`workspaces.subscription_levels`), overage price/policy (blocked / pay-as-you-go / packages), day packages,
credit products (carnets), services, accessory supplements per half-day, negotiated prices
(`priceNegotiations`), per-member payment terms. Arithmetic is frozen on issued documents
(`docs/wiki/Admin-Configuration-Guide.md` "Tariffs and billing rules"). Bands must cover 0-100 % with no gap
(wizard check; template contract also checks level/band coverage).

### 2.6 VAT, legal identity, numbering
- Legal identity: `workspaces.address/street/postal_code/city/vat_id/legal_id/tax_exemption_reason`,
  `invoice_legal` (8 mentions + seller kind + customer capacity + exigibility), `vat_regime`
  (not_subject / exempt / registered).
- Rates: versioned (`vatRateHistory`), grouped (`vatGroups`), counterparty treatments (`vatCounterparty`),
  declarations CA3/UStVA PDF+XML draft->submitted (`vatDeclarations`). Catalogue EU27+CH+NO+CA shipped; keeping
  it current is the owner's job (Admin-Configuration-Guide "VAT").
- Numbering: five journals (invoice, credit_note, vat_declaration, member, payment),
  `number_sequence.dart`; gapless, drawn in the database at issue (`next_document_number`, 0164);
  `number_sequence_pair_valid` (0217) forbids a reset more frequent than the printed date.

### 2.7 Payment methods
`payment_instructions` (bank block per country scheme + PayPal.me/Wero/Lydia/Wise/reference; wizard step 8),
online providers Stripe/PayPal/Mollie via webhook functions (`supabase/functions/*-webhook`,
`create-payment-order`), flag `onlinePayments`; credentials live on the workspace and never travel.

### 2.8 Roles and permissions
- `WorkspacePermission` has 31 values (`workspace_permission.dart`). Roles owner / co_owner / admin / member.
  Defaults: owner and co_owner all; admin 17 (manageMembers, manageDocuments, manageServices, approveExpenses,
  viewFinances, viewNegotiations, manageNegotiations, paymentTermsEdit, manageSites, manageReservations,
  operateKiosk, exportData, viewPersonalData, deployToDev, accessProd, viewAnalytics, ...); member none.
  Stored per workspace in `workspaces.role_permissions`. `adminInvoicing` flag grants `issueInvoices` to admins
  (only while effective). `deployToProd` implies `deployToDev`.
- Role matrix screen (`/roles`), custom roles (`customRoles`, 0247, template carries them), role assignment
  (`roleAssignment`), co-owner (`coOwner`, "everything by default").

### 2.9 Validation policies
Table `validation_policies`; `ValidationPolicy` (`lib/features/events/domain/validation_policy.dart`):
required_count, admins_may_validate, eligible_admin_ids, owner_required, auto_validate_admin/owner (only
`reservation_delete`), validator_scope (admins / listed / members), owner_may_self_validate, sequential,
min_amount_cents. No stored row = pre-quorum default (1 decision, any admin, owner not required). Lookup:
exact type row, then null-type default row, then default. Domains = `EventType` wire names (`workspace_event.dart`
l.12-83): reservation, payment, expense, adjustment, service_charge, quota, role_change, member_join,
space_reservation, invoice_payment, reservation_delete, invoice_reminder (applied, never pending),
price_negotiation, expense_schedule, expense_repartition, invoice_writeoff, usage_correction,
usage_record_delete, payment_terms_change, invoice_issue, invoice_void, refund, member_status_change,
subscription_change, matrix_change. The wizard's `DOMAINS` offers 21 of them.

### 2.10 Kiosk, sites, branding, languages
- Kiosk: `kioskMode` (Platform) with children `nfcBadges`, `qrBadges`, `kioskMemberPhotos`, `badgeSignIn`
  (child of `nfcBadges`); permission `operateKiosk`; a member is made a "kiosk device" in Membership
  (User-Guide l.2745); badge sign-in function `supabase/functions/badge-signin`. `nfcSeatTags` for seats.
- Sites: `multiSite` (Platform), `sites` table, level->site link, per-site legal id/address.
- Branding: `workspaceBranding` (seed colour, office/seat palettes, `workspaces.branding`, 0246/0397),
  `workspaceVocabulary` (lexicon overrides), `publicListings`.
- Languages: app ships en/fr/de/es/it; workspace `default_locale` ("Invitations and reports are written in it
  by default"); invitation templates per language with placeholders `{firstName}, {lastName}, {phone},
  {workspaceName}, {workspaceId}, {inviteLink}, {downloadUrl}, {role}` (max 2000 chars,
  `invitation_message.dart`); report templates per language.

### 2.11 Order that matters (derived)
1. Country/currency/time zone -> drive formats, bank scheme, VAT catalogue, e-invoice, holiday source.
2. Structure (seats) -> required for any booking (readiness `resources`).
3. Opening rules -> required for any booking (`region_rules`).
4. Features -> children invisible until parent on; money features chain `moneyTab -> invoicing -> ...`.
5. Tariffs -> before inviting members (members pick a level that must exist).
6. Legal identity + VAT regime + numbering -> before the FIRST invoice (issuing guards, section 3).
7. Roles + validation -> before invitations (quorum needs enough validators).
8. Invitations last.

---------------------------------------------------------------------------------------------------

## 3. Consistency guards

| Guard | What it catches | Where the owner sees it | Code |
|---|---|---|---|
| Feature dependencies | A child cannot be effective without its parent chain; turning a child on turns the chain on, naming what comes on; turning a parent off drops the subtree without erasing child choices | Features screen switch flow (consent/preview), wizard step 2 notes | `workspace_feature.dart` (`effectiveFeatures`, `featureFlagsAfterToggle`, `alsoEnabledWith`), `feature_switch_flow.dart` |
| Features screen, processes view | A capability switched on but held back by a missing prerequisite ("needsAttention" state/filter, `heldBack`, outside-prerequisite notices); states active/partial/available/needsAttention | Features -> process cards (default view), "Needs attention" filter | `lib/features/workspace/application/process_status.dart`, `presentation/widgets/process_overview.dart` |
| Setup readiness | Per section: region_rules, resources, pricing, invitations, payments, roles_validation, recovery, local_setup, assistant (only if `mcpAccess`), first_booking; states ready/needs_configuration/needs_operator/not_applicable/unverified; `required` flag | `WorkspaceReadinessCard` + `LocalReadinessCard` at top of workspace settings; the "Before anyone can book here: {step}." line of the Get-started card on Reserve | server `workspace_readiness` (0285 -> 0307 body), client `workspace_readiness.dart`, `local_setup_views.dart` (`setupReadinessCards`), `getting_started_hint.dart`, `getting_started_copy.dart` |
| What "Before anyone can book" really means | It speaks only when the server names a REQUIRED + needs section: `region_rules` (time zone, currency, >=1 open weekday), `resources` (>=1 seat), `roles_validation` when a `reservation` or `space_reservation` policy has fewer possible validators than required_count (0294), and the app's own backend section (schema behind -> operator). Pricing, invitations, payments, recovery, first booking, local setup are optional (`required:false`), can be "set aside for later" (0307) | Reserve hub | `workspace_readiness.dart` `blocking`, `nextReadinessStep` |
| Local needs of switched-on features | legal identity (required for `invoicing`), payment details (recommended), payment provider, e-invoice platform, site | Local readiness card | `template_local_slot_catalogue` 0280; `workspace_local_readiness` 0287; `local_setup.dart` |
| Invoice issuing guard (server) | `invoice_essentials_missing` (DKI01): seller_address, seller_vat_id (VAT-registered), seller_country_unsupported (only FR and DE), exemption_reason, buyer_name/address/vat_id (reverse charge), vat_rate_unresolved (default rate with no version in force), vat_line_zero_unexplained, vat_charged_not_registered, vat_treatment_unreviewed (cross-border, reverse-charge, export, exempt must be issued outside the app), invoice_feature_disabled (`invoicing`/`subscriptionInvoices`/`usageInvoices` off) | "Complete these details before issuing" list (ARB `invoiceMissing*`) in the invoicing flow; `invoiceIssueReadiness` | migrations 0365, 0385, 0393, 0395, 0396; `supabase_money_repository.dart`; ARB `invoiceMissingTitle` etc. |
| Online payment guard | with `onlinePayments` off, a NEW payment is refused (`feature_operation_allowed 'accept_new'`); one already open still settles | payment screens | 0393 tail |
| Template contract | A builtin: valid key; entities deployable; no payment_instructions or source identity keys; every feature written explicitly; child never on without parent; hours ordered; prices >= 0; bands neither overlap nor strand a level; VAT labels exist; lexicon placeholders kept; holidays marker coherent | CI only (before a workspace is made from it) | `test/lint/template_contract_test.dart`, `pezenas_template_test.dart` for variants |
| Template coverage / config reachable | Every workspaces column, config key, feature, permission, lexicon term has a template disposition; every config field has a screen | CI only | `template_coverage_test.dart`, `config_reachable_test.dart`, `configuration_classification_test.dart` |
| Wizard drift gates | Wizard offers every feature with the registry default, REQUIRES = manifest | CI only | `setup_html_test.dart` |
| Workspace alignment preflight | Reads a real workspace and its twin, aborts on environment/backend/parameter mismatch, template groups, referenced plans, locked holiday months; ends `PREFLIGHT CLEAR/STOP` | Operator running SQL; NOT an owner tool (needs authorisation and a date) | `docs/guides/WORKSPACE_ALIGNMENT.md`, `workspace_alignment_preflight.sql` |
| Feature lifecycle/maturity | Labels features as beta/unreviewed, asks consent for experimental, can mark deprecated/retired | Features screen badges, consent dialog | `feature_lifecycle.dart`, `feature_maturity_badge.dart`, `feature_opt_in_dialog.dart` |
| Number sequence pair | A reset cannot be more frequent than the printed date | Number sequences screen; wizard restricts options | 0217, `number_sequence.dart`, `setup.html` `numResets()` |
| Attention surface (owner inbox) | Ranks decisions; the `configuration` kind exists but only `person` and `month` are produced today | `attention_screen.dart` | `attention_providers.dart` l.81, 103 (no producer for money/instance/configuration) |

### Gaps: inconsistent configurations a new owner can still create
1. Wizard (and app) offer 32 countries and the VAT catalogue, but in-app invoice issuing is limited to FR and
   DE (`invoice_essentials_missing`: `seller_country_unsupported`, 0393 l.90; ARB `invoiceMissingSellerCountry`).
   Nothing in the wizard warns.
2. Registered VAT regime with `vatManagement` off: wizard requires the VAT id but not any rate (error
   `legalErrNoRates` fires only if `vatManagement` is on, l.738); the server rejects an unresolved default rate
   (`vat_rate_unresolved`). Whether a legacy default applies when `vatManagement` is off is unclear (doubt D3).
3. Wizard accepts `onlinePayments` on without any provider (only a warning); server needs a provider
   connection (`payment_provider` local slot, required).
4. Wizard exports `configuration` only with `configurationTransfer` ticked, and the app applies it only when the
   target workspace already has that feature (default off). A first import onto a fresh workspace silently
   applies settings/plan but not tariffs, legal identity, booking rules, validation, services, VAT rates.
5. Plan import is refused once any reservation exists; a second import over a live space can only apply the
   configuration, never the plan.
6. Whole-space prices and level flags collected in step 4 are not exported to the app.
7. Roles, members, default validation rule, numbering, VAT period are collected but not importable.
8. Validation quorum: wizard warns when required > 1 + admins listed (step 9), but members are not imported, so
   the real workspace can start with one owner and `required_count` 2 (server only reveals this as the optional
   to-required `roles_validation` blocker for `reservation`/`space_reservation`).
9. `environment` in the file is ignored; real vs test is decided in onboarding ("One real workspace" / "One test
   workspace" / pair) or later by an owner (`set_workspace_environment`, 0160). A dev space watermarks every
   document and says it is a test.
10. A feature on whose local needs are absent (invoicing without legal identity, `multiSite` without a site)
    is allowed; it shows only as readiness `local_setup` (optional) and at issue time.
11. Template apply drops identity, payment, site, invitation: a template-created space can have `invoicing`
    on and nothing to issue with (required `legal_identity` local slot).
12. Automatic payment reminders (`paymentReminders`): migrations 0134 and 0142 schedule server jobs (reminders 06:15,
    subscription and month-end invoices 06:40) when `pg_cron` exists; the client sweep when an admin opens Finances
    (`payment_reminder_sweep.dart`) is the fallback. Whether `pg_cron` is enabled on a given installation is for the
    operator; the setup does not say so.
13. Permissions in the wizard exclude 10 of 31.
14. The wizard does not check that numbering/VAT-period choices suit the country (e.g. no FEC/DATEV
    country consistency).

---------------------------------------------------------------------------------------------------

## 4. Notifications

### 4.1 Channels (verified)
| Channel | Mechanism | Needs | Source |
|---|---|---|---|
| In-app feed | `events` table (types listed in 2.9); realtime; bell screen; grouping by type/day/member behind `notificationGrouping` | `eventsTab` (+ `notificationGrouping`) | `workspace_event.dart`, feature descriptions |
| In-app messenger | `member_notes`, conversations, read receipts, @mentions (`messageMentions`), forwarding, capture protection, links `[res:|]` | `memberNotifications` (parent of `richMessageRefs`, `messageForwarding`, `captureProtection`, `messageMentions`) | feature_copy / ARB `featureMemberNotificationsDesc` |
| Push (FCM) | `send-push` function, triggered per event/note; generic English text, no names or times (0012 privacy rule) | Firebase project + `FCM_SERVICE_ACCOUNT` secret + APNs key + `flutterfire configure`; flag `pushNotifications`; stub `firebase_options.dart` keeps it off; F-Droid build has no FCM | `docs/guides/push-setup.md`, `supabase/functions/send-push/index.ts`, `packages/deskilo_push` |
| Local check-in reminder | local notification 15 minutes before a reservation (default arg `before = 15 min`) | OS permission | `lib/features/reservations/domain/check_in_reminders.dart` l.19, `lib/core/notifications/` |
| Automatic payment reminder (dunning) | `invoice_reminder` event (applied, never pending) produced by a client sweep + feed alert + push | `dunning` and `paymentReminders` (child), rules in legal step; an admin opening Finances triggers the sweep | `payment_reminder_sweep.dart`, `feature_copy.dart` l.210 |
| WhatsApp | NO server integration: 0136 dropped the mirror and credentials. What remains: member's own WhatsApp number and the group link; the app opens WhatsApp | `whatsappIntegration` (child of `membersDirectory`) | `supabase/migrations/0136_remove_whatsapp_mirror.sql`; ARB `featureWhatsappIntegrationDesc` |
| E-mail | No application-level transactional e-mail found in `lib/` or `supabase/functions/` (doubt D4). Account e-mails come from Supabase Auth. Invitations are texts shared through the OS share sheet | n/a | `invitation_message.dart` |
| E-invoice delivery | to government platform and/or customer service, not e-mail | `einvoiceCustomerDelivery`, tokens | `supabase/functions/send-e-invoice` |

### 4.2 Who is notified of what (push, verified in `send-push/index.ts` l.26-49, 280-420)
| Kind | Trigger | Recipients | Text |
|---|---|---|---|
| `pending_request` | any event with status pending | the event's subject member (not the actor) | "Someone needs your confirmation." |
| `reservation_cancelled` | reservation event action cancelled | the subject member plus all active admins/owner (not the actor) | "A reservation was removed by an admin." |
| `invoice_reminder` | dunning event | the subject member only; owner's own invoice still reaches the owner | "A payment reminder is waiting for you." |
| `member_note` | new message | direct: the target; group conversation: its current participants except sender (muted conversations silent); legacy broadcast: active admins/owner | "You have a new message." |
| `member_mention` | group message mentions someone (needs `messageMentions`) | the mentioned members, even if muted | "You were mentioned in a conversation." |
Other event types are "kind not pushed". Foreground apps replace the push by their own localized notification.
Older rule for who decides pending events is in 0012/0082 (expenses and own payments go to admins); the
function above is the current one.

### 4.3 What the owner configures
- Features: `pushNotifications`, `memberNotifications`, `eventsTab`, `notificationGrouping`, `dunning`,
  `paymentReminders`, `whatsappIntegration`, `deletionRequests`, `spaceInquiries` (messages from a published
  page to owners/public-contact admins), `calendarValidations`.
- Validation policies decide WHO is asked (domains in 2.9). Auto-validation of a `reservation_delete`
  request records the event already settled (no ping).
- Dunning levels/delays (legal step): the delay before the first reminder is also the payment term (hint
  `legalDunningHint`).
- WhatsApp group link and per-language invitation templates (identity/members).
- Push infrastructure is operator/owner secret-handling, not an in-app switch (`push-setup.md`).
### 4.4 What members control
- A device opt-out of push (`push_opt_out.dart`, stored on the device; restart or retry cannot turn it back
  on), conversation mute/pin/archive (messenger), OS notification permission, the WhatsApp number on their
  profile. No per-event-type subscription settings found.
### 4.5 Defaults
`pushNotifications` is Core and on by default, but delivery is dark until Firebase is configured.
`memberNotifications`, `eventsTab`, `notificationGrouping` on; `dunning` off, `paymentReminders` off
(both Platform).

---------------------------------------------------------------------------------------------------

## 5. Reports, documents, accountant handoff, AI assistance

### 5.1 Report engine
- One engine: kinds (`lib/features/money/domain/report_kind.dart`): invoice, proforma, statement, agreement,
  payments, usage, workspace, bi_analytics, workspace_configuration, status, vat, vat_declaration, coa, badges,
  space_codes, plus reminder levels r1..r9 (`kMaxReminderLevels = 9`). Design stored in
  `workspaces.invoice_pdf_template` (bands per kind, optional positioned layout XML).
- Bands header/body/continuation/footer or positioned layouts, Liquid-like conditions/loops/filters, fixed
  placeholder vocabulary (`docs/wiki/Admin-Technical-Guide.md` "Documents and reports"). Designer/editor with
  Markup/Visual and Design/Preview switches; four presets per document ("Professional" added for every kind,
  #1994); per-language templates and reader-language resolution; image library; CLI
  (`dart run tool/...` report check/render/sample/describe/default; see skill `deskilo-reports`).
- Letter standard: window-envelope contract, automatic right window (France) or left (Germany) by workspace
  country unless overridden (`letterStandard`, `invoiceAddressWindow`).
- Features involved: `invoicePdfTemplate` (child of `invoicing`), `reportDesigner`, `reportLayouts`,
  `reportTexts`, `reportDesignExchange`, `letterStandard`, `documents`, `pdfExport`, `usageReport`,
  `vatReport`. Report TEXT is not legal advice: "appearance and translation alone do not establish legal
  compliance or satisfy electronic-invoicing obligations" (Technical Guide, report types).
### 5.2 Invoice PDF and e-invoice
Invoice = frozen document; PDF and structured file from the same snapshot; formats CII, UBL, Factur-X (EN
16931), readiness gate refuses with the missing item named; two destinations (government + customer service);
dev spaces use test endpoints only (Technical Guide "Electronic invoicing"; function `send-e-invoice`).
### 5.3 Accounting exports
`accounting_format.dart`: FEC (regulatory claim), DATEV (exchange; needs UTF-8 BOM; FEC must not have one,
memory note), generic SAF-T (explicit `subset`: no `GeneralLedgerEntries`), accountant CSV (`accountant_csv.dart`),
Sage-like exchange. `accounting_capability.dart`: qualification states and obligations the file cannot
discharge (complete posted books, software certification, target acceptance). DesKilo holds invoices and
payments, not a double-entry ledger (ADR 0022). Period is chosen; export is a read and can be repeated
(Technical Guide "Accounting exports"; `docs/domain/ACCOUNTING_EXPORTS.md`). Chart of accounts is configured
on the space (`accountingBook`, report kind `coa`).
### 5.4 Real versus planned (evidence ledger `docs/product/CAPABILITIES.md`, manifest 2026-09-25.2)
Shipped with gated unit tests: booking, membership.allowances, statements.shared_expenses, approvals,
payments.stripe/paypal/mollie/wero, accounting.export, einvoice.generate, einvoice.transmit, demo.
`recovery.database_restore` shipped. Roadmap: recovery.storage_auth, calendar.interchange, and (as written in
the ledger) mcp.read, mcp.write, mcp.consent. The ledger lists no provider_sandbox, named_runtime or
operator_pilot evidence for any capability. Maturity in code: no feature is `stable`.
### 5.5 AI assistant (MCP)
- Real code: `supabase/functions/deskilo-mcp/index.ts` (Streamable HTTP, per-request delegated OAuth token,
  one facade `mcp_execute_v1`), contract `supabase/functions/_shared/mcp_contract.ts`, client
  `lib/features/mcp/`, ops runbook `docs/guides/OPERATIONS.md` l.182+ ("ships OFF", staged `tool/instance.dart
  mcp-inspect/mcp-enable/mcp-pilot`). Contradiction: the evidence ledger still says `mcp.*` "roadmap/Not
  delivered" (doubt D1) while User Guide documents the screens (`docs/wiki/User-Guide.md` l.4525-4610) and the
  Edge function and SQL exist.
- Operations (from the contract): list_workspaces, get_capabilities, get_availability, list_my_reservations,
  get_place, list_my_favorites, get_my_statement, list_my_invoices, create/update/cancel reservation, check_in,
  check_out, set_favorite, rate_place, request_reservation_deletion, request_invoice_issue / void / refund,
  request_member_status_change, request_subscription_change, list_pending_validations, get_validation,
  respond_to_validation. Confirmation "native" for the requests and the decision. NO operation configures a
  workspace (no features, tariffs, roles, templates). An assistant therefore cannot set a space up; it can
  only act as the member within what the owner exposed.
- Layers (User Guide l.4570+): installation operator turns MCP on; owner turns on `mcpAccess` (Platform, off),
  offers services in Assistant access (own records vs workspace-wide; operation groups); each member asks once;
  a database administrator approves; high-impact requests need an on-device confirmation. Readiness section
  `assistant` is optional.
- Other AI-adjacent/guidance tools: task recorder (`taskRecorder`, Platform, off) records a task and turns it
  into a guide followed on the real app; built-in guides ("Book a place"); `memberGettingStarted` card;
  `HelpHint` carousels (`formHelpHints`); in-app Help; the Admin guide mentions making the plan background
  image "from photographs, with an AI" (`Admin-Configuration-Guide.md` "Making that image ..."), an
  external-tool how-to.

---------------------------------------------------------------------------------------------------

## 6. Training path and irreversibility

### 6.1 What a new owner must understand, in order
1. Workspace vs installation vs environment: a workspace has a pair option dev/prod (`environmentPairs`);
   dev watermarks documents and says it is a test; prod means invoices are owed (`workspace.dart` l.58-66;
   onboarding strings). Roles of owner / operator / database administrator (readiness `actor`).
2. Place: country, currency, time zone, language; the plan (levels > offices > desks > seats; whole-space
   booking).
3. Time: open weekdays, granularity, working hours, closure days, rules for outside hours / past / simultaneous.
4. People and money model: subscription % -> half-day allowance -> fee band; overage; packages; services.
5. Legal and tax: organisation type, VAT regime, registration/VAT id, rates, exigibility, numbering, mentions,
   e-invoicing, accountant exports.
6. Governance: roles matrix, validation quorum per domain, auto-validation, co-owner.
7. Communication: invitations, messaging, push infrastructure, reminders.
8. Operations: readiness card, recovery export (evidence within 90 days), features lifecycle.

### 6.2 Irreversible or costly (derived from code)
- Issued invoices are immutable (`invoices_immutable`, 0060/0061; `docs/domain/INVARIANTS.md` l.14, "state
  machine, not a wall"); the ledger is append-only (`ledger_entries_no_rewrite` 0212); a posted amount never
  changes. Corrections are void/credit note/refund requests (events `invoice_void`, `refund`).
- Invoice number: gapless, taken in the DB at issue; `next_value` "raised, never lowered"
  (`number_sequence.dart`); the format applies "from then on; an issued document never changes"
  (`legalInvoiceNumberingHint`). Reset cadence cannot exceed the printed date.
- A month with an issued invoice is locked: "period already invoiced for this member" (0067-0142 raise); closure
  days / holiday import skip invoiced months and name them (0218 l.85-95, 0234, 0328). Voided invoices count.
- Frozen on the document: VAT breakdown (0072), parties snapshot (0069), tariff arithmetic, signature
  (invoices before 0152 are permanently unverifiable, INVARIANTS l.56).
- VAT regime and rates: rates are versioned by date, never edited (Admin guide "VAT"); changing the regime
  changes how future documents treat tax; submitted VAT declarations are never recomputed.
- Currency, country, time zone: updated by a direct owner row update with no lock found
  (`supabase_workspace_repository.dart` l.264-277); amounts are stored in cents with no conversion, so changing
  currency after money exists is semantically unsafe (doubt D2). A `timezone` change is audited in rights
  requests (0327 l.131).
- Floor plan: import replaces the plan (levels matched by name for template merge); refused once reservations
  exist (0023; Admin guide). Deleting plan objects goes through a substitution/audit RPC (`planObjectDelete`).
- Environment: dev/prod is a statement by the owner (`set_workspace_environment`, owners only); a dev
  workspace watermarks documents; deploying dev -> prod has a journal and way back (Environments guide
  "The journal and the way back"); credentials never travel.
- Roles: matrix change is itself an event (`matrix_change`); a validation rule needing more validators than
  exist leaves requests pending forever (readiness `too_few_validators`).
- Workspace ID / invite code: invite code is a secret and never exported; the workspace ID is the thing members
  type (`workspace-code` screen, "The workspace ID" help); not renameable from the app (name has no update
  path via import).
- Privacy facts: consent text version and date are recorded per member at first launch (`membersConsent`);
  rights requests and data export are features (`memberDataExport`, `dataAccessLog`).
- Template apply: group-based, merge for feature flags (0176), `pricing_credits` deletes and re-inserts every
  fee band, `roles_access` replaces the feature map outright (WORKSPACE_ALIGNMENT l.60-75).

---------------------------------------------------------------------------------------------------

## 7. Open questions / doubts
- D1. MCP status is contradictory: capability ledger says `roadmap` for `mcp.read/write/consent`
  (`docs/product/CAPABILITIES.md` l.200-225), while code, runbook and user guide describe a working endpoint.
  Ask the owner which statement is true before writing the owner guide.
  *Resolved 2026-10-10 (#2333): the code is shipped and the ledger now says so; MCP stays off until the
  infrastructure operator switches it on for one installation (`docs/guides/OPERATIONS.md`, MCP section).*
- D2. Is there any server-side guard on changing `currency_code`/`country_code` after invoices exist? Only a
  direct row update was found (`updateWorkspaceLocale`) and a rights-request audit trigger on timezone. Needs a
  look at `workspaces` triggers or a live probe.
- D3. With `vatManagement` off and `vat_regime=registered`, what rate does `workspace_default_vat_percent`
  resolve? 0393 refers to it as the default but the wizard permits this combination with no error.
- D4. Is any transactional e-mail sent by the system (beyond Supabase Auth and CI release reports)? None
  found in `lib/` or `supabase/functions/`.
- D5. `supabase/functions` has no `send-whatsapp` (consistent with migration 0136). The "Integrations" table in
  `docs/wiki/Admin-Technical-Guide.md` (l.293+) still advertises a "WhatsApp channel" that sends reminders,
  which 0136 removed; that guide row is likely stale.
- D6. Whether the page's intro/guide should present import as "creates a workspace": today the import is an
  owner action on an EXISTING workspace (plan replace + settings overwrite). Creation of a workspace is only in
  onboarding. Confirm intended flow for a brand-new person (create space in app first, then import?).
- D7. Wizard step counts vs real tier: exact numbers of core/platform features in the 126 should be
  regenerated, not hand-counted (my regex over the manifest was approximate: 45 default-on in the wizard is
  exact; the 30/63 split is approximate).
- D8. Where the owner sees "held back" capabilities outside the Features screen: `AttentionKind.configuration`
  is declared and rendered but no producer found (`attention_providers.dart`).
- D9. Hosting of `web/setup.html`: published to `https://fdittgen-png.github.io/deskilo/setup.html` (User
  Guide l.387) by a separate opt-in publish, not on merge (`AGENT_RULES.md` after l.215).

---------------------------------------------------------------------------------------------------

## Five most important findings for a wizard redesign
1. The wizard asks 126 feature switches at step 2, but the app has a Core tier (45 on by default) and
   builtin templates; a redesign should lead with a scenario/template and show Core-only by default.
2. The XML import is not a creation path: it replaces the plan, overwrites settings, skips the name and
   `environment`, ignores `<setup>`, and applies `<configuration>` only when `configurationTransfer` is already
   on in the target; roles, members, numbering and whole-space prices never reach the app. The wizard should
   either say so or produce what the app can really consume.
3. In-app invoice issuing is limited to FR and DE and refuses silent VAT treatments (0393/0395); the wizard
   offers 32 countries and no matching warning. Legal/VAT inputs are the riskiest and most irreversible
   (immutable invoices, gapless numbering, locked invoiced months).
4. "Before anyone can book here" depends only on time zone/currency/open weekday, at least one seat, and
   (when set) enough validators; everything else is optional and can be set aside. A minimum viable path is
   therefore: place, hours, seats, one rule set, then invite.
5. Notifications are mostly in-app; push is dark until Firebase secrets exist, WhatsApp is only a group link,
   automatic dunning needs an admin session, and the MCP assistant can act as a member but cannot configure a
   workspace. The guide should set these expectations early.


---------------------------------------------------------------------------------------------------

## Errata (found by fact-checking the guides against the code)

- Payment reminders have server jobs (migration 0134, daily 06:15, pg_cron) and the client sweep is the fallback;
  the feature flag defaults on, what is off is the `automatic` rule (0331). §3 gap 12 and §4.1 are corrected above
  only in part.
- The configuration import (migration 0177) carries `role_permissions` and the validation policies; the *wizard*
  writes them into `<setup>` (ignored), not into `<configuration>`. §1.5's list of "never reaches the app" is
  therefore about the wizard's output, not about the importer's capacity.
- The experimental-feature consent applies to Alpha and Beta only (`needsOptIn`), not to every unreviewed feature.
- The base-role card is labelled **User** in the role matrix (not "Every member").
- The workspace ID can be changed (**Change workspace ID**, 4–20 characters); the old ID stops working at once.
- The in-app invoice issuing refuses a VAT-exempt seller (category E, migration 0395) as well as cross-border,
  reverse-charge, export and foreign-buyer treatments.
- Foreground push texts are localised only for `reservation_cancelled`; validators get no push unless they are the
  event's subject.
- The MCP assistant's invoice, void, refund, member-status and subscription requests are staff-only
  (`mcp_contract.ts`).
