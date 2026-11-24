// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- a customer quote as the server answers it: a quote with its
// revisions (a sent revision is its frozen content, never changed), the
// issuer's recorded decision and the one conversion into an invoice. Nothing
// here computes an amount: a draft has no total, a sent revision carries the
// totals the real issuer froze, and expiry is the server's derived answer.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../core/failure/app_failure.dart';
import 'customer_quote_lines.dart';
import 'standalone_invoice.dart';

/// Where a quote stands. A quote with anything sent is never deleted.
enum QuoteStatus {
  draft,
  sent,
  accepted,
  declined,
  cancelled,
  converted;

  static QuoteStatus? of(String wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

/// The totals a sent revision froze (from the real invoice issuer's dry run).
@immutable
class QuoteTotals {
  const QuoteTotals({required this.totalCents, required this.currency});

  factory QuoteTotals.fromJson(JsonReader r) => QuoteTotals(
    totalCents: r.integer('total_cents'),
    currency: r.stringOr('currency'),
  );

  final int totalCents;
  final String currency;
}

/// One revision of a quote: the working draft (editable at its version) or a
/// sent one (frozen: the lines are its snapshot).
@immutable
class QuoteRevision {
  const QuoteRevision({
    required this.revision,
    required this.sent,
    required this.draftVersion,
    required this.issuedOn,
    required this.validUntil,
    required this.buyerReference,
    required this.purchaseOrder,
    required this.notes,
    required this.lines,
    required this.totals,
    required this.contentDigest,
    required this.superseded,
    this.amounts = const [],
  });

  factory QuoteRevision.fromJson(JsonReader r) => QuoteRevision(
    revision: r.integer('revision'),
    sent: r.stringOr('status') == 'sent',
    draftVersion: r.integer('draft_version'),
    issuedOn: DateTime.parse(r.string('issued_on')),
    validUntil: DateTime.parse(r.string('valid_until')),
    buyerReference: r.stringOr('buyer_reference'),
    purchaseOrder: r.stringOr('purchase_order'),
    notes: r.stringOr('notes'),
    // The working draft keeps the lines as they were entered; a SENT revision
    // is the invoice line snapshot the issuer froze (label, commercial facts).
    lines: r.objects(
      'lines',
      r.stringOr('status') == 'sent' ? frozenQuoteLine : StandaloneLine.fromJson,
    ),
    // What each frozen line comes to, in the order of [lines]; none for a draft.
    amounts: r.stringOr('status') == 'sent'
        ? r.objects('lines', QuoteLineAmounts.fromJson)
        : const [],
    totals: r.objectOrNull('totals') == null
        ? null
        : QuoteTotals.fromJson(r.objectOrNull('totals')!),
    contentDigest: r.stringOr('content_digest'),
    superseded: r.isTrue('superseded'),
  );

  final int revision;

  /// True for a sent (frozen) revision, false for the working draft.
  final bool sent;

  /// The version an edit of the working draft names; the server refuses a stale one.
  final int draftVersion;
  final DateTime issuedOn;
  final DateTime validUntil;
  final String buyerReference;
  final String purchaseOrder;
  final String notes;
  final List<StandaloneLine> lines;

  /// What each line of a sent revision comes to (same order as [lines]).
  final List<QuoteLineAmounts> amounts;

  /// Null for a draft: its amounts exist only once the revision is sent.
  final QuoteTotals? totals;
  final String contentDigest;

  /// A newer revision was sent after this one.
  final bool superseded;
}

/// What the issuer recorded: never a customer's signature.
@immutable
class QuoteDecision {
  const QuoteDecision({
    required this.accepted,
    required this.revision,
    required this.decidedOn,
    required this.source,
    required this.evidence,
  });

  factory QuoteDecision.fromJson(JsonReader r) => QuoteDecision(
    accepted: r.string('decision') == 'accepted',
    revision: r.integer('revision'),
    decidedOn: DateTime.parse(r.string('decided_on')),
    source: r.stringOr('source'),
    evidence: r.stringOr('evidence'),
  );

  final bool accepted;
  final int revision;
  final DateTime decidedOn;

  /// `received_outside_app`, `verbal`, `email` or `other`.
  final String source;
  final String evidence;
}

/// A quote with its revisions, the recorded decision and the conversion.
@immutable
class CustomerQuote {
  const CustomerQuote({
    required this.id,
    required this.subjectId,
    required this.reference,
    required this.status,
    required this.expired,
    required this.revisions,
    required this.decision,
    required this.invoiceId,
  });

  factory CustomerQuote.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'customer quote');
    final status = QuoteStatus.of(r.string('status'));
    if (status == null) {
      throw FormatException('unknown quote status: ${r.string('status')}');
    }
    final conversion = r.objectOrNull('conversion');
    final decision = r.objectOrNull('decision');
    return CustomerQuote(
      id: r.string('quote_id'),
      subjectId: r.string('subject_id'),
      reference: r.stringOrNull('reference'),
      status: status,
      expired: r.isTrue('expired'),
      revisions: r.objects('revisions', QuoteRevision.fromJson),
      decision: decision == null ? null : QuoteDecision.fromJson(decision),
      invoiceId: conversion?.stringOrNull('invoice_id'),
    );
  }

  final String id;

  /// The billing customer (the financial subject) the offer is made to.
  final String subjectId;

  /// Null until the first send: a draft takes no number.
  final String? reference;
  final QuoteStatus status;

  /// An unaccepted offer past its validity on the business clock (derived by the server).
  final bool expired;
  final List<QuoteRevision> revisions;
  final QuoteDecision? decision;

  /// The one initial invoice this quote became, when it did.
  final String? invoiceId;

  /// The revision an edit works on: the open draft, else none.
  QuoteRevision? get draft => revisions.where((r) => !r.sent).lastOrNull;

  /// The revision the customer is offered now: the latest sent, not superseded.
  QuoteRevision? get current =>
      revisions.where((r) => r.sent && !r.superseded).lastOrNull;

  /// Whether the issuer can still act on it: a draft or a sent quote.
  bool get openForActions =>
      status == QuoteStatus.draft ||
      status == QuoteStatus.sent ||
      status == QuoteStatus.accepted;

  /// What the list shows: the working draft, else the current sent revision.
  QuoteRevision? get shown => draft ?? current ?? revisions.lastOrNull;
}

/// What the issuer enters for a draft revision.
@immutable
class QuoteDraftInput {
  const QuoteDraftInput({
    required this.subjectId,
    required this.lines,
    this.issuedOn,
    this.validUntil,
    this.buyerReference = '',
    this.purchaseOrder = '',
    this.notes = '',
  });

  final String subjectId;
  final List<StandaloneLine> lines;

  /// Null: the business's today, and the end its own default validity gives.
  final DateTime? issuedOn;
  final DateTime? validUntil;
  final String buyerReference;
  final String purchaseOrder;
  final String notes;
}

/// A saved or amended draft: its quote, revision and the version to edit next.
@immutable
class QuoteSaved {
  const QuoteSaved({
    required this.quoteId,
    required this.revision,
    required this.version,
  });

  factory QuoteSaved.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'customer quote draft');
    return QuoteSaved(
      quoteId: r.string('quote_id'),
      revision: r.integer('revision'),
      version: r.integer('version'),
    );
  }

  final String quoteId;
  final int revision;
  final int version;
}

/// A sent revision: its reference (taken from the quote series at the first send).
@immutable
class QuoteSent {
  const QuoteSent({
    required this.quoteId,
    required this.reference,
    required this.revision,
    required this.replayed,
  });

  factory QuoteSent.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'send_customer_quote_v1');
    return QuoteSent(
      quoteId: r.string('quote_id'),
      reference: r.stringOr('reference'),
      revision: r.integer('revision'),
      replayed: r.isTrue('replayed'),
    );
  }

  final String quoteId;
  final String reference;
  final int revision;
  final bool replayed;
}

/// What the server refused, by its own code (DKQ01-DKQ10, DKN01, DKI01...).
enum QuoteRefusalKind {
  /// DKQ02: the draft changed since it was read.
  stale,

  /// DKQ03: the quote is in a state that does not allow this.
  state,

  /// DKQ04: the offer is past its validity, so an acceptance is refused.
  expired,

  /// DKQ08: the invoice would differ from what was accepted; the reviewed
  /// digest of exactly what would be issued is needed ([QuoteRefusal.detail]).
  needsReview,

  /// DKQ06 (or DKI01): the quote is not complete; [QuoteRefusal.missing] names what.
  incomplete,

  /// DKQ10: quotes are switched off in this business.
  featureOff,

  /// DKN01 / DKQ07: not allowed (right, or an assistant session).
  notAllowed,

  /// Anything else the server said no to.
  other,
}

class QuoteRefusal implements TypedRefusal {
  const QuoteRefusal(this.kind, {this.missing = const [], this.detail = ''});

  final QuoteRefusalKind kind;

  /// What the server attached: for [QuoteRefusalKind.needsReview] the digest of
  /// the invoice that would be issued now.
  final String detail;

  /// The facts the server named (`valid_until`, `line_1_quantity`...), if any.
  final List<String> missing;

  @override
  String toString() => 'QuoteRefusal($kind, $missing)';
}

/// What the issuer enters when recording the customer's answer: never the
/// customer's signature, the issuer's own record of a decision.
@immutable
class QuoteDecisionInput {
  const QuoteDecisionInput({
    required this.accepted,
    required this.revision,
    required this.decidedOn,
    required this.source,
    this.evidence = '',
  });

  final bool accepted;

  /// The sent, current revision the answer is about.
  final int revision;
  final DateTime decidedOn;

  /// `received_outside_app`, `verbal`, `email` or `other`.
  final String source;
  final String evidence;
}

/// What the invoice of an accepted quote would be, as the real issuer previews
/// it: the facts it cannot accept, or its amounts, set against what was accepted.
@immutable
class QuoteConversionPrep {
  const QuoteConversionPrep({
    required this.draftRevision,
    required this.missing,
    required this.acceptedTotalCents,
    required this.wouldBeTotalCents,
    required this.currency,
    required this.contextChanged,
    required this.reviewDigest,
  });

  factory QuoteConversionPrep.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'prepare_quote_conversion_v1');
    final outer = r.objectOrNull('preview');
    final inner = outer?.objectOrNull('preview');
    return QuoteConversionPrep(
      draftRevision: r.integer('draft_revision'),
      missing: outer?.strings('missing') ?? const [],
      acceptedTotalCents: _minor(r.string('accepted_total_cents'), 'accepted_total_cents'),
      wouldBeTotalCents: inner?.intOrNull('total_cents'),
      currency: inner?.stringOr('currency') ?? '',
      contextChanged: r.isTrue('context_changed'),
      reviewDigest: r.stringOr('review_digest'),
    );
  }

  /// The invoice draft's revision the conversion names.
  final int draftRevision;

  /// The facts the issuer cannot accept yet (`due_on`, `buyer_vat_id`...).
  final List<String> missing;
  final int acceptedTotalCents;
  /// What an issue would come to now; null while the preview has no total (a draft the issuer cannot accept yet).
  final int? wouldBeTotalCents;
  final String currency;

  /// The invoice would differ from what was accepted: it needs an explicit review.
  final bool contextChanged;

  /// The digest of exactly this preview: what a review is confirmed against.
  final String reviewDigest;

  bool get issuable => missing.isEmpty;
}

/// The one initial invoice a quote became.
@immutable
class QuoteConverted {
  const QuoteConverted({
    required this.invoiceId,
    required this.number,
    required this.replayed,
  });

  factory QuoteConverted.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'convert_customer_quote_v1');
    return QuoteConverted(
      invoiceId: r.string('invoice_id'),
      number: r.stringOrNull('number'),
      replayed: r.isTrue('replayed'),
    );
  }

  final String invoiceId;

  /// The invoice's number as the server answered, or null when the answer was lost and the invoice was found by its quote.
  final String? number;

  /// True when the quote had already been converted: the answer is that invoice.
  final bool replayed;
}

/// The server's reads and writes of customer quotes.
abstract interface class CustomerQuoteRepository {
  Future<List<CustomerQuote>> quotes(String workspaceId);

  Future<CustomerQuote> quote(String workspaceId, String quoteId);

  /// Creates a quote ([quoteId] null) or edits its working draft at [expectedVersion].
  Future<QuoteSaved> saveDraft(
    String workspaceId, {
    required QuoteDraftInput input,
    String? quoteId,
    int? expectedVersion,
  });

  /// Opens a new working draft revision of a sent quote.
  Future<QuoteSaved> amend(String workspaceId, String quoteId);

  /// Freezes [revision] at [version]; the first send takes the reference.
  Future<QuoteSent> send(
    String workspaceId,
    String quoteId, {
    required int revision,
    required int version,
  });

  /// Records the customer's answer to the current sent revision.
  Future<void> recordDecision(
    String workspaceId,
    String quoteId,
    QuoteDecisionInput decision,
  );

  /// Previews the invoice of an accepted quote for the stated dates; nothing is issued.
  Future<QuoteConversionPrep> prepareConversion(
    String workspaceId,
    String quoteId, {
    required DateTime serviceDate,
    required DateTime dueOn,
  });

  /// Issues the one initial invoice of an accepted quote under [requestId]; the
  /// same quote answers the same invoice whatever the request.
  Future<QuoteConverted> convert(
    String workspaceId,
    String quoteId, {
    required int draftRevision,
    required String requestId,
    String? reviewedDigest,
  });

  Future<void> cancel(String workspaceId, String quoteId);

  /// Discards a working draft that was never sent.
  Future<void> discardDraft(String workspaceId, String quoteId);
}

/// A minor-unit amount the server sent as text: an unreadable one is a decoding error, never a zero.
int _minor(String text, String field) =>
    int.tryParse(text) ?? (throw FormatException('prepare_quote_conversion_v1: $field is not an amount: $text'));
