// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances → one invoice, opened in the Money screen of the space it
// belongs to (production or development, never the other). Shown as MY
// invoice: the issuing actions stay in Invoicing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/invoice_ubl.dart';
import '../../domain/money_face.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_providers.dart';
import 'invoice_detail_sheet.dart';

/// Consumes [focus] when [workspaceId] (the space on screen) is the invoice's
/// own: switches to
/// the Invoices face and opens the invoice's sheet.
Future<void> openFocusedInvoice(
  BuildContext context,
  WidgetRef ref,
  ({String workspaceId, String invoiceId})? focus, {
  required String? workspaceId,
  required String countryCode,
}) async {
  if (focus == null || workspaceId != focus.workspaceId) return;
  ref.read(invoiceFocusProvider.notifier).clear();
  ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.invoices);
  final invoices = await ref.read(invoicesProvider.future);
  final invoice = invoices.where((i) => i.id == focus.invoiceId).firstOrNull;
  if (!context.mounted || invoice == null) return;
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  await showInvoiceDetailSheet(
    context,
    ref: ref,
    invoice: invoice,
    match: matches[invoice.id],
    canIssue: false,
    isEu: isEuCountry(countryCode),
  );
}
