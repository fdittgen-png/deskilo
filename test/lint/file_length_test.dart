// SPDX-License-Identifier: 0BSD
//
// File-length budget with a ratcheting allow-list.
//
// Nobody plans a 1 500-line screen; it accretes fifty lines per feature
// until nobody can hold it. The budget makes growth VISIBLE: a file over
// it must either shed weight (extract widgets, split by concern — the
// shared-building-blocks pattern in Architecture.md exists for exactly
// this) or have its baseline raised here, in a reviewable diff, with the
// reason in the PR description. Silent accretion is the only forbidden
// path.
//
// Baseline numbers may go DOWN freely — please lower one whenever you
// shrink a file, or the coupling quietly grows back to the stale cap.
// Known hazard from the sibling project: when two branches touch the
// same baseline entry, the resolved number must be the COMBINED
// post-merge line count, not either branch's figure.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Lines a hand-written lib/ file may have without an entry below.
const int _budget = 600;

/// Grandfathered files at their size when this ratchet landed
/// (2026-08-01), rounded up to the next 10 for edit headroom.
const Map<String, int> _baseline = {
  // ADR 0028 (#1373) — the suite's in-memory repositories moved here so
  // Demo can run the real app against them. Their size is the surface of
  // the interface each implements, not a file that grew: MoneyRepository
  // alone is ~90 methods. They are budgeted, so a NEW method still has
  // to be a decision, and they may only shrink.
  'lib/core/demo/data/workspace_repository.dart': 1830, // 2026-09-19 #1281 1827→1830: setLegendProfile, the fake's mirror of the booking-rule write // 2026-09-19 #1373 moved out of test/helpers/mock_providers.dart, which is 2358→408 lines
  'lib/core/demo/data/money_repository.dart': 1800, // 2026-09-19 #1373 moved from test/helpers/fake_money_repository.dart
  'lib/core/demo/data/reservation_repository.dart': 678, // 2026-09-19 #1373 moved from test/helpers/fake_reservation_repository.dart

  // 1510→1530 (2026-08-02): #408 presence rule — the sheets moved to
  // check_in_sheets.dart; what remains is the admin-for-others gate and
  // its action/error handling, which need the screen's ref and context.
  // 1530→1550 (2026-08-05): #490 workspace-clock browse machinery.
  // 1550→1620 (2026-08-22): #575 day-phase rings + list dots.
// 1650→1690 (2026-08-24): #620 the same photo-loader wrap on the
  // Plan tab canvas.
  // 1690→1560 (2026-08-25): #638 — _LevelReserveSheet DELETED; the level
  // rail's layers icon now opens the shared SpaceSheet, so the second
  // whole-space sheet and its write/error handling left this file.
  // new 700 (2026-08-22): #575 day-phase rings + #576 space rings.
// 700→740 (2026-08-24): #618 the occupant photo marker — clipped
  // photo draw beside the initial disc, one concern, same method.
    'lib/features/plan/presentation/widgets/floor_plan_painter.dart': 790, // 2026-09-19 #1289 783→790: the office palette is a painter parameter, its doc, and its line in shouldRepaint // // 2026-09-15 #1273 772→783: singleRoomLevelNames — the label rule and its flag // // 2026-09-13 #1216 750→780: the dropTargets parameter and the paragraph explaining why an EMPTY set differs from null; the drawing itself went to widgets/drop_target_paint.dart // 2026-09-06 #970 the demo blur on painted labels
  // 1290→1330 (2026-08-02): #395 Excel-export tile — feature lines, the
  // orchestration itself lives in excel_export.dart.
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 1044, // 2026-09-13 #1235 1063→1044: the name-this-room dialog moved to text_prompt_dialog.dart, paying for the canvas's screen-reader name // 2026-09-11 #1154 1250→1132: the office and desk sheets became one space_properties_sheet.dart // 2026-08 #585 seat NFC field
  // 1010→1020 (2026-08-04): #462 whole-space overlays on the plan view.
  // 1020→1070: #466 the hub's whole-level reserve button + visibility.
  // 1090→1110 (2026-08-23): #611 fade-through view switch + MotionReveal
  // on the hint/closed-day banner.
// 1110→1140 (2026-08-24): #620 the occupant-photo loader wrap on the
  // hub canvas — the #618 mechanism, no new concern.
    // #687 — 1140 -> 1180. The hub absorbed the Plan tab, which is
  // DELETED (1551 lines), and with it the show-on-plan focus jump.
  //
  // I raised this to 1220 first and then to nothing: the seat-ACTION
  // half — tap a seat and get the right thing — came out into
  // `reserve_seat_actions.dart` as a mixin, because none of it renders.
  // What stays is the screen; what left is the decisions.
  //
  // 1140 -> 1190. I set 1180 first, which was a guess made BEFORE the
  // UX pass; the map/list control that came out of it costs the other
  // eight. The +50 over the original is the focus state and that
  // control, both of which genuinely belong to the screen — the canvas,
  // the level switcher and the day selector all read the focus.
  // 1190→1215 (2026-08-31): #772 windowIsNow — the live-window probe in
  // workspace wall time beside the isLive it refines.
  // 1215→1240 (2026-09-01): #814 closed days into the Day/Week/Month views + the legend.
  // 1320→1323 (2026-09-16): #1277 S2 — the whole-level tooltip resolves through the lexicon;
  // its AppLocalizations lookup was already wrapped across lines.
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 1145, // 2026-09-17 #1301 S2 1185→1145: the four view segments left for widgets/reserve_view_menu.dart; // 2026-09-16 #1301 S1 1323→1185: the plan canvas and its overlays left for widgets/reserve_canvas.dart; // 2026-09-15 #1273 +1: the hub tells the canvas whether a level's only room is named by the level // 2026-09-15 #1273 1307→1308: singleRoomLevelNames — the label rule and its flag // // 2026-09-14 #1269 1298→1307: the browsed level left the screen for a provider, and the paragraph saying why three views may not each keep their own copy is longer than the field it replaced // 2026-09-05 #903 the seat's day: segments for the plan, the timeline behind a shared seat
  // 980→990 (2026-08-03): #419 workspace dev-mode switch — admin gate,
  // workspace hint subtitle and the RPC write helper.
  // 990→1000 (2026-08-05): #478 Billing & reports admin entry.
  // 1000→1020 (2026-08-05): #486 Payment methods admin entry.
  // 1040→1140 (2026-08-13): #560 the About section (author, licence,
  // privacy, bug link, support tiles).
  // 1260→1308 (2026-09-06): #945 sites.
  // 1311→1312 (2026-09-16): #1277 S2 — one term now resolves through the lexicon and wraps.
  // 1312→1240 (2026-09-16): #1307 — the Advanced section (backend, push,
  // environment, sites, number sequences, developer mode) moved to
  // widgets/settings_advanced_section.dart, taking _setWorkspaceDevMode
  // with it. The file sat at EXACTLY its cap, so Settings could not be
  // reorganized by ownership until something left.
  'lib/features/profile/presentation/screens/settings_screen.dart': 1039, // 2026-09-16 #1307 S3 1240→1039: the workspace sections left for settings_workspace_sections.dart; // 2026-09-11 #1154 1420→1316: the 723-line build() became four section methods; About and the section header moved to widgets/ // 2026-09-06 #970 the demo-mode switch and the address-dialog guard // 2026-09-06 #969 the navigation tile and its dialog // 2026-08 #586 default-period tile + dialog // 2026-09-05 #886 the personal-information tile beside the legacy address dialog it replaces // 2026-09-05 #902 the payment-conditions tile // 2026-09-08 #1019 twenty-two help symbols now name the exact setting they document (HelpAnchor), one named argument per symbol
  // 1020→1040 (2026-08-06): #513 the Role management tile.
  // 980→1030 (2026-08-05): #476 the statement export honors the
  // owner's report template (#478 Invoices button joins the grid).
  // 1030→1070 (2026-08-05): #486 grouped Pay/Requests/Documents actions
  // + the landscape balance card.
  // 1070→1180 (2026-08-05): #494 the self-service document sheet.
  // 1180→1210 (2026-08-05): #496 the member-language chain on self-service docs.
  // 1220→1200 (2026-08-31): #767 scheduled expenses — the button, the
  // sweep watch and the occurrence cards join the other money actions.
  // 1253→1316 (2026-09-06): #934 the status report kind and the money-screen tiles.
  'lib/features/money/presentation/screens/money_screen.dart': 1277, // 2026-09-05 #881 member payment conditions: effective terms threaded to every document // 2026-09-05 #880 reportTexts beside #887 managedProfiles after the rebase // 2026-09-05 #873 the consumption report entry points // 2026-09-05 #881 member payment conditions: effective terms threaded to every document // 2026-09-05 #873 the consumption report entry points
  // 1210→1220 (2026-08-06): #512 the account card above the bill.
  // 910→950 (2026-08-04): #456 note tile + admin broadcast button —
  // the dialog itself is its own file.
  // 950→990 (2026-08-05): #494 send-the-agreement action.
  // 990→1020 (2026-08-05): #496 the member-language agreement send.
  // 1020→1120 (2026-08-25): #628 the per-member simultaneous-reservations
  // permission — one sheet action, one preset dialog and one row chip,
  // the 0044 reservation-limit shape next to it, same concern.
  // 1130→1180 (2026-08-31): #763 fifteen help dots — rows, dialogs and
  // the gated negotiation wrap all live beside their existing helpers.
  'lib/features/workspace/presentation/screens/members_screen.dart': 519,
  // 900→920 (2026-08-03): #410 admin-visible email line on the member
  // row — the row shares its chip helpers with the detail sheet, so
  // extracting it would drag half the file; 15 feature lines instead.
  // 920→960 (2026-08-04): #456 notify affordance threaded through the
  // row and the sheet.
  'lib/features/members/presentation/screens/directory_screen.dart': 946, // 2026-09-11 #1154 965→951: the upcoming-bookings helper and the per-member grouping moved to domain/directory_status.dart // 2026-09-11 #1148/#1150/#1151 review batch: a traced fallback per enum and the feature gates the routes always claimed
  // 900→920 (2026-08-01): #393 environment picker threaded through the
  // send flow — feature lines, not accretion; picker itself is its own file.
  // 920→950 (2026-08-04): #454 template lookup + resolution threaded
  // through every PDF render; the editor sheet is its own file.
  // 950→990: #470 the report data model (fields, lines, VAT rows).
  // 990→1050: #472 buildReminderPdfFile + the remind-level flow.
  // 1050→1090 (2026-08-05): #474 the extracted public data builders
  // (invoiceReportData/reminderReportData) shared with the preview.
  // 1090→1180 (2026-08-05): #476 statementReportData — the statement
  // document's line model. 1180→1280 (2026-08-05): #480 legalMentionData
  // (the statutory mention variables + localized legal defaults) shared
  // by all three document data models.
  // 1280→1320 (2026-08-05): #488 resolveReportImages threaded through
  // every PDF path.
  // 1320→1680 (2026-08-05): #494 the agreement/payments/workspace data
  // models + the letter-doc warm/render/pdf helpers.
  // 1680→1740 (2026-08-05): #496 the language-resolution helpers threaded through the builders.
  // 1740→1820 (2026-08-05): #504 the write-off request dialog.
  // 1820→1910 (2026-08-05): #508 the credit-note refund dialog.
  // 1960→2000 (2026-08-14): #568 the customer-delivery send leg.
  // 2420→2480 (2026-09-06): #946 three site helpers for the report data.
  // 2480→2340 (2026-09-11, #1125): the proforma moved to
  // invoice_proforma.dart. `unawaited_futures` needed one import here
  // and the file was exactly at its cap, which is the house rule's cue
  // to extract rather than raise the number.
  'lib/features/money/presentation/invoice_documents.dart': 610, // 2026-09-11 #1061 born from the invoice_actions split: the PDF/e-invoice builders and the letter pipeline
  'lib/features/money/presentation/invoice_actions.dart': 1027, // 2026-09-19 #1532 1011→1027: the reminder shares BEFORE it records, and says so when nothing was sent. The order itself moved OUT, to application/send_reminder.dart; what stays is the outcome branch and its honest message // 2026-09-11 #1061 2340→1605→1018: the data builders moved to domain/report_data.dart, then document generation to invoice_documents.dart
  // 2026-09-05 #919 an association is steered off the exempt scheme:
  // the regime that demands a VAT number it cannot have.
  'lib/features/money/presentation/screens/legal_identity_screen.dart': 656, // 2026-09-02 #837 the annex question // 2026-09-04 #871 the bank block: IBAN/BIC/bank name reach a designed report, resolved once in legalMentionData for every document // 2026-09-04 #875 layout-wins hooks + the strings/features hoists they need; the engine itself lives under domain/report_layout // 2026-09-05 #886 the client identity (name, company, contacts, postal block) resolved for every document and frozen on the proforma // 2026-09-05 #881 member payment conditions: effective terms threaded to every document // 2026-09-05 #880 owner texts beside #881 member terms after the rebase // 2026-09-05 #910 the client name falls back to the company and the settlement date reaches the document: invoiceDueAt + the due_date placeholder threaded through every render // 2026-09-05 #917 the development watermark, resolved where the workspace is already at hand, and carried to every report through the shared letter funnel // 2026-09-06 #922 the two Chorus Pro references as placeholders, and the government destination on the pre-flight check // 2026-09-08 #1019 eighteen help symbols now name the exact field they document (HelpAnchor), one named argument per symbol
  // 1920→1960 (2026-08-06): #514 quickViewInvoice + the proforma triad.
  // 1910→1920 (2026-08-06): #512 imputation candidates (adjustment
  // credits, baked-credit filter).
  // 1370→1410 (2026-08-05): #494 the engine-based workspace report tile.
  // 1410→1440 (2026-08-05): #496 the language chain on the workspace report.
  // 1440→1465 (2026-09-01): #802 the invoice-schedule entry beside the
  // reminder rules — issuing and chasing are one conversation.
  // 600→660 (2026-09-08): #1019 the anchor registry names every one of
  // the app's 155 help symbols. It is a catalogue, not logic — the
  // right shape for it is one documented constant per object, and it
  // grows with the app rather than being refactored smaller.
  // 606→610 (2026-09-16): #1277 S3 — the wording editor's anchor: one constant, its doc
  // and its line in `all`. The registry grows by an anchor per
  // documented object, which is what keeps symbol and guide in step.
  // 610→640 (2026-09-16): #1393 — four admin.* anchors, possible only
  // since #1259 translated the technical guide into all five
  // languages. This file grows by an anchor per documented object,
  // which is the point: the comment above says so.
  // 640→650 (2026-09-16): #1393 — admin.exports.accounting and
  // admin.einvoice.readiness, each with the paragraph saying what it
  // documents. A flat registry of constants is the one shape where
  // extraction is the wrong answer: splitting it would put one identity
  // in two files and the lint's left-hand side in neither.
  'lib/core/help/help_anchors.dart': 651, // 2026-09-18 #1289 650→651: the colours anchor — this file IS the anchor registry and grows by one entry per documented surface
  // 1570→1600 (2026-09-16): #1294 — the new-member defaults ride this
  // screen's one Save. The tiles themselves are their own file
  // (new_member_defaults_tiles.dart); what is left here is the
  // seeding, the setter in _save and the render block.
  // 1600→1613 (2026-09-16): #1277 S2 — the four space nouns resolve through the lexicon
  // ABOVE the async gap, where the context is still safe to use.
  // 1613→1637 (2026-09-16): #1277 S3 — the Wording row: a ListTile opening the editor, with
  // its help anchor. The editor itself is its own screen precisely
  // so this file did not absorb it.
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart': 1656, // 2026-09-19 #1532 1636→1656: the XML import says how far it got when it stops partway — a floor plan already replaced was being reported as if nothing had happened. The growth is a flag, two call sites and one top-level sentence; the file itself is the standing decomposition candidate under #1449 checkpoint 4, and `_importXml` is the 240-line method to move once a home exists that does not re-add a presentation repository read // 2026-09-18 #1289 1637→1636: the brand-seed decision left for application/apply_brand_seed.dart and the two rows that open a screen of their own for widgets/workspace_own_screens.dart // // 2026-09-15 #1310 S0 1564→1570: every bulk export asks for the exportData permission // // 2026-09-14 #1269 1552→1564: the invitation-language chips carry a label now, plus the paragraph on why an unlabelled row of language chips reads as THE language setting // 2026-09-11 #1154 1605→1572: the 577-line build() became three section methods; the reset dialog moved to widgets/reset_confirm_dialog.dart
  // 600→640 (2026-08-05): #492 the request-deletion dialog + flow.
  // 640→760 (2026-08-22): #574 the running-booking extension flow.
  // 760→880 (2026-08-25): #638 the symmetric END-EARLIER flow — the
  // earlier-edge rule, the shrink picker and the ONE shared end-write
  // both directions now go through (the snapping itself moved to
  // BookingGranularity, so this is the flow, not a second copy).
  // 880→881 (2026-09-16): #1277 S2 — one term now resolves through the lexicon and wraps.
  'lib/features/reservations/presentation/widgets/reservation_detail_sheet.dart': 881,
  // 600→660 (2026-08-05): #488 the editor's mode toggle + image insert
  // flow; the visual editor itself is its own file.
  // new→840 (2026-08-05): #498 the WYSIWYG design surface — styled
  // band rendering, column groups, token palette, in-place editor.
  // #825 (2026-09-02): the member page and the shared admin actions.
  // 900→948 (2026-09-06): #945 sites.
  'lib/features/members/presentation/screens/member_page.dart': 947, // 2026-09-17 #1279 hosts MemberCarnetTile behind the carnets flag (the tile is its own file) 944→947; // 2026-09-05 #887 the managed-member tiles (edit identity, hand over, revoke) + chip
  // 720→779 (2026-09-06): #945 sites.
  'lib/features/workspace/presentation/member_admin_actions.dart': 780, // 2026-09-11 #1061 779→780: one import, the letter builders' new home
  // #828 (2026-09-02): the expense_repartition flag and repository methods.
  // 2026-09-04 #864: one more flag. This file is the feature
  // registry — it grows by ~5 lines per flag by design, and
  // splitting the registry would defeat its whole purpose.
  // 740→789 (2026-09-06): #934 the status report kind and the money-screen tiles.
  // 1264→1273 (2026-09-16): #1274 publicHolidays — the registry grows
  // by an enum value and a manifest entry per flag, by design.
  // 1273→1284 (2026-09-16): #1277 S2 — the workspaceVocabulary flag: one enum value and one
  // manifest entry. The registry grows by a flag per functionality.
  'lib/features/workspace/domain/workspace_feature.dart': 1376, // 2026-09-19 #1550 1370→1376: `withTwin` on the creation defaults — a named parameter, its four-line signature and the one conditional entry, all of it API; // 2026-09-19 #1247 decisionSurface — one flag, its doc and manifest entry 1355→1370; // 2026-09-19 #1380 demoMode now means the demonstration workspace, and the enum doc records what it used to mean; 1350 is what the file MEASURES with #1288 and #1380 both in, and 1355 is the usual headroom over it; // 2026-09-19 #1288 customFields — one flag, its doc and manifest entry 1330→1350; // 2026-09-18 #1287 customRoles — one flag, its doc and manifest entry 1315→1330; // 2026-09-18 #1289 workspaceBranding — one flag, its doc and manifest entry 1297→1315; // 2026-09-17 #1279 carnets — one flag, its doc and manifest entry 1284→1297; // 2026-09-15 #1273 1251→1264: singleRoomLevelNames — the label rule and its flag // // 2026-09-13 #1221 1130→1260: every manifest entry gained a required `surface` — one line each, and the registry is one declarative map by design // 2026-09-11 #1120 workspaceLibrary entry (was 1120) // // 2026-09-11 #1063 the Core/Platform tier: one required line on each of the hundred manifest entries, which is the point — a flag cannot be added without deciding which tier it is in // 2026-09-11 #1110 memberOrigin + #1119 memberEnvironments: the registry grows ~10 lines per flag by design (enum doc + manifest entry), which is the one file where a bump is the shape of the work rather than a failure to extract // 2026-09-07 #987/#988 environmentPairs + deployments // 2026-09-06 #985 vatRateHistory + vatCounterparty // 2026-09-06 #916 configurationTransfer // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #880 reportTexts beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #873 usageReport beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #880 reportTexts beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #878 vatReport beside #881 memberPaymentTerms after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #874 letterStandard manifest entry // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #880 reportTexts beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #873 usageReport beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #874 letterStandard manifest entry // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #880 reportTexts beside #881 after the rebase // 2026-09-05 #886/#887 personalInfo + managedProfiles manifest entries // 2026-09-05 #874 letterStandard manifest entry // 2026-09-05 five flags landed the same day (#880 #887 #881 #873 #878 #874)
  'lib/features/workspace/presentation/screens/features_screen.dart': 186, // 2026-09-17 #1327 190→186: the process overview became widgets/process_overview.dart and the flag write application/toggle_workspace_feature.dart, so the screen only chooses the view // 2026-09-16 #1327 242→190: the surface headings and the tile loop became widgets/feature_capability_list.dart, so the screen keeps the filtering and the list keeps the rendering // 2026-09-13 #1190 690→360: the 425 lines of switch descriptions became presentation/feature_copy.dart, which left room for the search the screen needed// 2026-09-11 #1063 the two tier headings and the reindented tile loop // 2026-09-11 #1110 + #1119 descriptions // 2026-09-07 #987 environmentPairs description beside #985's two
  'lib/features/money/presentation/widgets/report_visual_editor.dart': 981, // 2026-09-02 #822 drag, insert palette, image controls, move-to-band
  // 660→700 (2026-08-05): #494 the three further document chips + their
  // live data and letter-PDF branches.
  // 700→800 (2026-08-05): #496 the template-language chips + per-language
  // overlay assembly.
  // 800→810 (2026-08-31): #763 the report editor's header help dot.
  'lib/features/money/presentation/widgets/invoice_template_sheet.dart': 1115, // 2026-09-11 #1061 1160→1101: the live-data switch moved to template_live_data.dart // 1180→1160 (2026-09-10): #1056 the app bar's undo/redo pair left for report_history_controls.dart
  'lib/features/money/presentation/widgets/report_field_picker.dart': 353, // 2026-09-06 #966 meanings + topic groups // 2026-09-02 #822 the page, undo/redo, guards // 2026-09-04 #875 layout drafts per kind, the panel mount and its three handlers — the panel and the actions themselves live in their own files // 2026-09-05 #880 the owner-texts drafts per language, merged into every preview/export, and the Texts panel mount
  'lib/features/workspace/domain/workspace_xml.dart': 964, // 2026-09-18 #1289 943→964: the brand-color attribute on <settings>: the schema constant, the field, its parse and its write //
  'lib/features/profile/presentation/screens/new_instance_screen.dart': 492, // 2026-09-17 #1308 S2 486→492: the resume fields read from the project (missing functions, sign-in) and their reset; the read itself lives in instance_readiness.dart; // 2026-09-17 #1308 495→486: the readiness verdict and the run step left for widgets/instance_readiness_card.dart and widgets/instance_run_step.dart; // 2026-09-06 #977 six wizard steps // 2026-09-16 #1393 480→495: the wizard's help symbol — an instance and its bundle are explained in the guide, not on screen
  'lib/features/profile/presentation/screens/backend_screen.dart': 374, // 2026-09-17 #1309 381→374: the instance facts and the reset action left for widgets/server_facts_card.dart; // 2026-09-06 #977 the wizard button // 2026-09-06 #916 schema v3: plan attributes + the configuration section
  // 770→780 (2026-08-04): #452 whole-level rows merge into every seat
  // row — five feature lines, not accretion.
  // 780→810 (2026-09-01): #814 closed columns.
  'lib/features/reservations/presentation/widgets/week_grid.dart': 809, // 2026-09-15 #1273 803→809: singleRoomLevelNames — the label rule and its flag //
  // 750→780 (2026-08-02): #395 adds fetchWorkspaceLedger and
  // fetchPaymentIntents — two new repository surfaces, not accretion.
  // 780→800 (2026-08-04): #454 fetch/setInvoicePdfTemplate.
  // 800→830 (2026-08-04): #472 fetch/setDunningRules.
  // 830→870 (2026-08-05): #488 the report-image library (list/upload/
  // fetch on the floor-plans bucket).
  // 870→890 (2026-08-05): #506 the consumed-payments junction read.
  // 890→900 (2026-08-06): #512 the member_account fetch.
  // 900→980 (2026-08-11): #534 VAT declarations — fetch/save/mark/send
  // repository methods (one cohesive data client, no new concern).
  // 980→1020 (2026-08-14): #568 per-destination gateway probe parse.
  // 600→630 (2026-08-22): #585 seatIdForNfcUid + the nfc_uid column in
  // the seat row mapping.
  'lib/features/plan/data/supabase_floor_plan_repository.dart': 631, // 2026-09-11 #1148/#1150/#1151 review batch: a traced fallback per enum and the feature gates the routes always claimed
  // 1040→1130 (2026-08-31): #767 the six scheduled-expense methods live
  // beside the other money RPC wrappers they mirror.
  // 1130→1150 (2026-09-01): #802 the billing-rules read/write pair and
  // the manual sweep trigger.
  // 1150→1165 (2026-09-01): #804 the settle_invoices call.
  // 1165→1180 (2026-09-01): #816 the rules writers go through gated RPCs.
  // 2026-09-03 #833: three more RPC wrappers (usage records, the
  // early-departure correction, the record removal). This file is one
  // class of thin `_client.rpc` calls; splitting it would put one
  // repository implementation in two places for no gain.
  // 1260→1320 (2026-09-06): #925 three number-sequence methods.
  // 1320→1383 (2026-09-06): #934 two routes / three repository methods.
  // 1393→1420 (2026-09-16): #1310 S2 — four export reads page instead of
  // returning whatever the server's max_rows happened to allow. The cost
  // is structural, not padding: a paged read needs its select inside a
  // `build:` closure, because a PostgREST builder is single-use and the
  // second page would fail on a reused one. Extracting four closures
  // into helpers would move the lines, not remove them, and would put
  // each query a call away from the method that owns it.
  'lib/features/money/data/supabase_money_repository.dart': 1420, // 2026-09-11 #1148/#1150/#1151 review batch: a traced fallback per enum and the feature gates the routes always claimed
  // 600→630 (2026-08-11): #537 VAT price transparency — the gross-price
  // hint + per-pack VAT/currency subtitles (labeling, no new concern).
  // 630→660 (2026-08-11): #537 follow-up — live VAT-share helpers under
  // the band amount fields (default-rate resolver + helper text).
  // 660→700 (2026-08-11): #542 — the tariff's configurable VAT rate
  // (picker, resolution with inactive-rate fallback, immediate save).
  // 700→740 (2026-08-31): #763 thirteen help dots across bands, levels
  // and packages — each beside the field it explains.
  'lib/features/money/presentation/screens/billing_screen.dart': 767, // 2026-09-17 #1279 hosts CarnetsEditor behind the carnets flag (the editor is its own file) 763→767; // 2026-09-08 #1019 thirteen help symbols now name the exact field they document (HelpAnchor), one named argument per symbol
  // 750→880 (2026-08-05): #510 the month-invoice card + settlement-
  // driven balance footer (the invoice decides settled/outstanding).
  'lib/features/money/presentation/widgets/bill_view.dart': 892, // 2026-09-05 #881 member payment conditions: effective terms threaded to every document
  // 600→660 (2026-08-04): #472 the due-reminder flag + emphasized
  // remind action on the open cards.
  // 660→740 (2026-08-05): #504 the partial-open card branch (remaining + write-off).
  // 740→790 (2026-08-05): #508 the credit-note card branch (to-refund + record button).
  // 790→820 (2026-08-05): #510 the summary strip splits to-collect
  // (remaining value) from to-refund.
  // 820→840 (2026-09-01): #812 the Open tab hands over to the journey
  // list (open_invoice_card.dart) while the flag is on.
  // 846→850 (2026-09-16): #1339 — the issue-all button wraps in a
  // Flexible so the header Row stops overflowing at twice the text
  // size. One line of code, one of comment, one of indentation.
  'lib/features/money/presentation/widgets/invoicing_dashboard.dart': 850,
  // 750→770 (2026-08-05): #490 workspace-clock day instants beside the
  // naive axis anchor.
  'lib/features/calendar/presentation/widgets/day_timeline.dart': 776, // 2026-09-15 #1273 772→776: singleRoomLevelNames — the label rule and its flag // // 2026-09-14 #1269 769→772: reading the browsed level from the shared provider instead of its own State field
  // 820→830 (2026-08-25): #622 the whole-space conflict now resolves
  // the blocking RESERVATION (message-the-reserver affordance); the
  // seat action dialog moved OUT into the shared space_act_sheet.
  // 830→980 (2026-08-25): #638 the CONVERGED whole-space sheet — the
  // "For the member" selector and the assign write moved in from the
  // deleted _LevelReserveSheet (plan_screen.dart shrank by more).
  'lib/features/reservations/presentation/widgets/space_scan.dart': 889, // 2026-09-15 #1273 880→886: singleRoomLevelNames — the label rule and its flag //
  // 600→640 (2026-08-04): #460/#464 Messages inbox rows + mark-seen —
  // the note row widget lives with the feed it sits in. 640→700: #467
  // swipe reply/delete on the rows.
  // 700→720 (2026-08-05): #504 the invoice-writeoff event rendering.
  // 720→830 (2026-08-23): #598 feed regrouping — the group-by chip
  // line, the group headers with the ungroup symbol and their labels.
  // 830→850 (2026-08-25): #636 the feed marks an auto-settled deletion
  // (#629) apart from a peer-reviewed one.
  // 850→873 (2026-08-31): #769 the deviated-occurrence feed line names
  // 600→615 (2026-08-31): #769 the two missing domain cards (price
  // negotiation, scheduled expense) joined the pinned card list.
  'lib/features/events/presentation/screens/validation_settings_screen.dart': 298, // 2026-09-14 #1246 437→298: the policy card and its process strip moved to widgets/validation_policy_card.dart, paying for the ellipsis that stops "Übernimmt Standardwert" overflowing a 360 px phone
  // 600→615 (2026-08-31): #771 the kiosk consent exemption and its
  // rationale live where the gate lives.
  // 700→751 (2026-09-06): #934 two routes / three repository methods.
  // 747→757 (2026-09-16): #1277 S3 — /settings/wording: the import and one GoRoute with its
  // feature redirect. The router grows by a route per destination.
  'lib/app/router.dart': 805, // 2026-09-19 #1247 790→805: /attention, its flag redirect and its import — the router grows by a route per destination; // 2026-09-19 #1288 773→790: /settings/questions, its flag redirect and its import; // 2026-09-16 #1312 757→773: the schema gate listens, redirects first and owns /server-update — its rule lives in schema_gate.dart // 2026-09-11 #1120 /library on top of the #1148/#1150/#1151 review batch (745→752) // 2026-09-02 #821/#822/#825/#827 the conversation, report-editor, member and wizard routes // 2026-09-05 #902 /settings/payment-terms // 2026-09-10 #1085 751→730: the nine repeated owner-guard closures became one `needs(...)` helper
  // default→660 (2026-09-06): #934 the status report kind / two flags.
  'lib/features/money/presentation/report_defaults.dart': 628,
  // 600→620 (2026-09-01): #791 the tap dispatcher records the branch it
  // took. The paragraphs explaining WHY each silent branch needs a line
  // were extracted to booking_trace_points.dart; what stayed is eight
  // call sites, on the branches that used to end in nothing at all.
  // 620→680 (2026-09-01): #814 the booking gate before the sheet, the admin check-out.
  'lib/features/reservations/presentation/reserve_seat_actions.dart': 751, // 2026-09-15 #1301 S4 740→751: availabilityKnown on the interface and the tap guard that says "checking" instead of opening a sheet on an unknown day // 2026-09-05 #903 the seat's day: segments for the plan, the timeline behind a shared seat
  // the validated amount and the member's explanation.
  'lib/features/events/presentation/screens/events_screen.dart': 921, // 2026-09-02 #821 mark seen only when showing // 2026-09-05 #881 member payment conditions: effective terms threaded to every document
  // 680→700 (2026-08-04): #454 owner-template intro/footer blocks.
  // 700→790: #470 the banded report renderer (_reportWidgets) and the
  // header/body/footer band branches.
  // 790→820 (2026-08-04): #472 the banded LETTER builder.
  // 820→840 (2026-08-05): #482 the side-by-side ReportColumns renderer.
  // 840→860 (2026-08-05): #488 the ReportImage renderer branch.
  'lib/features/money/domain/invoice_pdf.dart': 1050, // 2026-09-02 #837 per-invoice sheets + annexes // 2026-09-02 #831 source groups + watermark helper // 2026-09-04 #869 page-1 window layout: the geometry and both painted blocks live in address_window.dart; what stays here is the flow restructure itself — the letterhead boxed into the band above the field and the field's own height reserved below it // 2026-09-04 #872 the page model: header on page 1, continuation strip on 2+, footer pinned to every page — three callbacks that ARE this file's contract, so splitting them would hide it // 2026-09-04 #873 window-envelope conformance: the identification block moves out of the letterhead to 90 mm when a window is in use
  'lib/features/money/presentation/widgets/invoice_detail_sheet.dart': 519, // 2026-09-13 #1217 640→530: the action list became widgets/invoice_sheet_actions.dart — it is the half that grows every time an invoice learns a new verb // 2026-09-02 #831 folded banner // 2026-09-02 #822 image size/alignment
  // 670→680 (2026-08-04): #446 out-of-shell WorkHours install — the
  // kiosk arms the ambient working day itself, like realtime (#430).
  // 680→690: #462 whole-space overlays on the wall display.
  // 690→720 (2026-08-08): #519 the period step wiring (sheet call,
  // combined reserve+check-in action, warm granularity).
  // 653→657 (2026-09-16): #1277 S2 — the kiosk installs the workspace's own words on its
  // own route, the same out-of-shell rule as the working day.
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 658, // 2026-09-19 #1289 657→658: the kiosk plan paints the workspace's own room colours // // 2026-09-15 #1273 652→653: singleRoomLevelNames — the label rule and its flag //
  // 600→640 (2026-08-04): #446 fetchWorkHours/setWorkHours — two new
  // repository surfaces (merge-preserving booking_rules writes), not
  // accretion. 640→660: #456 sendMemberNote/fetchMyNotes. 660→690:
  // #458 fetch/setDefaultWorkspaceId. 690→700 (2026-08-05): #480
  // setInvoiceLegal. 700→730 (2026-08-05): #486 setWorkspaceLanguage +
  // setInvitationTemplates.
  // 730→770 (2026-08-05): #500 the document-library reads/writes.
  // 790→800 (2026-08-11): #538 the WhatsApp-mirror config probe (one
  // functions.invoke method — same data client, no new concern).
  // 800→820 (2026-08-11): #542 setSubscriptionVatRate.
  // 820→840 (2026-08-12): #552 setWhatsappChannel + workspace-scoped probe.
  // 840→870 (2026-08-23): #600 fetchBookingPolicies/setBookingPolicy —
  // the same merge-preserving booking_rules write the granularity uses.
  // 870→890 (2026-08-25): #624 setOutsideHoursMode — the policy writes
  // now share ONE private _mergeBookingRule helper.
  // 890→900 (2026-08-25): #628 setSimultaneousReservations (through the
  // SAME _mergeBookingRule helper) + setMemberSimultaneousLimit.
  // 970→1020 (2026-09-06): #937 three platform-owner RPC readers.
  // 1020→1062 (2026-09-06): #948 the entity's numbers on the site sheet.
  // 1089→1109 (2026-09-16): #1274 — generateClosureDays, the definer RPC
  // that carries the owner gate and the invoiced-month rule.
  // 1109→1152 (2026-09-16): #1294 — the new-member defaults and the
  // workspace default period: two readers and two writers, each going
  // through a keyed RPC so the merge stays in the database.
  // 1152→1179 (2026-09-16): #1277 S2 — fetchLexicon and setLexiconTerm: the workspace's own
  // words, read off the row and written one term at a time through the
  // keyed RPC so a second editor cannot revert the first.
  'lib/features/workspace/data/supabase_workspace_repository.dart': 1285, // 2026-09-19 #1289 1242→1281: the emblem's upload, download and removal against the floor-plans bucket, whose policies already scope the workspace prefix // // 2026-09-18 #1289 1229→1242: the branding write (set_workspace_branding) and the branding column on the row mapping // // 2026-09-18 #1307 S4 +1 on top of #1329: the provenance mixin in the with-clause; // 2026-09-18 #1329 1209→1228: setFeatureFlags carries the read-set and maps DK409 to a typed conflict; // 2026-09-17 #1451 1188→1209: saveWorkspaceSettings — one RPC call and its typed conflict; it replaces eight awaited setters on the Save path, which stay for XML import and deployment; // 2026-09-16 #1303 1179→1188: createWorkspace routes a request id and the first template through create_workspace_once; // 2026-09-14 #1269 1074→1089: _updateWorkspaceRow, the one place that reads the row back so an RLS refusal stops looking like a save. Every workspaces-row write is shorter for it; the growth is the helper and the paragraph explaining the 204-with-no-body // 2026-09-11 #1063 the creation flags + #1119 alsoProd // 2026-09-06 #914/#915 the managed identity moves behind its rule: managedIdentityOf + setManagedAccess // 2026-09-05 #887 managed members: identity parse, names from managed_identity, three handover RPCs // 2026-09-08 #1030 an empty member id is dropped from the profile query, with the paragraph saying why one managed member blanked every name // 2026-09-10 #1089 1070→1090: setRolePermission, the single-permission write. The read-modify-write it replaces got SHORTER; the growth is the new method beside the whole-list one, which stays for the import and the deployment. Extracting part of a data-layer repository inside a security fix would be the larger, riskier diff // 2026-09-19 #1550 1281→1285: create_workspace passes what the person asked for (withTwin) to the creation defaults
  // 619→630 (2026-09-16): #1274 — the generateClosureDays contract.
  // 630→654 (2026-09-16): #1294 — four contracts: new-member defaults and
  // the workspace default period, each read and written. An interface
  // grows by a method per capability; there is nothing here to extract.
  // 654→671 (2026-09-16): #1277 S2 — the two lexicon contracts. An interface grows by a
  // method per capability; there is nothing here to extract.
  'lib/features/workspace/domain/workspace_repository.dart': 748, // 2026-09-19 #1281 745→748: setLegendProfile — one interface method for a parameter the plan reads, documented // 2026-09-19 #1289 726→745: the three emblem methods and the paragraph saying why they need no bucket of their own // // 2026-09-18 #1289 715→726: the setWorkspaceBranding contract and the paragraph that says what the server validates // // 2026-09-18 #1307 S4 709→715 on top of #1329: fetchWorkHoursProvenance and resetWorkHoursToDefault, documented; // 2026-09-18 #1329 703→709: the read-set parameter, documented; // 2026-09-17 #1451 696→703: saveWorkspaceSettings, the one-command Save, documented; // 2026-09-17 #1303 S3 692→696: workspaceTemplateOutline — one interface method, what a template sets up before a workspace exists; // 2026-09-17 #1280 S3 686→692: templatePublicationPreview and save's groups — interface only; // 2026-09-17 #1280 S2 681→686: previewWorkspaceTemplate — one interface method (the server computes the change-set), no logic to extract; // 2026-09-16 #1303 671→681: the request id and template parameters, documented; // 2026-09-11 #1120 the library surface of the interface, documented per method (was the 600 default)
  // 600→660 (2026-08-23): #600 the Booking policies section — three
  // switches + one write handler on the existing availability screen.
  // 660→730 (2026-08-25): #624 the outside-hours segmented control +
  // its write handler in the same section.
  // 730→790 (2026-08-25): #628 the simultaneous-reservations stepper —
  // one extracted tile widget + its write handler, same section.
  // 800→810 (2026-08-25): #634 the outside-hours control becomes FOUR
  // radio rows with per-mode subtitles (a four-way SegmentedButton does
  // not fit 360dp) — net of the deleted grid_within_hours switch.
  // 829→852 (2026-09-16): #1274 — the flag-gated entry point to the
  // holiday preview, which hands the sheet its command rather than
  // letting it reach for a repository (ADR 0024). The preview itself is
  // its own widget file.
  'lib/features/workspace/presentation/screens/availability_screen.dart': 856, // 2026-09-19 #1281 854→856: the legend-profile row and its import — the control itself is widgets/legend_profile_tile.dart // 2026-09-17 #1307 S4 852→854: the provenance row and its import — the row itself is widgets/work_hours_provenance_row.dart; // 2026-09-08 #1019 nine help symbols now name the exact rule they document (HelpAnchor), one named argument per symbol
  // 770→790 (2026-08-06): #513 setRolePermissions + role_permissions row.
  // 630→640 (2026-08-10): two-dot month markers (mine + others per day)
  // — a dozen lines of dot layout, no new concern worth a split.
  // 640→690 (2026-08-23): #611 directional month-slide switcher.
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 676,
};

void main() {
  test('no lib/ file outgrows its budget unnoticed', () {
    final over = <String>[];
    final stale = <String>[];

    final seen = <String>{};
    for (final file in handWrittenDartFiles('lib')) {
      seen.add(file.path);
      final count = lineCountOf(file);
      final cap = _baseline[file.path] ?? _budget;
      if (count > cap) {
        over.add('${file.path}: $count lines (cap $cap)');
      }
    }

    for (final path in _baseline.keys) {
      if (!seen.contains(path)) stale.add(path);
    }

    expect(
      over,
      isEmpty,
      reason: 'Over budget:\n${over.join('\n')}\n\n'
          'Extract widgets or split by concern first (see the shared '
          'building blocks in Architecture.md). If growth is genuinely '
          'the right call, raise this file\'s baseline in the same PR and '
          'say why in the PR description — the number changing in review '
          'IS the mechanism.',
    );
    expect(
      stale,
      isEmpty,
      reason: 'Baseline entries for files that no longer exist — delete '
          'them so the ratchet stays honest: ${stale.join(', ')}',
    );
  });
}
