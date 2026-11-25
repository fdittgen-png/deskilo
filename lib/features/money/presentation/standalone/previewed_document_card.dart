// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- a previewed document as a card: each line with its exact quantity
// and unit, the tax and the total, as the server answered. The standalone
// invoice and the conversion of an accepted quote show the same card.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/previewed_document.dart';

/// What the server would freeze: each line with its exact quantity and unit,
/// the tax and the total, as it answered.
class PreviewedDocumentCard extends StatelessWidget {
  const PreviewedDocumentCard({super.key, required this.preview});

  final PreviewedDocument preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context).moneyNamed(preview.currency);
    final net = preview.vatTotals.fold<int>(0, (s, t) => s + t.netCents);
    final tax = preview.vatTotals.fold<int>(0, (s, t) => s + t.vatCents);
    return Card(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in preview.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.label} · ${line.quantityText ?? ''} '
                        '${line.exactFacts?.unit.label ?? ''}',
                      ),
                    ),
                    Text(format.formatMinor(line.exactFacts?.amounts.netMinor ?? line.amountCents)),
                  ],
                ),
              ),
            const Divider(),
            _row(l.standaloneInvoicePreviewNet, format.formatMinor(net)),
            _row(l.standaloneInvoicePreviewTax, format.formatMinor(tax)),
            _row(l.standaloneInvoicePreviewTotal, format.formatMinor(preview.totalCents), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: bold ? const TextStyle().strong : null),
      ],
    ),
  );
}
