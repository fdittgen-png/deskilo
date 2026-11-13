// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — the sandbox test document that opens the issuing gate of a
// workspace whose country routes every invoice through its national channel
// (the SdI). It is the proforma of a member's current month (the server's own
// preview: nothing issued, booked or numbered), carrying a test number outside
// the invoice sequence, in the channel's own syntax. The same builder renders
// it as an issued invoice's document, so the test proves what will leave.
import 'dart:convert' show utf8;

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/files/file_names.dart';
import '../../../core/jurisdiction/installed_invoice_rules.dart';
import '../../../core/jurisdiction/installed_payment_slips.dart';
import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/channel_einvoice_xml.dart';
import '../domain/invoice_line_text.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference;
import 'invoice_document_locale.dart';
import 'invoice_documents.dart' show invoiceDocumentLocale;
import 'invoice_proforma.dart';

/// What marks a test document's number: no invoice number of the sequence
/// carries it, and the time it was built makes each test's number its own.
const einvoiceTestNumberPrefix = 'TEST-';

/// The number of a test document built at [at].
String einvoiceTestNumber(DateTime at) =>
    '$einvoiceTestNumberPrefix${DateFormat('yyyyMMddHHmmss').format(at)}';

/// The test document for [memberId]'s current month, as the channel's
/// FatturaPA; null when the month tracked nothing to put on it.
Future<({List<int> bytes, String fileName})?> buildEInvoiceTestDocument(
  WidgetRef ref, {
  required String memberId,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return null;
  final now = ref.read(clockProvider).now();
  final number = einvoiceTestNumber(now);
  final invoice = await proformaForMonth(
    ref,
    memberId: memberId,
    period: currentPeriod(now),
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
