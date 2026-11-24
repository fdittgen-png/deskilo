// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- service fulfilment: an ordered service followed as an engagement
// of its own, ordered -> started -> done, or cancelled with a reason, every step
// kept. The quote, the invoice and the payments beside it are read and never
// changed by it. Pure: what the server answers, what a step may be, and the typed
// refusals; the repository interface is what the screens depend on.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../core/failure/app_failure.dart';

/// The list the engagements are counted under when a row is left out.
const fulfilmentsArea = 'service_fulfilments';

/// Where an engagement stands. The wire names are the server's.
enum FulfilmentState {
  ordered('ordered'),
  started('started'),
  done('done'),
  cancelled('cancelled');

  const FulfilmentState(this.wire);

  final String wire;

  /// The state the server named, or null for one this build does not know.
  static FulfilmentState? of(String wire) =>
      values.where((s) => s.wire == wire).firstOrNull;

  /// No step leaves it: the engagement is over.
  bool get isFinal => this == done || this == cancelled;
}

/// A state of the server that this build does not know: the engagement is left
/// out of its list (and counted), never read as a state it is not.
class UnknownFulfilmentState implements Exception {
  const UnknownFulfilmentState(this.wire);

  final String wire;

  @override
  String toString() => 'UnknownFulfilmentState($wire)';
}

FulfilmentState _stateOf(String wire) {
  final state = FulfilmentState.of(wire);
  if (state == null) {
    throw UnknownFulfilmentState(wire);
  }
  return state;
}

/// The steps an engagement in [from] may take, in the order they are offered:
/// ordered goes on to started or is cancelled, started to done or is cancelled,
/// and nothing leaves done or cancelled (the server decides; this only offers).
List<FulfilmentState> nextSteps(FulfilmentState from) => switch (from) {
  FulfilmentState.ordered => const [
    FulfilmentState.started,
    FulfilmentState.cancelled,
  ],
  FulfilmentState.started => const [
    FulfilmentState.done,
    FulfilmentState.cancelled,
  ],
  FulfilmentState.done || FulfilmentState.cancelled => const [],
};

/// Whether a step to [to] must carry a reason.
bool stepNeedsReason(FulfilmentState to) => to == FulfilmentState.cancelled;

/// The canonical commercial source line of an engagement.
@immutable
class FulfilmentSource {
  const FulfilmentSource({
    required this.kind,
    required this.id,
    required this.lineId,
    this.revision,
  });

  factory FulfilmentSource.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment source');
    return FulfilmentSource(
      kind: r.string('kind'),
      id: r.string('id'),
      lineId: r.string('line_id'),
      revision: r.intOrNull('revision'),
    );
  }

  /// `quote`, `invoice` or `direct`.
  final String kind;
  final String id;
  final String lineId;

  /// The accepted quote revision it came from; null for the other kinds.
  final int? revision;
}

/// What was ordered, frozen when the engagement was opened.
@immutable
class FulfilmentScope {
  const FulfilmentScope({
    required this.description,
    required this.quantity,
    required this.unit,
    this.item = '',
    this.variant = '',
  });

  factory FulfilmentScope.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment scope');
    return FulfilmentScope(
      description: r.string('description'),
      quantity: r.string('quantity'),
      unit: r.string('unit'),
      item: r.stringOr('item'),
      variant: r.stringOr('variant'),
    );
  }

  final String description;

  /// An exact decimal, as the commitment froze it.
  final String quantity;
  final String unit;

  /// The catalogue item and variant as they were named then (never read again).
  final String item;
  final String variant;
}

/// One step of an engagement's history.
@immutable
class FulfilmentStep {
  const FulfilmentStep({
    required this.revision,
    required this.to,
    required this.actorId,
    required this.at,
    this.from,
    this.reason = '',
  });

  factory FulfilmentStep.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment step');
    final from = r.stringOrNull('from');
    return FulfilmentStep(
      revision: r.integer('revision'),
      from: from == null ? null : _stateOf(from),
      to: _stateOf(r.string('to')),
      reason: r.stringOr('reason'),
      actorId: r.string('actor_id'),
      at: DateTime.parse(r.string('at')),
    );
  }

  final int revision;
  final FulfilmentState? from;
  final FulfilmentState to;
  final String reason;
  final String actorId;
  final DateTime at;
}

/// A correction (credit note) of an invoice an engagement is billed on.
@immutable
class FulfilmentCorrection {
  const FulfilmentCorrection({
    required this.invoiceId,
    required this.number,
    required this.totalCents,
  });

  factory FulfilmentCorrection.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment correction');
    return FulfilmentCorrection(
      invoiceId: r.string('invoice_id'),
      number: r.string('number'),
      totalCents: r.integer('total_cents'),
    );
  }

  final String invoiceId;
  final String number;
  final int totalCents;
}

/// An invoice an engagement is billed on, with what was paid on it: facts that
/// are READ beside the engagement, never changed by it.
@immutable
class FulfilmentInvoice {
  const FulfilmentInvoice({
    required this.invoiceId,
    required this.number,
    required this.totalCents,
    required this.currency,
    required this.paidCents,
    this.corrections = const [],
  });

  factory FulfilmentInvoice.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment invoice');
    return FulfilmentInvoice(
      invoiceId: r.string('invoice_id'),
      number: r.string('number'),
      totalCents: r.integer('total_cents'),
      currency: r.string('currency'),
      paidCents: r.integer('paid_cents'),
      corrections: [
        for (final c in r.list('corrections')) FulfilmentCorrection.fromJson(c),
      ],
    );
  }

  final String invoiceId;
  final String number;
  final int totalCents;
  final String currency;
  final int paidCents;
  final List<FulfilmentCorrection> corrections;
}

/// The quote an engagement came from.
@immutable
class FulfilmentQuote {
  const FulfilmentQuote({
    required this.quoteId,
    required this.status,
    this.reference,
  });

  factory FulfilmentQuote.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'fulfilment quote');
    return FulfilmentQuote(
      quoteId: r.string('quote_id'),
      reference: r.stringOrNull('reference'),
      status: r.string('status'),
    );
  }

  final String quoteId;
  final String? reference;
  final String status;
}

/// One engagement as the server answers it.
@immutable
class ServiceFulfilment {
  const ServiceFulfilment({
    required this.id,
    required this.subjectId,
    required this.state,
    required this.revision,
    required this.source,
    required this.scope,
    required this.history,
    this.itemId,
    this.variantId,
    this.quote,
    this.invoices = const [],
  });

  factory ServiceFulfilment.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'service fulfilment');
    final quote = r.objectOrNull('quote')?.json;
    return ServiceFulfilment(
      id: r.string('fulfilment_id'),
      subjectId: r.string('subject_id'),
      state: _stateOf(r.string('state')),
      revision: r.integer('revision'),
      source: FulfilmentSource.fromJson(r.raw('source')),
      scope: FulfilmentScope.fromJson(r.raw('scope')),
      itemId: r.stringOrNull('item_id'),
      variantId: r.stringOrNull('variant_id'),
      history: [for (final s in r.list('history')) FulfilmentStep.fromJson(s)],
      quote: quote == null ? null : FulfilmentQuote.fromJson(quote),
      invoices: [
        for (final i in r.list('invoices')) FulfilmentInvoice.fromJson(i),
      ],
    );
  }

  final String id;

  /// The billing customer it is owed to (`members.id`).
  final String subjectId;
  final FulfilmentState state;

  /// The revision of its history: the next step is taken at this one.
  final int revision;
  final FulfilmentSource source;
  final FulfilmentScope scope;
  final String? itemId;
  final String? variantId;

  /// Every step, oldest first.
  final List<FulfilmentStep> history;
  final FulfilmentQuote? quote;
  final List<FulfilmentInvoice> invoices;

  /// The steps it may take now.
  List<FulfilmentState> get next => nextSteps(state);
}

/// What opening answered: the engagement, whether this call made it, and
/// whether the answer is a replay of the same request.
@immutable
class FulfilmentOpened {
  const FulfilmentOpened({
    required this.fulfilment,
    required this.created,
    required this.replayed,
  });

  factory FulfilmentOpened.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'opened fulfilment');
    return FulfilmentOpened(
      fulfilment: ServiceFulfilment.fromJson(r.raw('fulfilment')),
      created: r.isTrue('created'),
      replayed: r.isTrue('replayed'),
    );
  }

  final ServiceFulfilment fulfilment;
  final bool created;
  final bool replayed;
}

/// What the issuer enters to commit a direct engagement: the customer, what is
/// owed, and optionally the catalogue item (and its variant) it is an instance of.
@immutable
class DirectEngagementInput {
  const DirectEngagementInput({
    required this.subjectId,
    required this.description,
    required this.quantity,
    this.unit = '',
    this.itemId,
    this.variantId,
  });

  final String subjectId;
  final String description;

  /// An exact decimal, as typed.
  final String quantity;
  final String unit;
  final String? itemId;
  final String? variantId;

  Map<String, Object?> toWire() => {
    'subject_id': subjectId,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'item_id': itemId,
    'variant_id': variantId,
  };
}

/// Why the server refused, as a person can act on it.
enum FulfilmentRefusalKind {
  /// DKF02: the engagement moved on since it was read; read it again.
  stale,

  /// DKF04, DKF03: that step is not allowed from this state, or the source is
  /// not yet commercial evidence.
  state,

  /// DKF05: the request was used for something else; make a new one.
  requestReused,

  /// DKF06: a fact is missing or out of range (the detail names it).
  incomplete,

  /// DKF01: unknown engagement, source, customer or item.
  unknown,

  /// DKF10: service fulfilment is off in this business.
  featureOff,

  /// DKF07 and a missing right: not allowed.
  notAllowed,
}

class FulfilmentRefusal implements TypedRefusal {
  const FulfilmentRefusal(this.kind, {this.detail = ''});

  final FulfilmentRefusalKind kind;

  /// What the server attached: for [FulfilmentRefusalKind.stale] the current
  /// revision, for [FulfilmentRefusalKind.incomplete] the field.
  final String detail;

  /// The current revision a stale refusal names, when it does.
  int? get currentRevision =>
      kind == FulfilmentRefusalKind.stale ? int.tryParse(detail) : null;

  @override
  String toString() => 'FulfilmentRefusal($kind, $detail)';
}

/// The engagements of one business. A write names its request identity: the same
/// request answers the same, a changed payload under it is refused.
abstract interface class ServiceFulfilmentRepository {
  Future<List<ServiceFulfilment>> fulfilments(String workspaceId);

  Future<ServiceFulfilment> fulfilment(String workspaceId, String fulfilmentId);

  /// The engagement a quote or invoice line already has, or null.
  Future<ServiceFulfilment?> ofLine(
    String workspaceId, {
    required String kind,
    required String id,
    required String lineId,
  });

  /// Opens the engagement of a quote or invoice line, or finds it.
  Future<FulfilmentOpened> openFromLine(
    String workspaceId, {
    required String requestId,
    required String kind,
    required String id,
    required String lineId,
  });

  /// Commits a direct engagement.
  Future<FulfilmentOpened> openDirect(
    String workspaceId, {
    required String requestId,
    required DirectEngagementInput input,
  });

  /// One step at the revision the engagement was read at.
  Future<ServiceFulfilment> transition(
    String workspaceId,
    String fulfilmentId, {
    required int expectedRevision,
    required FulfilmentState to,
    required String requestId,
    String reason = '',
  });

  /// Records that [lineId] of [invoiceId] billed a direct engagement.
  Future<ServiceFulfilment> linkInvoice(
    String workspaceId,
    String fulfilmentId, {
    required String invoiceId,
    required String lineId,
  });
}
