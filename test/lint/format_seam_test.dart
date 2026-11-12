// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1150, #3484 — every number, amount, date and time a member reads goes
// through `AppFormat` (`ref.watch(appFormatProvider)`, or
// `appFormatOf(context)` without a ref): it is the one place that knows the
// member's format locale, clock (12/24h) and time-zone mode. A raw
// `DateFormat.Hm()` shows 14:30 to somebody who chose a 12-hour clock; a raw
// `.toLocal()` shows the device's zone to somebody who chose the workspace's.
//
// The raw calls left in presentation are COUNTED: each ceiling is the
// measure recorded before #3484's sweeps, and it only goes down. `Hm` and
// `jm` are at 0 since #1150.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// #3484 — files that format on purpose outside the member's seam: the
/// number of raw calls (the five patterns below, together) each may hold,
/// and its reason — a machine key, a document printed in its own locale, a
/// label baked into stored text in another language. The count only falls.
const _allowed = <String, (int, String)>{
  'lib/features/money/presentation/bank_reconciliation_actions.dart': (
    2,
    "a document: the reconciliation report prints in the document's locale",
  ),
  'lib/features/money/presentation/bank_reconciliation_archive.dart': (
    2,
    "a document: the reconciliation archive prints in the document's locale",
  ),
  'lib/features/money/presentation/book_report_actions.dart': (
    2,
    "a document: the book reports print in the document's locale",
  ),
  'lib/features/money/presentation/gobd_procedure_document.dart': (
    2,
    "a document: the GoBD procedure document prints in its own language",
  ),
  'lib/features/money/presentation/invoice_documents.dart': (
    2,
    "a document: the invoice files print in the document's locale",
  ),
  'lib/features/money/presentation/invoice_pdf_file_parts.dart': (
    1,
    "a document: the invoice PDF prints in the document's locale",
  ),
  'lib/features/money/presentation/purchase_order_print.dart': (
    3,
    "a document: the purchase order prints in the document's locale",
  ),
  'lib/features/money/presentation/screens/money_screen_ops.dart': (
    0,
    "a machine key: the yyyy-MM period sent to the server",
  ),
  'lib/features/money/presentation/status_report_data.dart': (
    2,
    "a document: the status report prints in the document's locale",
  ),
  'lib/features/money/presentation/usage_report_data.dart': (
    3,
    "a document: the usage report prints in the document's locale",
  ),
  'lib/features/money/presentation/vat_report_actions.dart': (
    2,
    "a document: the VAT report prints in the document's locale",
  ),
  'lib/features/profile/presentation/screens/developer_screen.dart': (
    1,
    "machine stamps: file names and the raw developer log, never a member-facing date",
  ),
  'lib/features/workspace/presentation/bi_print_strings_l10n.dart': (
    4,
    "a document: the printed analytics in the document's locale",
  ),
  'lib/features/workspace/presentation/config_pdf_lines.dart': (
    4,
    "a document: the configuration PDF prints in the document's locale",
  ),
  'lib/features/workspace/presentation/screens/workspace_settings_backup.dart': (
    1,
    "a document: the space-code sheet's cover prints its issue date",
  ),
  'lib/features/workspace/presentation/screens/workspace_settings_reports.dart': (
    2,
    "a document: the configuration report prints its generation date",
  ),
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': (
    1,
    "a document: the badge sheet's cover prints its issue date",
  ),
  'lib/features/workspace/presentation/widgets/bi_customer_views.dart': (
    3,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_dashboard_content.dart': (
    3,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_export.dart': (
    2,
    "a document: the analytics export's issue date prints in the document's locale",
  ),
  'lib/features/workspace/presentation/widgets/bi_module_section.dart': (
    5,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_overview_views.dart': (
    5,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_purchase_views.dart': (
    4,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_toolbar.dart': (
    1,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/bi_vendor_views.dart': (
    2,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/capacity_evidence.dart': (
    2,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/capacity_kpi_card.dart': (
    5,
    "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  ),
  'lib/features/workspace/presentation/widgets/holiday_import_sheet.dart': (
    1,
    "a machine key: the ISO day a holiday is matched by, never shown",
  ),
  'lib/features/workspace/presentation/widgets/note_record_choices.dart': (
    4,
    "a baked label: the reference a note carries is written in the note's language, stored as text",
  ),
  'lib/features/workspace/presentation/workspace_data_report_strings.dart': (
    4,
    "a document: the workspace data report prints in the document's locale",
  ),
};

/// The ceilings: 0 since #3484's sweeps (recorded before them: DateFormat. 141,
/// NumberFormat. 31, moneyFormat( 93, .toLocal() 42, WorkspaceTime.display 8).
const _ceilings = <String, int>{
  'DateFormat.': 0,
  'NumberFormat.': 0,
  'moneyFormat(': 0,
  '.toLocal()': 0,
  'WorkspaceTime.display': 0,
};

final _kinds = [
  LiteralKind('DateFormat.', RegExp(r'\bDateFormat\.')),
  LiteralKind('NumberFormat.', RegExp(r'\bNumberFormat\.')),
  LiteralKind('moneyFormat(', RegExp(r'\bmoneyFormat\(')),
  LiteralKind('.toLocal()', RegExp(r'\.toLocal\(\)')),
  LiteralKind('WorkspaceTime.display', RegExp(r'\bWorkspaceTime\.display\b')),
];

void main() {
  final presentation = filesUnder(['lib/features']).where(
    (f) =>
        f.path.contains('/presentation/') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart') &&
        !_allowed.containsKey(f.path),
  );

  test('every allowed file exists, says why and holds its pinned count', () {
    for (final MapEntry(key: path, value: (pinned, why)) in _allowed.entries) {
      expect(File(path).existsSync(), isTrue, reason: '$path is gone: drop it');
      expect(why.trim(), isNotEmpty, reason: path);
      final counted = countLiterals([File(path)], _kinds);
      final n = counted.values.fold(0, (s, perFile) => s + total(perFile));
      expect(n, pinned,
          reason: '$path: $n raw format calls, pinned at $pinned. A new one '
              'goes through AppFormat; a removed one lowers the pin.');
    }
  });

  test('presentation never formats a time with DateFormat.Hm or .jm', () {
    final counted = countLiterals(presentation, [
      LiteralKind('Hm/jm', RegExp(r'DateFormat\.(Hm|jm)\(')),
    ])['Hm/jm']!;
    expect(total(counted), 0,
        reason: 'use AppFormat.time() — ref.watch(appFormatProvider) or '
            'appFormatOf(context):\n${counted.keys.join('\n')}');
  });

  final counted = countLiterals(presentation, _kinds);
  for (final kind in _kinds) {
    test('raw "${kind.name}" calls in presentation only fall', () {
      final perFile = counted[kind.name]!;
      final ceiling = _ceilings[kind.name]!;
      expect(
        total(perFile),
        ceiling,
        reason: ratchetMessage(
          rule: 'format seam (#3484): format through AppFormat '
              '(ref.watch(appFormatProvider) or appFormatOf(context))',
          kind: kind.name,
          ceiling: ceiling,
          actual: total(perFile),
          perFile: perFile,
        ),
      );
    });
  }
}
