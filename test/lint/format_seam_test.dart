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

/// #3484 — files that format on purpose outside the member's seam, each
/// with its reason: a machine key, a document printed in its own locale, a
/// label baked into stored text in another language. Every pattern below is
/// allowed there; nowhere else.
const _allowed = <String, String>{
  'lib/features/money/presentation/bank_reconciliation_actions.dart':
      "a document: the reconciliation report prints in the document's locale",
  'lib/features/money/presentation/bank_reconciliation_archive.dart':
      "a document: the reconciliation archive prints in the document's locale",
  'lib/features/money/presentation/book_report_actions.dart':
      "a document: the book reports print in the document's locale",
  'lib/features/money/presentation/gobd_procedure_document.dart':
      "a document: the GoBD procedure document prints in its own language",
  'lib/features/money/presentation/invoice_documents.dart':
      "a document: the invoice files print in the document's locale",
  'lib/features/money/presentation/invoice_pdf_file_parts.dart':
      "a document: the invoice PDF prints in the document's locale",
  'lib/features/money/presentation/purchase_order_print.dart':
      "a document: the purchase order prints in the document's locale",
  'lib/features/money/presentation/screens/money_screen_ops.dart':
      "a machine key: the yyyy-MM period sent to the server",
  'lib/features/money/presentation/status_report_data.dart':
      "a document: the status report prints in the document's locale",
  'lib/features/money/presentation/usage_report_data.dart':
      "a document: the usage report prints in the document's locale",
  'lib/features/money/presentation/vat_report_actions.dart':
      "a document: the VAT report prints in the document's locale",
  'lib/features/profile/presentation/screens/developer_screen.dart':
      "machine stamps: file names and the raw developer log, never a member-facing date",
  'lib/features/reservations/presentation/widgets/message_reserver.dart':
      "a baked label: the message to a reserver is written in the space's reference language, stored as text",
  'lib/features/workspace/presentation/bi_print_strings_l10n.dart':
      "a document: the printed analytics in the document's locale",
  'lib/features/workspace/presentation/config_pdf_lines.dart':
      "a document: the configuration PDF prints in the document's locale",
  'lib/features/workspace/presentation/screens/workspace_settings_backup.dart':
      "a document: the space-code sheet's cover prints its issue date",
  'lib/features/workspace/presentation/screens/workspace_settings_reports.dart':
      "a document: the configuration report prints its generation date",
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart':
      "a document: the badge sheet's cover prints its issue date",
  'lib/features/workspace/presentation/widgets/bi_customer_views.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_dashboard_content.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_export.dart':
      "a document: the analytics export's issue date prints in the document's locale",
  'lib/features/workspace/presentation/widgets/bi_module_section.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_overview_views.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_purchase_views.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_toolbar.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/bi_vendor_views.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/capacity_evidence.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/capacity_kpi_card.dart':
      "BI renderers shared by the screens and the printed export: they format in the locale they are handed, and every screen hands them the member's format locale (appFormatOf(context).locale)",
  'lib/features/workspace/presentation/widgets/holiday_import_sheet.dart':
      "a machine key: the ISO day a holiday is matched by, never shown",
  'lib/features/workspace/presentation/widgets/member_note_composer.dart':
      "a baked label: the reference a note carries is written in the note's language, stored as text",
  'lib/features/workspace/presentation/widgets/note_record_choices.dart':
      "a baked label: the reference a note carries is written in the note's language, stored as text",
  'lib/features/workspace/presentation/workspace_data_report_strings.dart':
      "a document: the workspace data report prints in the document's locale",
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

  test('every allowed file exists and says why', () {
    for (final MapEntry(:key, :value) in _allowed.entries) {
      expect(File(key).existsSync(), isTrue, reason: '$key is gone: drop it');
      expect(value.trim(), isNotEmpty, reason: key);
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
