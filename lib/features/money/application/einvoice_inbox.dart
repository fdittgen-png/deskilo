// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — receiving a supplier's e-invoice: read it first, so a document
// that is not an invoice never reaches the server, then store it. The
// decisions (match, reject) are the server's; this is the one door.
import '../../../core/trace/trace_logger.dart';
import '../domain/einvoice_inbox.dart';
import '../domain/inbound_einvoice.dart';

class EInvoiceInbox {
  const EInvoiceInbox(this._repository);

  final EInvoiceInboxRepository _repository;

  /// Reads [xml] and stores it. A file that cannot be read comes back as
  /// [ReceivedEInvoice.problem] (an expected answer, not a failure); what
  /// the server refuses is thrown.
  Future<ReceivedEInvoice> receive(String workspaceId, String xml) async {
    final InboundEInvoice parsed;
    try {
      parsed = parseInboundEInvoice(xml);
    } on InboundEInvoiceException catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'supplier e-invoice unreadable: ${e.problem.name} ${e.field}',
        error: e,
        stackTrace: st,
      );
      return ReceivedEInvoice.refused(e);
    }
    await _repository.ingest(workspaceId, xml, parsed);
    return ReceivedEInvoice.stored(parsed);
  }

  Future<List<InboxCandidate>> candidates(String documentId) =>
      _repository.candidates(documentId);

  Future<void> match(String documentId, String eventId) =>
      _repository.match(documentId, eventId);

  /// A rejection without a reason is not one.
  Future<bool> reject(String documentId, String reason) async {
    final why = reason.trim();
    if (why.isEmpty) return false;
    await _repository.reject(documentId, why);
    return true;
  }
}

/// What [EInvoiceInbox.receive] made of a file.
class ReceivedEInvoice {
  const ReceivedEInvoice.stored(InboundEInvoice this.invoice) : problem = null;
  const ReceivedEInvoice.refused(InboundEInvoiceException this.problem)
    : invoice = null;

  final InboundEInvoice? invoice;
  final InboundEInvoiceException? problem;
}
