// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the screens' side of an issued invoice's stored original: how it
// is rendered, handed over, and kept right after issue. Which bytes are the
// document is decided by InvoiceOriginals (application/invoice_originals).
//
// The original is the invoice alone, in its frozen language, format and
// paper, without a copy stamp, a paid stamp or appended sources: the
// Factur-X PDF/A-3 where the business's country has an e-invoice route,
// else the plain PDF with its CII recorded beside it.
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/invoice_originals.dart';
import '../domain/e_invoice_routing.dart';
import '../providers/guest_pass_providers.dart' show currentWorkspaceProvider;
import '../providers/invoice_original_providers.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference;
import 'invoice_documents.dart';
import 'invoice_pdf_actions.dart' show invoiceShareOptions, savePdfToDownloads;
import 'report_layout_actions.dart';

/// An invoice's document as a screen hands it over, from [context] and [ref].
class InvoiceDocumentFlow {
  const InvoiceDocumentFlow(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// The document of [invoice]: its stored original, or a copy that says why
  /// it is one.
  Future<InvoiceDocument> documentOf(Invoice invoice) => ref
      .read(invoiceOriginalsProvider)
      .documentOf(invoice, ({required copy}) => _render(invoice, copy: copy));

  /// The file a download or a share hands over: the invoice's document, or,
  /// with [annexes], the bundle with its regrouped sources, stamped as a copy
  /// and never the original. A copy says why it is one.
  Future<({List<int> bytes, String fileName})> fileFor(
    Invoice invoice,
    List<Invoice> annexes,
  ) async {
    if (annexes.isNotEmpty) {
      return buildInvoicePdfFile(
        context,
        invoice,
        invoiceShareOptions(context, ref, invoice, annexes, copy: true),
      );
    }
    final document = await documentOf(invoice);
    final why = _whyACopy(document.source);
    if (why != null && context.mounted) {
      AppSnack.info(context, why(context.l10n));
    }
    return (bytes: document.bytes, fileName: document.fileName);
  }

  /// Keeps the originals of the invoices just issued, in turn, in the same
  /// flow and without a tap. An invoice whose original is not kept now stays
  /// issued and is kept later; how many is said in words.
  Future<void> keep(Iterable<String> invoiceIds) async {
    final ids = invoiceIds.toSet();
    if (ids.isEmpty) return;
    var notKept = ids.length;
    try {
      await readDocumentPolicies(ref);
      // the list as it stands now, with the invoices just issued in it
      ref.invalidate(invoicesProvider);
      final invoices = await ref.read(invoicesProvider.future);
      for (final invoice in invoices.where((i) => ids.contains(i.id))) {
        if (!context.mounted) return;
        final document = await documentOf(invoice);
        if (document.source == InvoiceDocumentSource.original) notKept--;
      }
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the originals of the invoices just issued were not all kept',
        error: e,
        stackTrace: st,
      );
    }
    if (notKept > 0 && context.mounted) {
      AppSnack.info(context, context.l10n.invoiceOriginalsNotKeptNow(notKept));
    }
  }

  /// Today's copy of [invoice] with its payment status: rendered now, stamped
  /// as a copy and with the paid stamp, saved for the person who asks. It is
  /// never stored or sent as the original.
  Future<void> copyWithPaymentStatus(Invoice invoice) async {
    await readDocumentPolicies(ref);
    if (!context.mounted) return;
    final made = await buildInvoicePdfFile(
      context,
      invoice,
      invoiceShareOptions(context, ref, invoice, const [], copy: true),
    );
    if (!context.mounted) return;
    await savePdfToDownloads(
      context,
      ref,
      bytes: Uint8List.fromList(made.bytes),
      fileName: made.fileName,
    );
  }

  /// The invoice alone, rendered now from its frozen language, format and
  /// paper: as a [copy], or as the original with the CII it carries.
  Future<InvoiceRendered> _render(Invoice invoice, {required bool copy}) async {
    final reference = requireWorkspaceTaxReference(ref);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    var xml = '';
    Uint8List? icc;
    if (!copy && workspace != null && context.mounted) {
      xml = facturXmlOf(
        context,
        ref,
        invoice,
        seller: sellerOf(invoice, workspace),
        buyer: buyerOf(invoice, workspace),
        iban: workspaceIban(workspace),
        reference: reference,
      );
      if (eInvoiceRouteFor(workspace.countryCode, reference: reference) != null) {
        icc = (await rootBundle.load('assets/pdf/sRGB2014.icc')).buffer.asUint8List();
      }
    }
    if (!context.mounted) return (pdf: Uint8List(0), xml: '');
    final made = await buildInvoicePdfFile(
      context,
      invoice,
      InvoicePdfFileOptions(
        reference: reference,
        reportImage: (String name) => layoutImage(ref, name),
        memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        copy: copy,
        facturXml: icc == null ? '' : xml,
        colorProfile: icc,
        template: invoicePdfTemplateFor(ref),
        workspace: workspace,
      ),
    );
    return (pdf: Uint8List.fromList(made.bytes), xml: xml);
  }
}

/// What a copy says about itself, or null for the original.
String Function(AppLocalizations)? _whyACopy(InvoiceDocumentSource source) =>
    switch (source) {
      InvoiceDocumentSource.original => null,
      InvoiceDocumentSource.notKept => (l10n) => l10n.invoiceOriginalNotKept,
      InvoiceDocumentSource.mismatch => (l10n) => l10n.invoiceOriginalMismatch,
      InvoiceDocumentSource.tooLarge => (l10n) => l10n.invoiceOriginalTooLarge,
      InvoiceDocumentSource.notYetKept => (l10n) =>
          l10n.invoiceOriginalNotYetKept,
    };
