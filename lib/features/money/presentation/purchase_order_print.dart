// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — a purchase order printed through the workspace's report system:
// the `purchase_order` kind, its letter layout (the supplier in the
// window) when the letter standard is on, else its bands; quick view, save
// or share like every document.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/print_or_retry.dart';
import '../domain/invoice_report.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_report.dart';
import '../providers/supplier_providers.dart';
import 'invoice_document_locale.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// Prints a purchase order of the space.
class PurchaseOrderPrint {
  const PurchaseOrderPrint(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  DocumentLocale get _locale => businessDocumentLocale(ref);

  /// The data and the rendered bands of [order] under [letterhead]; null
  /// once the screen is gone.
  Future<({Map<String, Object?> data, InvoiceReport rendered, String title})?>
  _document(
    String workspaceId,
    PurchaseOrder order,
    ({String name, String address}) letterhead,
  ) async {
    await readDocumentPolicies(ref); // #3742 — the template and rules, read
    final suppliers = await ref.read(suppliersProvider(workspaceId).future);
    if (!context.mounted) return null;
    // #3850 — a supplier has no language: the order is written in the
    // business's document language and its country's conventions, whoever
    // prints it.
    final locale = _locale;
    final l10n = l10nForLanguage(locale.language);
    final money = moneyFormat(order.currency, locale: locale.formatLocale);
    final day = DateFormat.yMMMd(locale.language);
    final quantity = NumberFormat.decimalPattern(locale.formatLocale);
    final data = purchaseOrderReportData(
      order,
      supplier: suppliers.where((s) => s.id == order.supplierId).firstOrNull,
      format: (
        money: money.formatMinor,
        date: day.format,
        quantity: quantity.format,
      ),
      issued: ref.read(clockProvider).now(),
      issuedBy: letterhead.name,
      letterhead: {
        'workspace': letterhead.name,
        'workspace_address': letterhead.address,
      },
    );
    return (
      data: data,
      rendered: renderLetterDoc(
        context,
        ref,
        docId: 'purchase_order',
        data: data,
        language: locale.language,
      ),
      title: l10n.reportDocPurchaseOrderTitle(order.reference),
    );
  }

  Future<({Uint8List bytes, String fileName})> _pdf(
    PurchaseOrder order,
    ({Map<String, Object?> data, InvoiceReport rendered, String title}) doc,
  ) async {
    final pdf = await letterPdfOf(
      ref,
      (
        report: doc.rendered,
        title: doc.title,
        layoutXml: letterLayoutXml(ref, docId: 'purchase_order'),
        data: doc.data,
        images: const {},
      ),
      pageLabel: l10nForLanguage(_locale.language).invoicePdfPage,
      watermark: developmentMark(context, ref),
    );
    return (
      bytes: pdf.bytes,
      fileName: 'purchase-order-${order.reference}.pdf',
    );
  }

  /// Opens [order]'s document under [letterhead] (the space's name and
  /// address): quick view, save or share.
  Future<void> show({
    required String workspaceId,
    required PurchaseOrder order,
    required ({String name, String address}) letterhead,
  }) => printOrRetry(context, 'purchase order', () async {
    final doc = await _document(workspaceId, order, letterhead);
    if (doc == null || !context.mounted) return;
    await runReportActions(
      context,
      ref,
      keyPrefix: 'purchase-order-print',
      logMessage: 'purchase order pdf failed',
      render: () => doc.rendered,
      buildPdf: () => _pdf(order, doc),
    );
  });

  /// #3307 — what the e-mail carries: the same document, its subject and
  /// a short text in the reader's language; null once the screen is gone.
  Future<PurchaseOrderMail?> mail({
    required String workspaceId,
    required PurchaseOrder order,
    required ({String name, String address}) letterhead,
  }) async {
    final l10n = context.l10n;
    final doc = await _document(workspaceId, order, letterhead);
    if (doc == null || !context.mounted) return null;
    final pdf = await _pdf(order, doc);
    return (
      subject: doc.title,
      text: l10n.purchaseOrderMailText(order.reference, letterhead.name),
      pdfBase64: base64Encode(pdf.bytes),
      fileName: pdf.fileName,
    );
  }
}
