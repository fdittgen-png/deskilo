// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../domain/invoice_report.dart';
import 'invoice_documents.dart';

/// Carries report limitations outside the owner's editable PDF design.
class BankReconciliationPdf {
  const BankReconciliationPdf(this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;

  Future<({Uint8List bytes, String fileName})> build({
    required InvoiceReport report,
    required String title,
    required String? layoutXml,
    required Map<String, Object?> data,
    required List<String> mandatoryNotices,
  }) => letterPdfOf(
    ref,
    (
      report: report,
      title: title,
      layoutXml: layoutXml,
      data: data,
      images: const {},
    ),
    pageLabel: context.l10n.invoicePdfPage,
    watermark: developmentMark(context, ref),
    mandatoryNotices: mandatoryNotices,
  );
}
