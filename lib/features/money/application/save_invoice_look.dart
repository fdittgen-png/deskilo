// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's invoice look: one of the shipped looks becomes the
// invoice's own bands. The rest of the template (the other documents, the
// layouts, the texts, the address window) is written back as it was read.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/invoice_pdf_template.dart';
import '../domain/report_template_repository.dart';
import '../providers/money_queries_providers.dart';

part 'save_invoice_look.g.dart';

class SaveInvoiceLook {
  const SaveInvoiceLook(this._templates);
  final ReportTemplateRepository _templates;

  /// Writes [current] with [look] as the invoice's bands. Throws whatever
  /// the repository throws.
  Future<void> apply(
    String workspaceId,
    InvoicePdfTemplate current,
    ReportBands look,
  ) => _templates.setInvoicePdfTemplate(
    workspaceId,
    current.copyWith(invoice: look),
  );
}

/// The setup guide's write of the invoice look.
@riverpod
SaveInvoiceLook saveInvoiceLook(Ref ref) =>
    SaveInvoiceLook(ref.watch(reportTemplateRepositoryProvider));
