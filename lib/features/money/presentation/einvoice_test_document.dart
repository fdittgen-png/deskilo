// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — the sandbox test document that opens the issuing gate of a
// workspace whose country routes every invoice through its national channel
// (the SdI). It is the proforma of a member's month to invoice (the server's own
// preview: nothing issued, booked or numbered), carrying a test number outside
// the invoice sequence, in the channel's own syntax. The same builder renders
// it as an issued invoice's document, so the test proves what will leave.
import 'dart:convert' show utf8;

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/files/file_names.dart';
import '../../../core/jurisdiction/installed_invoice_rules.dart';
import '../../../core/jurisdiction/installed_payment_slips.dart';
import '../../../core/time/clock.dart';
import '../application/channel_einvoice_xml.dart';
import '../domain/invoice_line_text.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference;
import 'invoice_document_locale.dart';
import 'invoice_documents.dart' show invoiceDocumentLocale;
import 'invoice_proforma.dart';
import 'screens/money_view_data.dart';

/// The number of a test document built at [at]: its mark is carried by no
/// number of the invoice sequence, and the time it was built makes each
/// test's number its own.
@visibleForTesting
String einvoiceTestNumber(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'TEST-${at.year}${two(at.month)}${two(at.day)}'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
}

/// Builds the test document for a member's proforma of a period, as the
/// channel's FatturaPA; null when that month tracked nothing to put on it.
typedef EInvoiceTestDocumentBuilder =
    Future<({List<int> bytes, String fileName})?> Function(
      WidgetRef ref, {
      required String memberId,
      required String period,
    });

/// The builder the test document card uses; a test hands in its own.
final eInvoiceTestDocumentBuilderProvider =
    Provider<EInvoiceTestDocumentBuilder>(
      (ref) => _buildEInvoiceTestDocument,
    );

Future<({List<int> bytes, String fileName})?> _buildEInvoiceTestDocument(
  WidgetRef ref, {
  required String memberId,
  required String period,
}) async {
  final workspace = MoneyViewData.gates(ref).workspace;
  if (workspace == null) return null;
  final number = einvoiceTestNumber(ref.read(clockProvider).now());
  final invoice = await proformaForMonth(
    ref,
    memberId: memberId,
    period: period,
    number: number,
  );
  if (invoice == null) return null;
  final words = documentStringsOf(invoiceDocumentLocale(ref, invoice));
  final association = ref.read(sellerIsAssociationProvider);
  final xml = buildChannelEInvoiceXml(
    EInvoiceFormat.fatturaPa,
    EInvoiceInput(
      paymentReferenceRules: installedPaymentReferenceRules,
      nationalRules: installedNationalInvoiceRules,
      invoice: invoice,
      seller: sellerOf(invoice, workspace),
      buyer: buyerOf(invoice, workspace),
      iban: workspaceIban(workspace),
      lineText: (line) => invoiceLineTextFor(
        words,
        invoice,
        line,
        liveAssociation: association,
      ),
      reference: requireWorkspaceTaxReference(ref),
    ),
  );
  return (
    bytes: utf8.encode(xml),
    fileName: '${safeFileSlug('fatturaPa $number')}.xml',
  );
}
