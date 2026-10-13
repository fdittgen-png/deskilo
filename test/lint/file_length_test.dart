// SPDX-License-Identifier: AGPL-3.0-or-later
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
//
// #2121 — layout rule: no two entries on adjacent lines. git reports a
// conflict for changes to ADJACENT lines, so two pull requests raising
// two neighbouring files' budgets used to collide although they had
// nothing in common. A blank line (or a comment) between entries lets
// them merge cleanly; two pull requests raising the SAME file still
// collide, which is right — the combined count needs a new number.
// The last test below holds the layout.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Lines a hand-written lib/ file may have without an entry below.
// #1791 (2026-09-28): existing screen budgets grow only for imports/entries;
// portal implementation remains in separate small widgets. Router and registry
// add the public directory/account destinations and publication flag.
const int _budget = 500; // 2026-10-11 #2386: 600→500 for new files; the files over it are listed below.

/// #2491 — how far above its file's length an entry may sit. Within it the
/// number is headroom for an edit; beyond it the budget has stopped
/// meaning anything (a 2015-line cap on a 507-line file lets the file
/// quadruple unnoticed), and the failing test prints the line to write.
const int _headroom = 20;

/// Grandfathered files at their size when this ratchet landed
/// (2026-08-01), rounded up to the next 10 for edit headroom.
const Map<String, int> _baseline = {
  'lib/features/money/domain/invoice.dart': 518, // 2026-10-12 #2440: the Spanish correction reason (R1-R5) frozen in the parties. 2026-10-11 #2358: the party's electronic address, its scheme and the country subdivision (BT-34/49, BT-39/54), which Peppol, XRechnung and CIUS-RO require.
  // 600→630 (2026-09-20): #1514 — the recording seam. Three of the six
  // providers that answer with a person live here, and each pays four
  // lines: the flag read hoisted above the await (#1218), the
  // substitution, and the sentence saying which personal thing the row
  // carries. The substitution itself is NOT here — it is
  // `recordingMember` in lib/core/privacy/recording_privacy.dart, so
  // the seam stays one file.
  'lib/features/workspace/providers/workspace_providers.dart': 667, // 2026-10-07 #2216 662→667: messageMentionsOn, the one switch both message screens read; 2026-10-04 642→662: resetOnWorkspaceSwitch — the one helper that starts a workspace's session state over when the person moves to another; 2026-10-03 #2137 632→642: actsForReservations, the one staff check the reservation surfaces share (keeps reservations->workspace flat); 2026-10-02 #2085 630→632: myPermissions adds what the workspace's own roles grant, as has_permission has since 0247 — one argument and its import;
  // ADR 0028 (#1373) — the suite's in-memory repositories moved here so
  // Demo can run the real app against them. Their size is the surface of
  // the interface each implements, not a file that grew: MoneyRepository
  // alone is ~90 methods. They are budgeted, so a NEW method still has
  // to be a decision, and they may only shrink.
  'lib/core/demo/data/workspace_repository.dart': 507, // 2026-10-13 #2491 2015→507: the budget follows the file down. 2026-10-11 #2389 2012→2015: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-05 workspace symbol 2010→2012: the letters-and-colour pair is refused when taken (0378); 2026-10-04 2000→2010: the fixture workspaces start from an explicit everyday matrix (three lines). Earlier: 2026-10-03 #1916 1991→2000: the demo twin of set_member_customer_capacity; 2026-10-01 #2051 1942→1991: importClosureDays on the fake — invoiced months, present days and the calls a test reads, the same verdict import_closure_days answers.  2026-09-28 #1652 1889→1942: previewInvitation/joinByInvitation on the fake — the same classification the 0309 functions answer, and the counters the journey tests read to prove a review writes nothing.  2026-09-28 #1791: admission route, comment and expected-account wiring; implementation lives in separate files.  // 2026-09-27 #1658 1865→1885: the fake keeps the request ids a publication used, replays a retry and loses one answer on demand, the same contract the real function keeps; // 2026-09-25 #1655 1840→1865: inspectWorkspaceTemplate on the fake — the seeded map and the default built from the outline, the same shape as templateOutlines; // 2026-09-19 #1281 1827→1830: setLegendProfile, the fake's mirror of the booking-rule write // 2026-09-19 #1373 moved out of test/helpers/mock_providers.dart, which is 2358→408 lines // 2026-09-25 #1650 1830→1840: fetchFailure — the one knob that lets a test say the membership list could not be FETCHED, as opposed to being empty; // 2026-09-19 #1281 1827→1830: setLegendProfile, the fake's mirror of the booking-rule write // 2026-09-19 #1373 moved out of test/helpers/mock_providers.dart, which is 2358→408 lines

  'lib/features/task_recorder/domain/action_registry.dart': 620, // 2026-10-04 #1884 B 600→620: the management-form actions and outcomes (permission, role, validation rule) join the registry.


  'lib/core/demo/data/reservation_repository.dart': 760, // 2026-10-03 #1855 700→760: the fake mirrors the server's request claim (same id → the original booking, a changed payload refused by name, a lost answer after a commit) and the own-result lookup; // 2026-09-19 #1562 695→700: convertToSeries takes the chosen window, and says why it is not the stored one // 2026-09-19 #1565 678→695: the signed-in member is READ on every call instead of captured once, so a Demo persona switch re-attributes the bookings that follow it — the constructor seam, the getter and the paragraph saying why // 2026-09-19 #1373 moved from test/helpers/fake_reservation_repository.dart

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
  'lib/features/workspace/presentation/screens/members_screen.dart': 559, // 2026-10-09 #2313 537→559: every control keyed for the task recorder; 2026-10-02 #2085 520→537: the sheet's "Add a role" action behind roleAssignment, beside the Administrator row it replaces when the flag is on;
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
  'lib/features/money/presentation/invoice_documents.dart': 644, // 2026-10-13 #2360: the Swiss QR-bill page is asked for and handed to both renderers. 2026-10-11 #2389 630→632: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-03 #1916 614→630: memberCapacityFor and the frozen BT-20 payment terms; 2026-10-02 #1913 610→614: the printed due date reads the date frozen at issue first. 2026-09-11 #1061 born from the invoice_actions split: the PDF/e-invoice builders and the letter pipeline

  'lib/features/money/presentation/accounting_export.dart': 505, // 2026-10-13 #2360: the Swiss booking journal is one more export case.

  // 2026-09-05 #919 an association is steered off the exempt scheme:
  // the regime that demands a VAT number it cannot have.
  'lib/features/money/presentation/screens/legal_identity_screen.dart': 677, // 2026-10-11 #2388 676→677: the import of context.l10n. // 2026-10-11 #2357 661→676: the declaration period is stored with the legal identity (state, load, save, the self-gating widgets/vat_declaration_period_field.dart); 2026-10-10 #2355 676→661: the VAT tax-point selector moved to widgets/vat_tax_point_field.dart; 2026-10-09 #2313 675→676: every control keyed for the task recorder; 2026-10-03 #1916 656→675: the default customer capacity selector; the association-only clause hint is gone; 2026-09-02 #837 the annex question // 2026-09-04 #871 the bank block: IBAN/BIC/bank name reach a designed report, resolved once in legalMentionData for every document // 2026-09-04 #875 layout-wins hooks + the strings/features hoists they need; the engine itself lives under domain/report_layout // 2026-09-05 #886 the client identity (name, company, contacts, postal block) resolved for every document and frozen on the proforma // 2026-09-05 #881 member payment conditions: effective terms threaded to every document // 2026-09-05 #880 owner texts beside #881 member terms after the rebase // 2026-09-05 #910 the client name falls back to the company and the settlement date reaches the document: invoiceDueAt + the due_date placeholder threaded through every render // 2026-09-05 #917 the development watermark, resolved where the workspace is already at hand, and carried to every report through the shared letter funnel // 2026-09-06 #922 the two Chorus Pro references as placeholders, and the government destination on the pre-flight check // 2026-09-08 #1019 eighteen help symbols now name the exact field they document (HelpAnchor), one named argument per symbol
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
  'lib/core/help/help_anchors.dart': 515, // 2026-10-13 #2491 651→515: the budget follows the file down. 2026-09-18 #1289 650→651: the colours anchor — this file IS the anchor registry and grows by one entry per documented surface
  // 600→660 (2026-08-05): #488 the editor's mode toggle + image insert
  // flow; the visual editor itself is its own file.
  // new→840 (2026-08-05): #498 the WYSIWYG design surface — styled
  // band rendering, column groups, token palette, in-place editor.
  // #825 (2026-09-02): the member page and the shared admin actions.
  // 900→948 (2026-09-06): #945 sites.
  'lib/features/members/presentation/screens/member_page.dart': 758, // 2026-10-13 #2491 970→758: the budget follows the file down. 2026-10-03 #2137 966→970: "Add a service" also for manageServices, as record_service_charge accepts it;  2026-10-03 #1916 955→966: the Customer capacity row (the dialog is workspace/presentation/member_customer_capacity.dart); 2026-10-02 #2085 947→955: hosts MemberRolesCard behind roleAssignment and hides the single Administrator row it replaces; the card itself is workspace/presentation/widgets/member_roles_card.dart;  2026-09-17 #1279 hosts MemberCarnetTile behind the carnets flag (the tile is its own file) 944→947; // 2026-09-05 #887 the managed-member tiles (edit identity, hand over, revoke) + chip
  // 720→779 (2026-09-06): #945 sites.
  'lib/features/workspace/presentation/widgets/conversation_thread.dart': 653, // 2026-10-11 #2389 651→653: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-09 #2313 648→651: every control keyed for the task recorder; 2026-10-07 #2216 646→648: the group mention picker names people by id and my own mentions stand out; 2026-10-06 messenger: reactions, stars, edits, group posting rules and @mentions are read and drawn here — the thread is the one place that knows the roster and the marks.

  'lib/features/directory/presentation/messenger/context_thread_screen.dart': 631, // 2026-10-09 #2313 629→631: every control keyed for the task recorder; 2026-10-07 #2216 620→629: cross-workspace groups get the mention picker: the members other than me, by account; 2026-10-06 groups of people: the thread asks which workspaces every member shares, closes posting in an announcement-only group and opens the group sheet.

  'lib/features/workspace/presentation/member_admin_actions.dart': 697, // 2026-10-13 #2491 780→697: the budget follows the file down. 2026-09-11 #1061 779→780: one import, the letter builders' new home
  // #828 (2026-09-02): the expense_repartition flag and repository methods.
  // 2026-09-04 #864: one more flag. This file is the feature
  // registry — it grows by ~5 lines per flag by design, and
  // splitting the registry would defeat its whole purpose.
  // 740→789 (2026-09-06): #934 the status report kind and the money-screen tiles.
  // 1264→1273 (2026-09-16): #1274 publicHolidays — the registry grows
  // by an enum value and a manifest entry per flag, by design.
  // 1273→1284 (2026-09-16): #1277 S2 — the workspaceVocabulary flag: one enum value and one
  // manifest entry. The registry grows by a flag per functionality.
  'lib/features/workspace/domain/workspace_feature.dart': 614, // 2026-10-13 #2484 611→614: the configurableSettings enum value and its doc line (a flag's enum value goes here). // 2026-10-11 #2386 1684→611: the manifest's entries moved to feature_manifest_part1..3.dart (data); a new flag's entry goes at the end of the last part, its enum value here.

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
  'lib/features/plan/data/supabase_floor_plan_repository.dart': 714, // 2026-10-05 #2011 +3: fetchTargetNames pages its three tables through one local helper; 2026-10-02 #2012 B 698→711: every successful plan-media write runs the bounded orphan sweep (0332 plan_media_orphans; the sweep itself lives in plan_media_sweep.dart). 2026-10-01 #2012 B 697→698: a plan image is uploaded before its row exists and created under the operation's id, so a retry converges on one image. 2026-10-01 #2011 673→697: levels, offices, desks, seats and images read to the end (fetchAllPages / fetchAllIn), totally ordered. 2026-10-01 #2012 636→673: background and plan-image writes go through PlanMediaSteps (new object per upload, reference before removal, no pending row left by a failed upload). 2026-10-01 #2010 631→636: the level reorder is one atomic RPC with its expected order and outcome, and the site change busts the cache. 2026-09-11 #1148/#1150/#1151 review batch: a traced fallback per enum and the feature gates the routes always claimed
  // 600→630 (2026-08-11): #537 VAT price transparency — the gross-price
  // hint + per-pack VAT/currency subtitles (labeling, no new concern).
  // 630→660 (2026-08-11): #537 follow-up — live VAT-share helpers under
  // the band amount fields (default-rate resolver + helper text).
  // 660→700 (2026-08-11): #542 — the tariff's configurable VAT rate
  // (picker, resolution with inactive-rate fallback, immediate save).
  // 700→740 (2026-08-31): #763 thirteen help dots across bands, levels
  // and packages — each beside the field it explains.
  'lib/features/money/presentation/screens/billing_screen.dart': 736, // 2026-10-13 #2491 781→736: the budget follows the file down. 2026-10-09 #2313 767→781: every control keyed for the task recorder; 2026-09-17 #1279 hosts CarnetsEditor behind the carnets flag (the editor is its own file) 763→767; // 2026-09-08 #1019 thirteen help symbols now name the exact field they document (HelpAnchor), one named argument per symbol
  // 600→615 (2026-08-31): #771 the kiosk consent exemption and its
  // rationale live where the gate lives.
  // 700→751 (2026-09-06): #934 two routes / three repository methods.
  // 747→757 (2026-09-16): #1277 S3 — /settings/wording: the import and one GoRoute with its
  // feature redirect. The router grows by a route per destination.
  'lib/app/router.dart': 959, // 2026-10-11 #2388 957→959: the pages opened over another screen register here (one line) and import page_routes.dart; #2386 splits the router by feature. // 2026-10-11 #2389 955→957: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-11 954→955: a router whose provider was rebuilt answers "stay" instead of reading a disposed ref (the guide's embedded app threw). // #2301: Reports destination reuses existing exports (2026-10-09). // 2026-10-06 calendar holds the alerts +11: /messages and /events open the calendar hub, with the request that selects its Alerts view; 2026-10-04 task wizard 930→936: its route and import. 2026-10-04 915→930: the one permission door (route_access.dart) in the redirect. 2026-10-03 #2142 910→915: the task recorder's window observer and its import. 2026-10-03 #2145 904→910: /assistants/connect appended last, its mcpAccess redirect and import. // 2026-10-02 #1872 900→904: the /task-workbench route appended last and its import. // 2026-10-02 #1865 892→900: the /task-recorder route appended last and its two imports. // 2026-10-02 #1923 877→892: the /bi route, web-only and gated by the BI registry before any fetch, and its imports. // 2026-10-02 #1827 B 870→877: the instance operator's assistant console route (/installation/assistants). 2026-10-02 #1914 869→870: the consent gate asks for the version the server publishes — one listen line.  2026-10-02 #2085 859→869: /settings/what-you-can-do, its roleAssignment redirect and the member query parameter;  2026-10-01 #1827+#1823 merge 851→859: /settings/assistant-setup, its manageIntegrations redirect, comment and import — a route per destination.  2026-09-29 #1823 856→851: /me, the chosen-space fact and its listen — paid for by the three fact builders that moved into route_policy.dart as pure helpers; 2026-09-28 #1652 843→856: an invitation link opened from outside leaves the location at once for the join field; /server takes an invitation's candidate.  2026-09-28 #1791: admission route, comment and expected-account wiring; implementation lives in separate files.  // 2026-09-26 #1615/#1626/#1627/#1628 805→827: four assistant routes, the owner redirect on /settings/assistants and their imports — a route per destination; // 2026-09-19 #1247 790→805: /attention, its flag redirect and its import — the router grows by a route per destination; // 2026-09-19 #1288 773→790: /settings/questions, its flag redirect and its import; // 2026-09-16 #1312 757→773: the schema gate listens, redirects first and owns /server-update — its rule lives in schema_gate.dart // 2026-09-11 #1120 /library on top of the #1148/#1150/#1151 review batch (745→752) // 2026-09-02 #821/#822/#825/#827 the conversation, report-editor, member and wizard routes // 2026-09-05 #902 /settings/payment-terms // 2026-09-10 #1085 751→730: the nine repeated owner-guard closures became one `needs(...)` helper
  // default→660 (2026-09-06): #934 the status report kind / two flags.
  'lib/features/money/presentation/report_defaults.dart': 637, // 2026-10-11 #2389 635→637: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-11 #2384 632→635: @visibleForTesting on the symbols its tests read; #2003 configuration and BI kind registrations.
  // 600→620 (2026-09-01): #791 the tap dispatcher records the branch it
  // took. The paragraphs explaining WHY each silent branch needs a line
  // were extracted to booking_trace_points.dart; what stayed is eight
  // call sites, on the branches that used to end in nothing at all.
  // 620→680 (2026-09-01): #814 the booking gate before the sheet, the admin check-out.
  'lib/features/reservations/presentation/widgets/booking_sheet.dart': 644, // 2026-10-11 #2389 643→644: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-08 #2272: scroll frame and review move to booking_review_summary.dart.  // 2026-10-04 #2185 650→656: the seat's favourite heart and rating bar sit in the sheet; 2026-10-02 #1865 629→650: onFieldCommitted: which field was committed, never its value, for the task recorder; 2026-10-01 #2016 600→629: Reserve / Check in now as explicit modes (the reservation draft kept while the walk-up is looked at, the walk-up's own cap, the check-in-right-away switch following the edited window); the selector, overlap notice and time/date tiles moved to booking_sheet_parts.dart.

  'lib/features/reservations/presentation/reserve_seat_actions.dart': 834, // 2026-10-10 #2328 825→834: my seat sheet offers cancel or request deletion by the same rule as the booking's detail sheet, and files the request; 2026-10-06 task recorder values +5: the booking's window and resource are handed to the recorder as typed values (opt-in per recording); 2026-10-03 #1855 +23: the plain booking goes through the durable intent; a lost answer opens the recovery sheet; 2026-10-02 #1881 786→797: the recorder seams for check-in, check-out, cancel and close on my reservation; 2026-10-02 #1865 765→786: the task recorder attempt before the booking command and its outcome after, the cancel and the field-commit hook; 2026-10-01 #2016 T08 +3: a sheet choice made before a workspace switch is dropped. 2026-10-01 #2016 720→762: the live free-seat tap OFFERS the walk-up (its own window and cap beside the reservation's), opens when either action is allowed, and writes the action confirmed in the sheet; the overlap check for the edited window.  2026-09-28 #1813 751→720: someone else's booking moved to the part file others_booking_tap.dart, so a seat-day row and a seat tap share it // 2026-09-15 #1301 S4 740→751: availabilityKnown on the interface and the tap guard that says "checking" instead of opening a sheet on an unknown day // 2026-09-05 #903 the seat's day: segments for the plan, the timeline behind a shared seat
  // the validated amount and the member's explanation.
  'lib/features/events/presentation/screens/events_screen.dart': 624, // 2026-10-13 #2491 921→624: the budget follows the file down. 2026-09-02 #821 mark seen only when showing // 2026-09-05 #881 member payment conditions: effective terms threaded to every document

  'lib/features/money/presentation/widgets/invoice_detail_sheet.dart': 542, // 2026-10-02 #1922 540→542: the reminder history line and its import; the list lives in reminder_evidence_list.dart. 2026-10-02 #1913 519→540: the hold and the unreviewed-term notes for the issuer, and the held reason handed to the action list. 2026-09-13 #1217 640→530: the action list became widgets/invoice_sheet_actions.dart — it is the half that grows every time an invoice learns a new verb // 2026-09-02 #831 folded banner // 2026-09-02 #822 image size/alignment
  // 670→680 (2026-08-04): #446 out-of-shell WorkHours install — the
  // kiosk arms the ambient working day itself, like realtime (#430).
  // 680→690: #462 whole-space overlays on the wall display.
  // 690→720 (2026-08-08): #519 the period step wiring (sheet call,
  // combined reserve+check-in action, warm granularity).
  // 653→657 (2026-09-16): #1277 S2 — the kiosk installs the workspace's own words on its
  // own route, the same out-of-shell rule as the working day.
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 658, // 2026-09-19 #1289 657→658: the kiosk plan paints the workspace's own room colours // // 2026-09-15 #1273 652→653: singleRoomLevelNames — the label rule and its flag //
  // 619→630 (2026-09-16): #1274 — the generateClosureDays contract.
  // 630→654 (2026-09-16): #1294 — four contracts: new-member defaults and
  // the workspace default period, each read and written. An interface
  // grows by a method per capability; there is nothing here to extract.
  // 654→671 (2026-09-16): #1277 S2 — the two lexicon contracts. An interface grows by a
  // method per capability; there is nothing here to extract.
  'lib/features/workspace/domain/workspace_repository.dart': 797, // 2026-10-11 #2358 787→797: the customer's e-invoicing address setter. // 2026-10-11 #2389 786→787: the stricter lints — cascades one section per line, reasoned ignores, if-elements. 2026-10-03 #1916 781→786: setMemberCustomerCapacity; 2026-10-01 #2051 772→781: importClosureDays, documented.  2026-09-28 #1652 761→772: previewInvitation and joinByInvitation, documented.  2026-09-27 #1658 756→761: saveWorkspaceAsTemplate's requestId and what a retry and a conflict mean; // 2026-09-25 #1655 748→756: inspectWorkspaceTemplate — one interface method, documented, for the field-level inspection the confirm step reads; // 2026-09-19 #1281 745→748: setLegendProfile — one interface method for a parameter the plan reads, documented // 2026-09-19 #1289 726→745: the three emblem methods and the paragraph saying why they need no bucket of their own // // 2026-09-18 #1289 715→726: the setWorkspaceBranding contract and the paragraph that says what the server validates // // 2026-09-18 #1307 S4 709→715 on top of #1329: fetchWorkHoursProvenance and resetWorkHoursToDefault, documented; // 2026-09-18 #1329 703→709: the read-set parameter, documented; // 2026-09-17 #1451 696→703: saveWorkspaceSettings, the one-command Save, documented; // 2026-09-17 #1303 S3 692→696: workspaceTemplateOutline — one interface method, what a template sets up before a workspace exists; // 2026-09-17 #1280 S3 686→692: templatePublicationPreview and save's groups — interface only; // 2026-09-17 #1280 S2 681→686: previewWorkspaceTemplate — one interface method (the server computes the change-set), no logic to extract; // 2026-09-16 #1303 671→681: the request id and template parameters, documented; // 2026-09-11 #1120 the library surface of the interface, documented per method (was the 600 default)
  // 770→790 (2026-08-06): #513 setRolePermissions + role_permissions row.
  // 630→640 (2026-08-10): two-dot month markers (mine + others per day)
  // — a dozen lines of dot layout, no new concern worth a split.
  // 640→690 (2026-08-23): #611 directional month-slide switcher.
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 726, // 2026-10-09 #2313 717→726: every control keyed for the task recorder; 2026-10-05 #1848 +5: a failed month read shows the unavailable banner instead of 'no reservations'; 2026-10-05 UX redesign 710→712: the side panel is for a phone held sideways only (app_frame.dart); 2026-10-03 #1881 B 676→710: the task recorder's seams — month steps, whose calendar, list/timeline, the chosen day, and the cancel's attempt and real result.

  'lib/features/calendar/presentation/screens/calendar_hub_screen.dart': 658, // 2026-10-06 calendar holds the alerts +43: the Alerts view, its request listener, the switcher's fourth segment and the alert row opening it in place; 2026-10-05 UX redesign 613→615: the side panel is for a phone held sideways only (app_frame.dart); 2026-10-03 #1881 B 600→613: the task recorder's seams — view, step, day, kind filter, whose calendar and the opened row's kind.
  // 2026-09-28 #1791: one import for the separately implemented account requests entry.
  'lib/features/workspace/presentation/screens/onboarding_screen.dart': 637, // 2026-10-09 #2313 633→637: every control keyed for the task recorder; 2026-09-28 #1652 602→633: Join is selected by an invitation errand, a link the app was opened with, or an invitation kept for this server; the join journey itself moved to widgets/invitation_join_panel.dart.

  'lib/app/shell/shell_screen.dart': 507, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/backend/backend_settings.dart': 572, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/backend/secondary_federation.dart': 576, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/demo/data/messenger_repository.dart': 590, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/instance/instance_doctor.dart': 508, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/instance/mcp_readiness_checks.dart': 554, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/core/mcp/mcp_operations.dart': 590, // #2394: +2, it re-exports the generated enum and envelope. #2386: the budget fell 600→500. #2391: get_member_statement and each operation's group are generated here.

  'lib/core/ui/canvas_controls.dart': 504, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/auth/data/supabase_auth_repository.dart': 581, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/auth/presentation/screens/auth_screen.dart': 595, // 2026-10-12 #2459: +5 for the welcome link (import + the Wrap beside Discover); was 590 (2026-10-11 #2386: the budget fell 600→500; this file was within the old one).

  'lib/features/directory/data/supabase_messenger_repository.dart': 507, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/directory/domain/messenger.dart': 506, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.




  'lib/features/money/domain/fec.dart': 590, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/domain/invoice_pdf_part2.dart': 801, // 2026-10-13 #2360: the invoice takes the QR-bill page as its second sheet. 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/domain/invoice_pdf_template.dart': 568, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/domain/money_repository.dart': 610, // 2026-10-12 #2440: createInvoice and invoiceIssueReadiness take the correction reason. 2026-10-11 #2358 587→598: the send names the syntax and the receiver; the receipt request joins the interface. #2357 +7: setExpenseScheduleVat. 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/domain/saf_t.dart': 511, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/domain/vat_tax_point.dart': 544, // 2026-10-11 #2384 540→544: @visibleForTesting on the declarations only tests read, and its import; 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/presentation/screens/my_finances_screen.dart': 574, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/presentation/screens/vat_declarations_screen.dart': 587, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/presentation/screens/vat_screen.dart': 572, // 2026-10-12 #2360: a decided change of rate comes prefilled in Change by law. 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/presentation/widgets/expense_schedule_sheet.dart': 576, // 2026-10-11 #2357 557→576: the schedule asks the VAT its occurrences carry (expense_vat_fields.dart, shared with the expense sheet). 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/presentation/widgets/invoice_form_sheet.dart': 552, // 2026-10-13 #2361: the Canadian BN and QST number refusals have their messages. 2026-10-12 #2360: the Swiss UID refusal has its message. 2026-10-12 #2359: the sterling VRN refusal has its message. 2026-10-12 #2440: the correction reason joins readiness and the result (the field itself is its own file). 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/money/providers/money_providers.dart': 601, // 2026-10-13 #2484 588→601: the dunning rules provider reads the workspace's settings snapshot for the first reminder's delay (a setting now). // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/application/recorder_controller.dart': 548, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/domain/task_recording_decoder.dart': 570, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/export/docx/docx_writer.dart': 524, // 2026-10-11 #2384 520→524: @visibleForTesting on the declarations only tests read, and its import; 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/package/task_package.dart': 592, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/presentation/screens/task_wizard_screen.dart': 568, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/task_recorder/presentation/ui_capture.dart': 592, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/domain/template_capabilities.dart': 588, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': 565, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/bi_charts.dart': 509, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/bi_views_bar.dart': 514, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/member_note_composer.dart': 598, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/ref_picker_sheet.dart': 501, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.

  'lib/features/workspace/presentation/widgets/template_gallery.dart': 559, // 2026-10-11 #2386: the budget fell 600→500; this file was within the old one.
};

void main() {
  test('no lib/ file outgrows its budget unnoticed', () {
    final over = <String>[];
    final stale = <String>[];
    final loose = <String>[];

    final seen = <String>{};
    for (final file in handWrittenDartFiles('lib')) {
      seen.add(file.path);
      final count = lineCountOf(file);
      final cap = _baseline[file.path] ?? _budget;
      if (count > cap) {
        over.add('${file.path}: $count lines (cap $cap)');
      }
      if (_baseline.containsKey(file.path) && cap > count + _headroom) {
        loose.add(count <= _budget
            ? "${file.path}: $count lines, under the default budget of "
                "$_budget — delete its entry"
            : "  '${file.path}': $count, // $cap→$count");
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
      loose,
      isEmpty,
      reason: 'Budgets more than $_headroom lines above their file — the '
          'budget follows the file down (#2491). Write these lines:\n'
          '${loose.join('\n')}',
    );
    expect(
      stale,
      isEmpty,
      reason: 'Baseline entries for files that no longer exist — delete '
          'them so the ratchet stays honest: ${stale.join(', ')}',
    );
  });

  test('no two budget entries sit on adjacent lines (#2121)', () {
    final lines = File('test/lint/file_length_test.dart').readAsLinesSync();
    final start = lines.indexWhere((l) => l.contains('_baseline = {'));
    final end = lines.indexWhere((l) => l.startsWith('};'), start);
    final entry = RegExp(r"^\s*'[^']+\.dart':\s*\d+");
    final adjacent = <String>[
      for (var i = start + 1; i < end - 1; i++)
        if (entry.hasMatch(lines[i]) && entry.hasMatch(lines[i + 1]))
          'lines ${i + 1}-${i + 2}',
    ];
    expect(adjacent, isEmpty,
        reason: 'put a blank line between these budget entries: adjacent '
            'lines conflict whenever two pull requests raise neighbours');
    expect(start, greaterThan(0));
  });
}
