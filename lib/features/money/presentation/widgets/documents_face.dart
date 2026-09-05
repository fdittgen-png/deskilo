// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import 'money_faces_view.dart';

/// #720 — the Documents face: the paperwork that is not an invoice.
/// Each button is present only when its feature is on (a null callback
/// hides the button rather than disabling it — an absent feature is not
/// a broken one).
class DocumentsFaceActions extends StatelessWidget {
  const DocumentsFaceActions({
    super.key,
    required this.onAgreement,
    required this.onPaymentsReport,
    this.onUsageReport,
    required this.onStatementPdf,
    required this.showDocumentLibrary,
  });

  final VoidCallback? onAgreement;
  final VoidCallback? onPaymentsReport;

  /// #873 — the month's consumption report.
  final VoidCallback? onUsageReport;
  final VoidCallback? onStatementPdf;
  final bool showDocumentLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttons = <Widget>[
      if (onAgreement != null)
        OutlinedButton.icon(
          key: const ValueKey('agreement-report-button'),
          onPressed: onAgreement,
          icon: const Icon(Icons.handshake_outlined),
          label: fittedLabel(l10n?.moneyMyAgreement ?? 'My conditions'),
        ),
      if (onPaymentsReport != null)
        OutlinedButton.icon(
          key: const ValueKey('payments-report-button'),
          onPressed: onPaymentsReport,
          icon: const Icon(Icons.summarize_outlined),
          label: fittedLabel(l10n?.reportDocPayments ?? 'Payments report'),
        ),
      if (onUsageReport != null)
        OutlinedButton.icon(
          key: const ValueKey('usage-report-button'),
          onPressed: onUsageReport,
          icon: const Icon(Icons.insights_outlined),
          label: fittedLabel(l10n?.reportDocUsage ?? 'Consumption report'),
        ),
      if (onStatementPdf != null)
        OutlinedButton.icon(
          key: const ValueKey('statement-pdf-button'),
          onPressed: onStatementPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: fittedLabel(
              l10n?.moneyStatementPdf ?? "This month's statement (PDF)"),
        ),
      if (showDocumentLibrary)
        OutlinedButton.icon(
          key: const ValueKey('document-library-button'),
          onPressed: () => context.push('/documents'),
          icon: const Icon(Icons.folder_open_outlined),
          label: fittedLabel(l10n?.moneyDocumentLibrary ?? 'Document library'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in buttons) ...[const SizedBox(height: 8), b],
      ],
    );
  }
}
