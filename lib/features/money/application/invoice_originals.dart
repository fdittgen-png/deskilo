// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the document of an issued invoice: its stored original, the same
// bytes for everyone who opens it, whenever they do.
//
// The first render by someone who may issue invoices makes the original and
// stores it (0772); every later read serves the stored bytes after checking
// them by their digest. What is not the original says so: an invoice issued
// before originals were kept, one whose stored bytes do not match their
// digest, one whose PDF is larger than the store keeps, and one nobody who
// may issue invoices has rendered yet are rendered now, as a copy.
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../core/files/file_names.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/invoice_original.dart';

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

  /// The business has not kept the original yet: rendered now, as a copy.
  notYetKept,

  /// The original could not be kept: the server refused it, in its words
  /// (the document's `why`), or there was nothing to check it by. Rendered
  /// now, as a copy, until the fault is fixed.
  refused,
}

/// The document of an issued invoice and where its bytes come from.
typedef InvoiceDocument = ({
  Uint8List bytes,
  String fileName,
  InvoiceDocumentSource source,
  String why,
});

/// An invoice rendered now: its PDF and the CII it carries (empty for a
/// copy).
typedef InvoiceRendered = ({Uint8List pdf, String xml});

/// Renders the invoice now, as a [copy] or as the original.
typedef InvoiceRender = Future<InvoiceRendered> Function({required bool copy});

class InvoiceOriginals {
  const InvoiceOriginals(this._store, {required this.mayIssue});

  final InvoiceOriginalRepository _store;

  /// Whether the person may issue invoices, and so store an original.
  final bool mayIssue;

  /// #4120 — the structured part (CII) stored with [invoice]'s original,
  /// when one is kept and its text still matches the digest the server
  /// recorded; null otherwise, and the caller builds it as before.
  Future<String?> storedXmlOf(Invoice invoice) async {
    if (!invoice.keepsOriginal) return null;
    final kept = await _store.originalOf(invoice.workspaceId, invoice.id);
    if (kept == null) return null;
    final xml = await _store.xmlOf(invoice.workspaceId, kept);
    if (kept.holdsXml(xml)) return xml;
    TraceLogger.instance.warn(
      'money',
      'the stored XML of ${invoice.number} does not match its digest',
    );
    return null;
  }

  /// The document of [invoice]: its stored original, made and stored by the
  /// first render of someone who may issue invoices, or a copy rendered now
  /// by [render] that says why it is one.
  Future<InvoiceDocument> documentOf(
    Invoice invoice,
    InvoiceRender render,
  ) async {
    final name = '${safeFileSlug(invoice.number)}.pdf';
    Future<InvoiceDocument> copy(
      InvoiceDocumentSource source, [
      String why = '',
    ]) async => (
      bytes: (await render(copy: true)).pdf,
      fileName: name,
      source: source,
      why: why,
    );
    InvoiceDocument original(Uint8List bytes) => (
      bytes: bytes,
      fileName: name,
      source: InvoiceDocumentSource.original,
      why: '',
    );

    if (!invoice.keepsOriginal) return copy(InvoiceDocumentSource.notKept);
    final kept = await _store.originalOf(invoice.workspaceId, invoice.id);
    if (kept != null) {
      final bytes = await _store.pdfOf(kept);
      if (kept.holds(bytes)) return original(bytes);
      TraceLogger.instance.warn(
        'money',
        'the stored original of ${invoice.number} does not match its digest',
      );
      return copy(InvoiceDocumentSource.mismatch);
    }
    if (!mayIssue) return copy(InvoiceDocumentSource.notYetKept);
    final made = await render(copy: false);
    if (made.xml.isEmpty) return copy(InvoiceDocumentSource.refused);
    try {
      final stored = await _store.store(
        workspaceId: invoice.workspaceId,
        invoiceId: invoice.id,
        pdf: made.pdf,
        xml: made.xml,
      );
      if (stored.holds(made.pdf)) return original(made.pdf);
      // Two issuers may render at once: the first stored is the original,
      // checked by its digest like any read.
      final first = await _store.pdfOf(stored);
      if (stored.holds(first)) return original(first);
      return await copy(InvoiceDocumentSource.mismatch);
    } on InvoiceOriginalRefused catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the original of ${invoice.number} was not kept',
        error: e,
        stackTrace: st,
      );
      return e.reason == InvoiceOriginalRefusal.tooLarge
          ? copy(InvoiceDocumentSource.tooLarge)
          : copy(InvoiceDocumentSource.refused, e.message);
    }
  }
}
