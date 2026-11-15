// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the document of an issued invoice: its stored original, the same
// bytes for everyone who opens it, whenever they do.
//
// The first render after issue by someone who may issue invoices makes the
// original and stores it (0772): the invoice alone, in its frozen language,
// format and paper, without a copy stamp, a paid stamp or appended sources,
// as the Factur-X PDF/A-3 where the business's country has an e-invoice
// route, else the plain PDF with its CII recorded beside it. Every later
// read serves the stored bytes after checking them by their digest.
//
// What is not the original says so: an invoice issued before originals were
// kept, one whose stored bytes do not match their digest, one whose PDF is
// larger than the store keeps, and one nobody who may issue invoices has
// opened yet are rendered now and stamped as a copy.
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../../workspace/providers/workspace_tax_reference.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice_original.dart';
import '../providers/invoice_original_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_documents.dart';
import 'invoice_pdf_actions.dart' show invoiceShareOptions;
import 'report_layout_actions.dart';

/// Where the bytes of an invoice's document come from.
enum InvoiceDocumentSource {
  /// Its stored original, checked by its digest.
  original,

  /// Issued before originals were kept: rendered now, as a copy.
  notKept,

  /// The stored bytes do not match their digest: rendered now, as a copy.
  mismatch,

  /// Its PDF is larger than the store keeps: rendered now, as a copy.
  tooLarge,

  /// Nobody who may issue invoices has opened it yet: rendered now, as a copy.
  notYetKept,
}

/// The document of an issued invoice and where its bytes come from.
typedef InvoiceDocument = ({
  Uint8List bytes,
  String fileName,
  InvoiceDocumentSource source,
});

/// The document of [invoice]: its stored original, made and stored at the
/// first render after issue, or a copy rendered now that says it is one.
Future<InvoiceDocument> invoiceDocumentOf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final name = '${safeFileSlug(invoice.number)}.pdf';
  InvoiceDocument done(Uint8List bytes, InvoiceDocumentSource source) =>
      (bytes: bytes, fileName: name, source: source);
  Future<InvoiceDocument> copy(InvoiceDocumentSource source) async {
    if (!context.mounted) return done(Uint8List(0), source);
    return done((await _render(context, ref, invoice, copy: true)).pdf, source);
  }

  if (!invoice.keepsOriginal) return copy(InvoiceDocumentSource.notKept);
  final store = ref.read(invoiceOriginalRepositoryProvider);
  final kept = await store.originalOf(invoice.id);
  if (kept != null) {
    final bytes = await store.pdfOf(kept);
    if (kept.holds(bytes)) return done(bytes, InvoiceDocumentSource.original);
    TraceLogger.instance.warn(
      'money',
      'the stored original of ${invoice.number} does not match its digest',
    );
    return copy(InvoiceDocumentSource.mismatch);
  }
  final mayIssue = ref
      .read(myPermissionsProvider)
      .contains(WorkspacePermission.issueInvoices);
  if (!mayIssue || !context.mounted) {
    return copy(InvoiceDocumentSource.notYetKept);
  }
  final made = await _render(context, ref, invoice, copy: false);
  if (made.xml.isEmpty) return copy(InvoiceDocumentSource.notYetKept);
  try {
    final stored = await store.store(
      workspaceId: invoice.workspaceId,
      invoiceId: invoice.id,
      pdf: made.pdf,
      xml: made.xml,
    );
    // Two issuers may render at once: the first stored is the original.
    return done(
      stored.holds(made.pdf) ? made.pdf : await store.pdfOf(stored),
      InvoiceDocumentSource.original,
    );
  } on InvoiceOriginalRefused catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'the original of ${invoice.number} was not kept',
      error: e,
      stackTrace: st,
    );
    return copy(
      e.reason == InvoiceOriginalRefusal.tooLarge
          ? InvoiceDocumentSource.tooLarge
          : InvoiceDocumentSource.notYetKept,
    );
  }
}

/// The invoice alone, rendered now from its frozen language, format and
/// paper: as a [copy], or as the original with the CII it carries.
Future<({Uint8List pdf, String xml})> _render(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required bool copy,
}) async {
  final reference = requireWorkspaceTaxReference(ref);
  final workspace = ref.read(currentWorkspaceProvider).value;
  var xml = '';
  Uint8List? icc;
  if (!copy && workspace != null) {
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
      icc = (await rootBundle.load('assets/pdf/sRGB2014.icc')).buffer
          .asUint8List();
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

/// #3853 — the file a download or a share hands over: the invoice's
/// document, or, with [annexes], the bundle with its regrouped sources,
/// stamped as a copy and never the original. A copy says why it is one.
Future<({List<int> bytes, String fileName})> invoiceFileFor(
  BuildContext context,
  WidgetRef ref,
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
  final document = await invoiceDocumentOf(context, ref, invoice);
  final why = _whyACopy(document.source);
  if (why != null && context.mounted) {
    AppSnack.info(context, why(context.l10n));
  }
  return (bytes: document.bytes, fileName: document.fileName);
}

/// What a copy says about itself, or null for the original.
String Function(AppLocalizations)? _whyACopy(InvoiceDocumentSource source) =>
    switch (source) {
      InvoiceDocumentSource.original => null,
      InvoiceDocumentSource.notKept => (l10n) => l10n.invoiceOriginalNotKept,
      InvoiceDocumentSource.mismatch => (l10n) => l10n.invoiceOriginalMismatch,
      InvoiceDocumentSource.tooLarge => (l10n) => l10n.invoiceOriginalTooLarge,
      InvoiceDocumentSource.notYetKept => (
        l10n,
      ) => l10n.invoiceOriginalNotYetKept,
    };
