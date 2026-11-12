// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The structured e-invoice (CII) a Factur-X PDF embeds; moved out of
// invoice_documents.dart for #3673, unchanged.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/jurisdiction/installed_invoice_rules.dart';
import '../../../core/jurisdiction/installed_payment_slips.dart';
import '../../../core/l10n/context_l10n.dart';
import '../domain/invoice_line_text.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart' show invoiceDueAt;
import 'report_facts_of.dart';
import 'report_strings_l10n.dart';

/// FACTUR-X: one PDF that carries the EN 16931 invoice inside it (as CII,
/// the syntax the format mandates). A human opens it and sees the invoice;
/// a platform opens it and finds `factur-x.xml`. This is what French and
/// German small businesses actually hand to their platform.
/// The structured e-invoice (CII) of [invoice], the XML a Factur-X PDF
/// embeds: the same positions, due date and terms the PDF prints.
String facturXmlOf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
  required TaxReferenceSet reference,
}) {
  final association = ref.read(sellerIsAssociationProvider);
  final words = reportStringsOf(context.l10n, formatLocale: appFormatOf(context).locale);
  return buildInvoiceCii(EInvoiceInput(paymentReferenceRules: installedPaymentReferenceRules, nationalRules: installedNationalInvoiceRules, invoice: invoice,
    seller: seller,
    buyer: buyer,
    iban: iban,
    lineText: (line) => invoiceLineText(words, line,
        association: association, period: invoice.period),
    // #941 — the same due date and terms the PDF prints.
    dueDate: invoiceDueAt(ref, invoice),
    // #1916 — an issued invoice states the terms frozen with it.
    paymentTerms: invoice.legalClauses?.clauses.paymentTerms ??
        memberTermsFor(ref, invoice.memberId)?.paymentTerms ??
        '',
    reference: reference));
}
