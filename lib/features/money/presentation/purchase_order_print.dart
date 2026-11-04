// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — a purchase order printed through the workspace's report system:
// the `purchase_order` kind, its letter layout (the supplier in the
// window) when the letter standard is on, else its bands; quick view, save
// or share like every document.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_report.dart';
import '../providers/supplier_providers.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// Opens [order]'s document of [workspaceId]: quick view, save or share.
Future<void> printPurchaseOrder(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  required PurchaseOrder order,
}) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  final suppliers = await ref.read(suppliersProvider(workspaceId).future);
  if (!context.mounted || workspace == null) return;
  final locale = Localizations.localeOf(context).toString();
  final money = moneyFormat(order.currency, locale: locale);
  final day = DateFormat.yMMMd(locale);
  final quantity = NumberFormat.decimalPattern(locale);
  final data = purchaseOrderReportData(
    order,
    supplier: suppliers.where((s) => s.id == order.supplierId).firstOrNull,
    money: money.formatMinor,
    date: day.format,
    quantity: quantity.format,
    issued: ref.read(clockProvider).now(),
    issuedBy: workspace.name,
    letterhead: {
      'workspace': workspace.name,
      'workspace_address': workspace.address,
    },
  );
  final rendered = renderLetterDoc(
    context,
    ref,
    docId: 'purchase_order',
    data: data,
  );
  final title = '${l10n.reportDocPurchaseOrder} ${order.reference}';
  await runReportActions(
    context,
    ref,
    keyPrefix: 'purchase-order-print',
    logMessage: 'purchase order pdf failed',
    render: () => rendered,
    buildPdf: () async {
      final pdf = await letterDocPdf(
        context,
        ref,
        report: rendered,
        title: title,
        layoutXml: letterLayoutXml(ref, docId: 'purchase_order'),
        data: data,
      );
      return (
        bytes: pdf.bytes,
        fileName: 'purchase-order-${order.reference}.pdf',
      );
    },
  );
}
