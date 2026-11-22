// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 -- the Demo's engagements, with the rules of 0851 (one per canonical source
// line, append-only steps at an expected revision, one request one step), reading the
// space's quotes and invoices and changing none. Its answers are the server's JSON,
// read back through the real reader: the Demo cannot drift from the shape.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/customer_quote.dart';
import '../../../features/money/domain/service_fulfilment.dart';

typedef _Key = ({String kind, String id, String line});

class _Source {
  const _Source(this.key, this.subjectId, this.scope, [this.revision]);

  final _Key key;
  final String subjectId;
  final Map<String, Object?> scope;
  final int? revision;
}

typedef _Step = ({int revision, FulfilmentState? from, FulfilmentState to, String reason, String actor, DateTime at});

class _Engagement {
  _Engagement(this.id, this.source, this.itemId, this.variantId);

  final String id;
  final _Source source;
  final String? itemId;
  final String? variantId;
  FulfilmentState state = FulfilmentState.ordered;
  final steps = <_Step>[];
  final links = <({String invoiceId, String lineId})>[];

  int get revision => steps.length;
}

class FakeServiceFulfilmentRepository implements ServiceFulfilmentRepository {
  FakeServiceFulfilmentRepository({
    required this.workspaceId,
    required this.quotes,
    required this.invoices,
    required this.matches,
    required this.hasCustomer,
    required this.actor,
    required this.clock,
    this.seed,
  });

  final String workspaceId;
  final CustomerQuoteRepository quotes;
  final List<Invoice> Function() invoices;
  final Map<String, InvoiceMatch> Function() matches;

  /// Whether the business has this billing customer.
  final bool Function(String subjectId) hasCustomer;

  /// The member acting.
  final String Function() actor;
  final DateTime Function() clock;

  /// What the space already has, made through its own operations before the first answer.
  final Future<void> Function(FakeServiceFulfilmentRepository repo)? seed;
  Future<void>? _seeding;
  var _inSeed = false;

  Future<void> _ready() async {
    final make = seed;
    if (make == null || _inSeed) {
      return;
    }
    _seeding ??= () async {
      _inSeed = true;
      try {
        await make(this);
      } finally {
        _inSeed = false;
      }
    }();
    await _seeding;
  }

  final _items = <_Engagement>[];

  /// request id -> what it asked and what it made or did.
  final _requests =
      <String, ({String digest, String fulfilmentId, int revision})>{};
  var _next = 1;

  static FulfilmentRefusal _refuse(
    FulfilmentRefusalKind kind, [
    String detail = '',
  ]) => FulfilmentRefusal(kind, detail: detail);

  @override
  Future<List<ServiceFulfilment>> fulfilments(String workspaceId) async {
    await _ready();
    return [for (final e in _items) await _view(e)];
  }

  @override
  Future<ServiceFulfilment> fulfilment(
    String workspaceId,
    String fulfilmentId,
  ) async {
    await _ready();
    return _view(_find(fulfilmentId));
  }

  @override
  Future<ServiceFulfilment?> ofLine(
    String workspaceId, {
    required String kind,
    required String id,
    required String lineId,
  }) async {
    await _ready();
    final source = await _source(workspaceId, kind, id, lineId);
    final found = _byKey(source.key);
    return found == null ? null : await _view(found);
  }

  @override
  Future<FulfilmentOpened> openFromLine(
    String workspaceId, {
    required String requestId,
    required String kind,
    required String id,
    required String lineId,
  }) async {
    await _ready();
    if (kind != 'quote' && kind != 'invoice') {
      throw _refuse(FulfilmentRefusalKind.incomplete, 'kind');
    }
    final digest = '$kind|$id|$lineId';
    final replay = await _replay(requestId, digest);
    if (replay != null) return replay;
    final source = await _source(workspaceId, kind, id, lineId);
    final found = _byKey(source.key);
    if (found != null) {
      return FulfilmentOpened(
        fulfilment: await _view(found),
        created: false,
        replayed: false,
      );
    }
    return _create(source, requestId, digest);
  }

  @override
  Future<FulfilmentOpened> openDirect(
    String workspaceId, {
    required String requestId,
    required DirectEngagementInput input,
  }) async {
    await _ready();
    final digest = 'direct|${input.toWire()}';
    final replay = await _replay(requestId, digest);
    if (replay != null) return replay;
    if (!hasCustomer(input.subjectId)) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'subject');
    }
    final description = input.description.trim();
    final quantity = num.tryParse(input.quantity.trim());
    if (description.isEmpty || description.length > 200) {
      throw _refuse(FulfilmentRefusalKind.incomplete, 'description');
    }
    if (quantity == null || quantity <= 0 || quantity > 1000000) {
      throw _refuse(FulfilmentRefusalKind.incomplete, 'quantity');
    }
    final id = 'fulfilment-${_next++}';
    final source = _Source(
      (kind: 'direct', id: id, line: 'line-$id'),
      input.subjectId,
      {
        'description': description,
        'quantity': input.quantity.trim(),
        'unit': input.unit.trim(),
      },
    );
    return _create(
      source,
      requestId,
      digest,
      id: id,
      itemId: input.itemId,
      variantId: input.variantId,
    );
  }

  @override
  Future<ServiceFulfilment> transition(
    String workspaceId,
    String fulfilmentId, {
    required int expectedRevision,
    required FulfilmentState to,
    required String requestId,
    String reason = '',
  }) async {
    await _ready();
    final e = _find(fulfilmentId);
    final why = reason.trim();
    final digest = '$fulfilmentId|$expectedRevision|${to.wire}|$why';
    final prior = _requests[requestId];
    if (prior != null) {
      if (prior.fulfilmentId != e.id || prior.digest != digest) {
        throw _refuse(FulfilmentRefusalKind.requestReused, 'request');
      }
      return _view(e);
    }
    if (to == FulfilmentState.ordered) {
      throw _refuse(FulfilmentRefusalKind.incomplete, 'state');
    }
    if (e.revision != expectedRevision) {
      throw _refuse(FulfilmentRefusalKind.stale, '${e.revision}');
    }
    if (!nextSteps(e.state).contains(to)) {
      throw _refuse(FulfilmentRefusalKind.state, e.state.wire);
    }
    if (stepNeedsReason(to) && why.isEmpty) {
      throw _refuse(FulfilmentRefusalKind.incomplete, 'reason');
    }
    final from = e.state;
    e.state = to;
    e.steps.add((revision: e.revision + 1, from: from, to: to, reason: why, actor: actor(), at: clock()));
    _requests[requestId] = (
      digest: digest,
      fulfilmentId: e.id,
      revision: e.revision,
    );
    return _view(e);
  }

  @override
  Future<ServiceFulfilment> linkInvoice(
    String workspaceId,
    String fulfilmentId, {
    required String invoiceId,
    required String lineId,
  }) async {
    await _ready();
    final e = _find(fulfilmentId);
    if (e.source.key.kind != 'direct') {
      throw _refuse(FulfilmentRefusalKind.state, 'not_direct');
    }
    final invoice = invoices().where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'invoice');
    }
    if (invoice.memberId != e.source.subjectId || invoice.totalCents <= 0) {
      throw _refuse(FulfilmentRefusalKind.state, 'subject');
    }
    if (!_hasLine(invoice, lineId)) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'line');
    }
    final holder = _items.where(
      (o) => o.links.any((l) => l.invoiceId == invoiceId && l.lineId == lineId),
    );
    if (holder.isNotEmpty && holder.first.id != e.id) {
      throw _refuse(FulfilmentRefusalKind.state, 'taken');
    }
    if (holder.isEmpty) {
      final quoted = (await quotes.quotes(workspaceId))
          .any((q) => q.invoiceId == invoiceId);
      final own =
          _byKey((kind: 'invoice', id: invoiceId, line: lineId)) != null;
      if (quoted || own) {
        throw _refuse(FulfilmentRefusalKind.state, 'taken');
      }
      e.links.add((invoiceId: invoiceId, lineId: lineId));
    }
    return _view(e);
  }

  // ── sources ──────────────────────────────────────────────────────────────

  static bool _hasLine(Invoice invoice, String lineId) => invoice.lines.any(
    (l) =>
        l.commercial is CommercialLineV1 &&
        (l.commercial! as CommercialLineV1).lineId == lineId,
  );

  Future<_Source> _source(
    String workspaceId,
    String kind,
    String id,
    String lineId,
  ) async {
    if (kind == 'quote') return _quoteSource(workspaceId, id, lineId);
    final invoice = invoices().where((i) => i.id == id).firstOrNull;
    if (invoice == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'invoice');
    }
    if (invoice.totalCents <= 0) {
      throw _refuse(FulfilmentRefusalKind.state, 'not_a_service_invoice');
    }
    final line = invoice.lines
        .where(
          (l) =>
              l.commercial is CommercialLineV1 &&
              (l.commercial! as CommercialLineV1).lineId == lineId,
        )
        .firstOrNull;
    if (line == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'line');
    }
    // billed from a quote: that quote's line is the source
    final quoted = (await quotes.quotes(workspaceId))
        .where((q) => q.invoiceId == id)
        .firstOrNull;
    if (quoted != null) return _quoteSource(workspaceId, quoted.id, lineId);
    // billed from a direct commitment: that commitment is the source
    final linked = _items
        .where(
          (e) => e.links.any((l) => l.invoiceId == id && l.lineId == lineId),
        )
        .firstOrNull;
    if (linked != null) return linked.source;
    final v1 = line.commercial! as CommercialLineV1;
    return _Source(
      (kind: 'invoice', id: id, line: lineId),
      invoice.memberId,
      {
        'description': line.label,
        'quantity': v1.quantity.toString(),
        'unit': v1.unit.label.isEmpty ? v1.unit.code : v1.unit.label,
      },
    );
  }

  Future<_Source> _quoteSource(
    String workspaceId,
    String id,
    String lineId,
  ) async {
    final quote = (await quotes.quotes(workspaceId))
        .where((q) => q.id == id)
        .firstOrNull;
    if (quote == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'quote');
    }
    if (quote.status != QuoteStatus.accepted &&
        quote.status != QuoteStatus.converted) {
      throw _refuse(FulfilmentRefusalKind.state, 'not_accepted');
    }
    final accepted = quote.revisions
        .where((r) => r.revision == quote.decision?.revision)
        .firstOrNull;
    final line = accepted?.lines.where((l) => l.lineId == lineId).firstOrNull;
    if (accepted == null || line == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'line');
    }
    return _Source(
      (kind: 'quote', id: id, line: lineId),
      quote.subjectId,
      {
        'description': line.description,
        'quantity': line.quantity,
        'unit': line.unitLabel.isEmpty ? line.unitCode : line.unitLabel,
      },
      accepted.revision,
    );
  }

  // ── the store ────────────────────────────────────────────────────────────

  _Engagement _find(String id) {
    final found = _items.where((e) => e.id == id).firstOrNull;
    if (found == null) {
      throw _refuse(FulfilmentRefusalKind.unknown, 'fulfilment');
    }
    return found;
  }

  _Engagement? _byKey(_Key key) =>
      _items.where((e) => e.source.key == key).firstOrNull;

  Future<FulfilmentOpened?> _replay(String requestId, String digest) async {
    final prior = _requests[requestId];
    if (prior == null) return null;
    if (prior.digest != digest || prior.revision != 1) {
      throw _refuse(FulfilmentRefusalKind.requestReused, 'request');
    }
    return FulfilmentOpened(
      fulfilment: await _view(_find(prior.fulfilmentId)),
      created: false,
      replayed: true,
    );
  }

  Future<FulfilmentOpened> _create(
    _Source source,
    String requestId,
    String digest, {
    String? id,
    String? itemId,
    String? variantId,
  }) async {
    final e = _Engagement(
      id ?? 'fulfilment-${_next++}',
      source,
      itemId,
      variantId,
    );
    e.steps.add((revision: 1, from: null, to: FulfilmentState.ordered, reason: '', actor: actor(), at: clock()));
    _items.add(e);
    _requests[requestId] = (digest: digest, fulfilmentId: e.id, revision: 1);
    return FulfilmentOpened(
      fulfilment: await _view(e),
      created: true,
      replayed: false,
    );
  }

  /// The engagement as `service_fulfilment_json` answers it, read back through
  /// the real reader.
  Future<ServiceFulfilment> _view(_Engagement e) async {
    final qs = await quotes.quotes(workspaceId);
    final billed = <String>{
      for (final q in _quotedInvoices(e, qs)) q,
      if (e.source.key.kind == 'invoice') e.source.key.id,
      for (final l in e.links) l.invoiceId,
    };
    return ServiceFulfilment.fromJson({
      'fulfilment_id': e.id,
      'subject_id': e.source.subjectId,
      'state': e.state.wire,
      'revision': e.revision,
      'source': {
        'kind': e.source.key.kind,
        'id': e.source.key.id,
        'revision': e.source.revision,
        'line_id': e.source.key.line,
      },
      'item_id': e.itemId,
      'variant_id': e.variantId,
      'scope': e.source.scope,
      'history': [
        for (final s in e.steps)
          {
            'revision': s.revision,
            'from': s.from?.wire,
            'to': s.to.wire,
            'reason': s.reason,
            'actor_id': s.actor,
            'at': s.at.toUtc().toIso8601String(),
          },
      ],
      'quote': _quoteOf(e, qs),
      'invoices': [
        for (final i in invoices().where((i) => billed.contains(i.id)))
          {
            'invoice_id': i.id,
            'number': i.number,
            'total_cents': i.totalCents,
            'currency': i.currency,
            'paid_cents': matches()[i.id]?.paidCents ?? 0,
            'corrections': [
              for (final c in invoices().where(
                (c) => c.replacesInvoiceId == i.id,
              ))
                {
                  'invoice_id': c.id,
                  'number': c.number,
                  'total_cents': c.totalCents,
                },
            ],
          },
      ],
    });
  }

  Map<String, Object?>? _quoteOf(_Engagement e, List<CustomerQuote> qs) {
    if (e.source.key.kind != 'quote') return null;
    final quote = qs.where((q) => q.id == e.source.key.id).firstOrNull;
    return quote == null
        ? null
        : {
            'quote_id': quote.id,
            'reference': quote.reference,
            'status': quote.status.name,
          };
  }

  Iterable<String> _quotedInvoices(_Engagement e, List<CustomerQuote> qs) =>
      e.source.key.kind == 'quote'
      ? qs
            .where((q) => q.id == e.source.key.id && q.invoiceId != null)
            .map((q) => q.invoiceId!)
      : const [];
}
