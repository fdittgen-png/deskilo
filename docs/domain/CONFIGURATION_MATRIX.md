<!-- SPDX-License-Identifier: 0BSD -->
# Configuration matrix

#1290 (T19). **Every piece of workspace-relevant configuration, and every
hardcoded workspace assumption, classified — so the next setting cannot
quietly become "nobody decided whether it travels".**

Verified against master and the development project, 2026-09-16.

## Classes

| | class | template? |
|---|---|---|
| **A** | workspace configuration | if safe |
| **B** | template-carried workspace configuration | yes |
| **C** | product invariant — with the reason | no |
| **D** | personal preference (account or device) | **never** |
| **E** | transactional or member data | **never** |
| **F** | defect — gets its own issue | — |

D and E are never carried by a template. That is not a default; it is the
rule this document exists to keep.

## How to repeat the sweep

The matrix is only true if it can be rebuilt. These are the recipes:

```bash
# Every deployable entity key, from the server rather than from memory.
psql "$DB_URL" -At -c "select jsonb_pretty(public.deployable_entities())"

# Every workspaces column (42 at the time of writing).
psql "$DB_URL" -At -c "select string_agg(column_name, ', ' order by ordinal_position)
                         from information_schema.columns
                        where table_schema='public' and table_name='workspaces'"

# Fixed enums where a workspace might want to define the values.
grep -rn "^enum \|abstract final class .*Colors" lib/ | grep -v '.g.dart'

# Workspace defaults that live as Dart constants.
grep -rn "static const .*defaults\|initialLocation:" lib/
```

## Workspace configuration — the `workspaces` table

42 columns. Six are the system columns (#992, ADR 0018) and are never
configuration.

| setting | home | class | template? | merge policy | issue | test |
|---|---|---|---|---|---|---|
| name | `workspaces.name` | A | no — identity | replace | — | — |
| country_code, currency_code, timezone | `workspaces.*` | A | no — identity | replace | — | `workspace_locale_test` |
| invite_code | `workspaces.invite_code` | A | **never** — a secret | replace | — | — |
| booking_rules (open_weekdays, granularity, horizon, min/max duration, simultaneous, outside_hours_mode, allow_past_bookings, admin_check_out) | `workspaces.booking_rules` jsonb | B | yes | replace whole key | #1274 uses it | `availability_screen_test` |
| desk_opacity | `workspaces.desk_opacity` | B | yes | replace | — | — |
| subscription_levels, billing_rules | `workspaces.*` jsonb | B | yes | replace | #1279 | `fee_band_test` |
| feature_flags | `workspaces.feature_flags` jsonb | B | yes | **merge** (0176, #963) | #1323 | `workspace_feature_test` |
| payment_instructions | `workspaces.payment_instructions` jsonb | B | yes | replace | #1010 | `deployment_test` |
| dunning_rules | `workspaces.dunning_rules` jsonb | B | yes | replace | — | — |
| invoice_pdf_template | `workspaces.invoice_pdf_template` jsonb | B | yes | replace | #548 | `report_designer_test` |
| invoice_legal, vat_regime, vat_id, legal_id, tax_exemption_reason, vat_account | `workspaces.*` | A | **no** — legal identity is the space's own | replace | — | `vat_regime_test` |
| address, street, city, postal_code | `workspaces.*` | A | no — identity | replace | — | — |
| default_locale | `workspaces.default_locale` | B | yes | replace | — | `workspace_language_test` |
| invitation_template, invitation_templates | `workspaces.*` | B | yes | replace | — | — |
| whatsapp_group | `workspaces.whatsapp_group` | A | no — identity (with a space's own twins) | replace | #1360 | `18_configuration_merge` |
| role_permissions | `workspaces.role_permissions` jsonb | B | yes | replace | #1287 | `roles_screen_test` |
| subscription_vat_rate_id | `workspaces.subscription_vat_rate_id` | B | yes — by natural key | replace | — | — |
| accessory_supplements_since | `workspaces.accessory_supplements_since` | A | no — a date in this space's history | replace | — | — |
| dev_mode | `workspaces.dev_mode` | A | no | replace | #419 | `developer_screen_test` |
| environment, pair_id | `workspaces.*` | C | **never** — which twin this is | — | #1160 | `environment_pairs_test` |
| created_by, created_at, id | `workspaces.*` | E | never | — | — | — |
| created_datetime, modified_datetime, company_id, site_id, created_by_user, modified_by_user | system columns | C | never | — | #992 | `system_columns_test` |

## Deployable entities

The 18 keys `deployable_entities()` returns, which is what a deployment
actually moves.

| key | kind | tables / workspace keys | class | note |
|---|---|---|---|---|
| identity | configuration | address, street, postal_code, city, default_locale, vat_regime, vat_id, legal_id, tax_exemption_reason, vat_account, invoice_legal, whatsapp_group | A | legal identity travels between a space's OWN twins, not between spaces. `whatsapp_group` joined it in #1360 — it names one space the same way an address does |
| vat | master_data | vat_rates, subscription_vat_rate | B | |
| tariffs | master_data | fee_bands, plans, subscription_levels, billing_rules | B | |
| services | master_data | services | B | |
| packages | master_data | packages | B | |
| accessories | master_data | accessories | B | |
| floor_plan | master_data | floor_plan | B | requires accessories, sites |
| sites | master_data | sites | B | |
| booking_rules | configuration | booking_rules, desk_opacity | B | |
| validation_rules | configuration | validation_policies | B | |
| roles | configuration | role_permissions | B | #1287 would make the roles themselves configurable |
| payment_instructions | configuration | payment_instructions | B | |
| reminders | configuration | dunning_rules | B | |
| document_design | reports | invoice_pdf_template | B | |
| document_links | configuration | workspace_documents | B | |
| **closure_days** | configuration | closure_days | B | **a mirror import replaces them**, so generated public holidays (#1274) can be removed by a deployment — ADR 0025 |
| invitations | configuration | invitation_template, invitation_templates | B | wording only. `whatsapp_group` was here until #1360, and a template that carried the wording carried the group link with it |
| number_sequences | configuration | number_sequences | B | **format only** — `prefix`, `suffix`, `date_part`, `digits`, `reset`, `gapless`. `period_key` and `next_value` are class E and never exported (#1295) |
| features | configuration | feature_flags | B | merge, not replace (0176) |

## Personal preferences — class D, never carried

The issue's earlier text said regional formats were per device. They are
not: they are per person, server-side, and cross-workspace.

| setting | home | class |
|---|---|---|
| regional formats | `profiles.format_locale`, `profiles.clock`, `profiles.time_zone_mode` | D |
| app language | `profiles.preferred_locale` + device override (`LocaleController`) | D |
| theme mode | device prefs (`lib/core/theme/theme_controller.dart`) | D |
| navigation style | `lib/core/navigation/navigation_style.dart` | D |
| default booking period | device prefs keyed by workspace (`lib/features/reservations/providers/default_period_controller.dart`) | D — workspace fallback proposed in #1294 |
| dismissed help hints, help-tip rotation | device prefs | D |

## Hardcoded assumptions

| assumption | evidence | class | issue |
|---|---|---|---|
| four fixed roles | `lib/features/workspace/domain/workspace_permission.dart:96` — `enum PermissionRole { owner, coOwner, admin, member }` | F | #1287 |
| no workspace-defined fields | none exist | F | #1288 |
| office colours are an index into a compiled palette of 8 | `lib/core/theme/office_colors.dart:7` — `OfficeColors.palette` | A per office; palette is F | #1289 |
| seat-state colours are compiled | `lib/core/theme/seat_state_colors.dart:19` | C — they mean a state, not a taste | — |
| brand colour and emblem are compiled | `_burntOrange`, no emblem | F | #1289 |
| landing destination | `lib/app/router.dart:139` — `initialLocation: '/reserve'` | C today, candidate A | #1306 |
| working-hours fallback | `lib/core/time/work_hours.dart` — `WorkHours.defaults` | **C, legitimate** — a fallback for "unset"; the configuration is `booking_rules` | — |
| every member has a subscription | `members.subscription_pct` default 100, `coalesce(…, 100)` in SQL | F | #1294, #1279 |
| new-member overage policy | `members.overage_policy` default `'blocked'`; no workspace default | F | #1294 |
| ~~number sequences do not travel~~ | fixed: entity `number_sequences`, `keyed_update` on `journal`, format columns only | — | #1295, 0220 |
| a template is a floor plan | `WorkspaceTemplate.counts`, `libraryCounts` | F | #1276 |

## Gaps this sweep found

- ~~**`whatsapp_group` travels with `invitations`.**~~ Closed by #1360:
  moved to `identity`, which is where the class-A keys live and which
  only travels between a space's own twins. Dropping it outright would
  have made it the one class-A key that could not follow a space to its
  own production twin. `18_configuration_merge.sql` now asserts both the
  instance and the rule — no entity but `identity` may carry a key that
  names one particular space.
- Everything else already has one: #1287, #1288, #1289, #1294, #1295,
  #1276.

## The lint

`test/lint/configuration_classification_test.dart` (S2) fails when any
`workspaces` column or any `deployable_entities()` key has no row above.
It reads both from the migrations rather than from a live database — the
way `privacy_claims_test` reads its SQL — because a lint that needs a
connection is a lint that gets skipped.

Three shapes it has to know about, each of which would otherwise let a
setting through unclassified:

- many `alter table public.workspaces` statements put the table on one
  line and the column on the next, so the parser reads whole statements;
  a single-line pattern finds five of the twenty-eight;
- the six system columns (#992) are never named in a `workspaces`
  statement at all — `ensure_system_columns()` adds them to every table;
- `deployable_entities()` is defined twice (0186, then 0219), and only
  the later definition is the one in force.

It is proven red: a throwaway migration adding an unclassified column and
a nineteenth entity key makes it name both and fail.

The sweep recipes above remain how to rebuild this document by hand when
the classification itself — as opposed to its completeness — needs
revisiting.
