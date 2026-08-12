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
  // 1510→1530 (2026-08-02): #408 presence rule — the sheets moved to
  // check_in_sheets.dart; what remains is the admin-for-others gate and
  // its action/error handling, which need the screen's ref and context.
  // 1530→1550 (2026-08-05): #490 workspace-clock browse machinery.
  'lib/features/plan/presentation/screens/plan_screen.dart': 1550,
  // 1290→1330 (2026-08-02): #395 Excel-export tile — feature lines, the
  // orchestration itself lives in excel_export.dart.
  'lib/features/editor/presentation/screens/level_canvas_screen.dart': 1160,
  // 1010→1020 (2026-08-04): #462 whole-space overlays on the plan view.
  // 1020→1070: #466 the hub's whole-level reserve button + visibility.
  'lib/features/reservations/presentation/screens/reserve_screen.dart': 1070,
  // 980→990 (2026-08-03): #419 workspace dev-mode switch — admin gate,
  // workspace hint subtitle and the RPC write helper.
  // 990→1000 (2026-08-05): #478 Billing & reports admin entry.
  // 1000→1020 (2026-08-05): #486 Payment methods admin entry.
  'lib/features/profile/presentation/screens/settings_screen.dart': 1040,
  // 1020→1040 (2026-08-06): #513 the Role management tile.
  // 980→1030 (2026-08-05): #476 the statement export honors the
  // owner's report template (#478 Invoices button joins the grid).
  // 1030→1070 (2026-08-05): #486 grouped Pay/Requests/Documents actions
  // + the landscape balance card.
  // 1070→1180 (2026-08-05): #494 the self-service document sheet.
  // 1180→1210 (2026-08-05): #496 the member-language chain on self-service docs.
  'lib/features/money/presentation/screens/money_screen.dart': 1220,
  // 1210→1220 (2026-08-06): #512 the account card above the bill.
  // 910→950 (2026-08-04): #456 note tile + admin broadcast button —
  // the dialog itself is its own file.
  // 950→990 (2026-08-05): #494 send-the-agreement action.
  // 990→1020 (2026-08-05): #496 the member-language agreement send.
  'lib/features/workspace/presentation/screens/members_screen.dart': 1020,
  // 900→920 (2026-08-03): #410 admin-visible email line on the member
  // row — the row shares its chip helpers with the detail sheet, so
  // extracting it would drag half the file; 15 feature lines instead.
  // 920→960 (2026-08-04): #456 notify affordance threaded through the
  // row and the sheet.
  'lib/features/members/presentation/screens/directory_screen.dart': 960,
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
  'lib/features/money/presentation/invoice_actions.dart': 1960,
  // 1920→1960 (2026-08-06): #514 quickViewInvoice + the proforma triad.
  // 1910→1920 (2026-08-06): #512 imputation candidates (adjustment
  // credits, baked-credit filter).
  // 1370→1410 (2026-08-05): #494 the engine-based workspace report tile.
  // 1410→1440 (2026-08-05): #496 the language chain on the workspace report.
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart': 1440,
  // 600→640 (2026-08-05): #492 the request-deletion dialog + flow.
  'lib/features/reservations/presentation/widgets/reservation_detail_sheet.dart': 640,
  // 600→660 (2026-08-05): #488 the editor's mode toggle + image insert
  // flow; the visual editor itself is its own file.
  // new→840 (2026-08-05): #498 the WYSIWYG design surface — styled
  // band rendering, column groups, token palette, in-place editor.
  'lib/features/money/presentation/widgets/report_visual_editor.dart': 840,
  // 660→700 (2026-08-05): #494 the three further document chips + their
  // live data and letter-PDF branches.
  // 700→800 (2026-08-05): #496 the template-language chips + per-language
  // overlay assembly.
  'lib/features/money/presentation/widgets/invoice_template_sheet.dart': 800,
  'lib/features/workspace/domain/workspace_xml.dart': 800,
  // 770→780 (2026-08-04): #452 whole-level rows merge into every seat
  // row — five feature lines, not accretion.
  'lib/features/reservations/presentation/widgets/week_grid.dart': 780,
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
  'lib/features/money/data/supabase_money_repository.dart': 980,
  // 600→630 (2026-08-11): #537 VAT price transparency — the gross-price
  // hint + per-pack VAT/currency subtitles (labeling, no new concern).
  // 630→660 (2026-08-11): #537 follow-up — live VAT-share helpers under
  // the band amount fields (default-rate resolver + helper text).
  // 660→700 (2026-08-11): #542 — the tariff's configurable VAT rate
  // (picker, resolution with inactive-rate fallback, immediate save).
  'lib/features/money/presentation/screens/billing_screen.dart': 700,
  // 750→880 (2026-08-05): #510 the month-invoice card + settlement-
  // driven balance footer (the invoice decides settled/outstanding).
  'lib/features/money/presentation/widgets/bill_view.dart': 880,
  // 600→660 (2026-08-04): #472 the due-reminder flag + emphasized
  // remind action on the open cards.
  // 660→740 (2026-08-05): #504 the partial-open card branch (remaining + write-off).
  // 740→790 (2026-08-05): #508 the credit-note card branch (to-refund + record button).
  // 790→820 (2026-08-05): #510 the summary strip splits to-collect
  // (remaining value) from to-refund.
  'lib/features/money/presentation/widgets/invoicing_dashboard.dart': 820,
  // 750→770 (2026-08-05): #490 workspace-clock day instants beside the
  // naive axis anchor.
  'lib/features/calendar/presentation/widgets/day_timeline.dart': 770,
  'lib/features/reservations/presentation/widgets/space_scan.dart': 730,
  // 600→640 (2026-08-04): #460/#464 Messages inbox rows + mark-seen —
  // the note row widget lives with the feed it sits in. 640→700: #467
  // swipe reply/delete on the rows.
  // 700→720 (2026-08-05): #504 the invoice-writeoff event rendering.
  'lib/features/events/presentation/screens/events_screen.dart': 720,
  // 680→700 (2026-08-04): #454 owner-template intro/footer blocks.
  // 700→790: #470 the banded report renderer (_reportWidgets) and the
  // header/body/footer band branches.
  // 790→820 (2026-08-04): #472 the banded LETTER builder.
  // 820→840 (2026-08-05): #482 the side-by-side ReportColumns renderer.
  // 840→860 (2026-08-05): #488 the ReportImage renderer branch.
  'lib/features/money/domain/invoice_pdf.dart': 860,
  // 670→680 (2026-08-04): #446 out-of-shell WorkHours install — the
  // kiosk arms the ambient working day itself, like realtime (#430).
  // 680→690: #462 whole-space overlays on the wall display.
  // 690→720 (2026-08-08): #519 the period step wiring (sheet call,
  // combined reserve+check-in action, warm granularity).
  'lib/features/kiosk/presentation/screens/kiosk_screen.dart': 720,
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
  'lib/features/workspace/data/supabase_workspace_repository.dart': 840,
  // 770→790 (2026-08-06): #513 setRolePermissions + role_permissions row.
  // 630→640 (2026-08-10): two-dot month markers (mine + others per day)
  // — a dozen lines of dot layout, no new concern worth a split.
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 640,
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
