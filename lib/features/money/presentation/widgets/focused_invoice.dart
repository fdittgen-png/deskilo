// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances → one invoice, opened in the Money screen of the space it
// belongs to (production or development, never the other). Shown as MY
// invoice: the issuing actions stay in Invoicing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/session_source.dart';
import '../../domain/money_face.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show workspaceIsEu;
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
  final target = ref.read(financeCurrentTargetProvider);
  if (focus == null || (workspaceId != focus.workspaceId && target?.networkId != focus.workspaceId)) return;
  final principal = ref.read(sessionStateProvider).value;
  bool current() => ref.read(sessionStateProvider).value == principal &&
      ref.read(financeCurrentTargetProvider) == target;
  ref.read(invoiceFocusProvider.notifier).clear();
  ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.invoices);
  final invoiceAnswer = ref.read(invoicesProvider.future);
  final matchAnswer = ref.read(invoiceMatchesProvider.future)..ignore();
  final invoices = await invoiceAnswer;
  final invoice = invoices.where((i) => i.id == focus.invoiceId).firstOrNull;
  if (!context.mounted || invoice == null || !current()) return;
  final matches = await matchAnswer;
  if (!context.mounted || !current()) return;
  await showInvoiceDetailSheet(
    context,
    ref: ref,
    view: InvoiceDetailView(
      invoice: invoice,
      match: matches[invoice.id],
      canIssue: false,
      isEu: workspaceIsEu(ref, countryCode),
    ),
  );
}
