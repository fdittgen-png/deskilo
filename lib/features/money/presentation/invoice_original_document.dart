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
import 'dart:async';
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
    final why = _whyACopy(document);
    if (why != null && context.mounted) {
      AppSnack.info(context, why(context.l10n));
    }
    return (bytes: document.bytes, fileName: document.fileName);
  }

  /// The Factur-X of [invoice] as it leaves for a platform or a download:
  /// its stored original, made first if it is missing, which is the
  /// Factur-X wherever the business's country has an e-invoice route. Null
  /// when the invoice has no original: the caller renders it as before.
  Future<({List<int> bytes, String fileName})?> facturXOriginal(
    Invoice invoice,
  ) async {
    final document = await documentOf(invoice);
    if (document.source != InvoiceDocumentSource.original) return null;
    return (
      bytes: document.bytes,
      fileName: '${safeFileSlug('facturx ${invoice.number}')}.pdf',
    );
  }

  /// Keeps the originals of the invoices just issued, in turn, in the same
  /// flow and without a tap. An invoice whose original is not kept now stays
  /// issued and is kept later; how many is said in words.
  ///
  /// [askedFor]: the person asked for it (the To do's action), so a dialog
  /// shows the progress and an original not kept is said to be one that
  /// could not be kept.
  Future<void> keep(
    Iterable<String> invoiceIds, {
    bool askedFor = false,
  }) async {
    final ids = invoiceIds.toSet();
    if (ids.isEmpty) return;
    var kept = 0;
    final done = ValueNotifier<int>(0);
    if (askedFor) unawaited(_showProgress(done, ids.length));
    try {
      await readDocumentPolicies(ref);
      // the list as it stands now, with the invoices just issued in it
      ref.invalidate(invoicesProvider);
      final invoices = await ref.read(invoicesProvider.future);
      for (final invoice in invoices.where((i) => ids.contains(i.id))) {
        if (!context.mounted) return;
        // one that is not kept never stops the others
        try {
          final document = await documentOf(invoice);
          if (document.source == InvoiceDocumentSource.original) kept++;
          done.value++;
        } on Object catch (e, st) {
          done.value++;
          TraceLogger.instance.warn(
            'money',
            'the original of ${invoice.number} was not kept',
            error: e,
            stackTrace: st,
          );
        }
      }
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the invoices just issued could not be read to keep their originals',
        error: e,
        stackTrace: st,
      );
    }
    if (!context.mounted) return;
    if (askedFor) Navigator.of(context, rootNavigator: true).pop();
    final l10n = context.l10n;
    final notKept = ids.length - kept;
    AppSnack.info(
      context,
      notKept == 0
          ? l10n.invoiceOriginalsKeptNow(kept)
          : askedFor
          ? l10n.invoiceOriginalsCouldNotKeep(notKept)
          : l10n.invoiceOriginalsNotKeptNow(notKept),
    );
  }

  /// The progress of a run the person asked for: done of [total].
  Future<void> _showProgress(ValueNotifier<int> done, int total) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          key: const ValueKey('invoice-originals-keeping'),
          content: ValueListenableBuilder<int>(
            valueListenable: done,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.invoiceOriginalsKeeping(value, total)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total == 0 ? null : value / total,
                ),
              ],
            ),
          ),
        ),
      );

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
      if (eInvoiceRouteFor(workspace.countryCode, reference: reference) !=
          null) {
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
}

/// What a copy says about itself, or null for the original.
String Function(AppLocalizations)? _whyACopy(InvoiceDocument document) =>
    switch (document.source) {
      InvoiceDocumentSource.refused => (l10n) => l10n.invoiceOriginalRefused(
        document.why,
      ),
      InvoiceDocumentSource.original => null,
      InvoiceDocumentSource.notKept => (l10n) => l10n.invoiceOriginalNotKept,
      InvoiceDocumentSource.mismatch => (l10n) => l10n.invoiceOriginalMismatch,
      InvoiceDocumentSource.tooLarge => (l10n) => l10n.invoiceOriginalTooLarge,
      InvoiceDocumentSource.notYetKept => (
        l10n,
      ) => l10n.invoiceOriginalNotYetKept,
    };
