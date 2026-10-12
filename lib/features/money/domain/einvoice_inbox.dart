// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'inbound_einvoice.dart';

/// #2358 — where a decision stands.
enum InboxStatus {
  received,
  matched,
  rejected;

  static InboxStatus of(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => received);
}

/// One supplier invoice in the inbox (`einvoice_inbox`, 0415), without the
/// XML — the bytes stay on the server.
class InboxDocument {
  const InboxDocument({
    required this.id,
    required this.number,
    required this.issueDate,
    required this.currency,
    required this.supplierName,
    required this.grossCents,
    required this.status,
    this.documentType = '380',
    this.rejectReason = '',
  });

  factory InboxDocument.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'einvoice_inbox');
    return InboxDocument(
      id: r.string('id'),
      number: r.stringOr('invoice_number'),
      issueDate: r.stringOr('issue_date'),
      currency: r.stringOr('currency'),
      supplierName: r.stringOr('supplier_name'),
      grossCents: r.intOrNull('gross_cents') ?? 0,
      status: InboxStatus.of(r.stringOrNull('status')),
      documentType: r.stringOr('document_type', '380'),
      rejectReason: r.stringOr('reject_reason'),
    );
  }

  final String id;
  final String number;
  final String issueDate;
  final String currency;
  final String supplierName;
  final int grossCents;
  final InboxStatus status;
  final String documentType;
  final String rejectReason;
}

/// A filed expense a document may be the invoice of.
class InboxCandidate {
  const InboxCandidate({
    required this.eventId,
    required this.filedOn,
    required this.category,
    required this.note,
    required this.amountCents,
  });

  factory InboxCandidate.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'einvoice_match_candidates');
    return InboxCandidate(
      eventId: r.string('event_id'),
      filedOn: r.stringOr('filed_on'),
      category: r.stringOr('category'),
      note: r.stringOr('note'),
      amountCents: r.intOrNull('amount_cents') ?? 0,
    );
  }

  final String eventId;
  final String filedOn;
  final String category;
  final String note;
  final int amountCents;
}

abstract interface class EInvoiceInboxRepository {
  Future<List<InboxDocument>> fetchInbox(String workspaceId);

  /// Stores [xml] with what the parser read; throws when the server
  /// refuses (a duplicate, a total that does not add up, no permission).
  Future<void> ingest(String workspaceId, String xml, InboundEInvoice parsed);

  Future<List<InboxCandidate>> candidates(String documentId);

  Future<void> match(String documentId, String eventId);

  Future<void> reject(String documentId, String reason);
}
