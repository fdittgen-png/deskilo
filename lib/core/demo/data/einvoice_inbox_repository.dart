// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/einvoice_inbox.dart';
import '../../../features/money/domain/inbound_einvoice.dart';

/// #2358 — the supplier inbox in memory: a received document waits, a
/// decision is remembered. Demo has no filed expenses to match, so it
/// offers no candidate.
class FakeEInvoiceInboxRepository implements EInvoiceInboxRepository {
  final List<InboxDocument> documents = [];

  @override
  Future<List<InboxDocument>> fetchInbox(String workspaceId) async =>
      List.unmodifiable(documents);

  @override
  Future<void> ingest(
    String workspaceId,
    String xml,
    InboundEInvoice parsed,
  ) async {
    documents.insert(
      0,
      InboxDocument(
        id: 'demo-inbox-${documents.length + 1}',
        number: parsed.number,
        issueDate: parsed.issueDate,
        currency: parsed.currency,
        supplierName: parsed.supplierName,
        grossCents: parsed.grossCents,
        status: InboxStatus.received,
        documentType: parsed.documentType,
      ),
    );
  }

  @override
  Future<List<InboxCandidate>> candidates(String documentId) async => const [];

  @override
  Future<void> match(String documentId, String eventId) async {}

  @override
  Future<void> reject(String documentId, String reason) async {
    final i = documents.indexWhere((d) => d.id == documentId);
    if (i < 0) return;
    final d = documents[i];
    documents[i] = InboxDocument(
      id: d.id,
      number: d.number,
      issueDate: d.issueDate,
      currency: d.currency,
      supplierName: d.supplierName,
      grossCents: d.grossCents,
      status: InboxStatus.rejected,
      documentType: d.documentType,
      rejectReason: reason,
    );
  }
}
