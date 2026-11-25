// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the in-memory customer quotes the Demo and the widget tests
// read, with the server's own rules: a draft has no amounts and no number, a
// send freezes the revision (its amounts worked out at the Demo seller's tax
// rate) and takes the next reference, an amendment is another revision, a stale
// version is refused. Nothing here is a second tax engine: the Demo seller has
// one rate, and the real issuer computes every real amount.
import '../../../features/money/domain/customer_quote.dart';
import '../../../features/money/domain/quote_validity.dart';
import '../../../features/money/domain/standalone_invoice.dart';

class FakeCustomerQuoteRepository implements CustomerQuoteRepository {
  FakeCustomerQuoteRepository({
    this.mayIssue = _always,
    this.vatPercent = 20,
    this.currency = 'EUR',
    required this._clock,
  });

  static bool _always() => true;

  /// Whether the signed-in person holds the right to issue invoices.
  bool Function() mayIssue;

  /// The Demo seller's one VAT rate, the percent every net line is taxed at.
  final int vatPercent;
  final String currency;

  /// #4168 — when set, a conversion issues the REAL invoice into the space's money.
  StandaloneInvoiceCommands? invoicing;

  /// #4291 — how long a quote stays valid: the business's settings, else the default.
  QuoteValidity Function() validity = () => const QuoteValidity();
  final DateTime Function() _clock;

  final Map<String, List<_Quote>> _byWorkspace = {};
  int _next = 1;
  int _reference = 1;
  int _line = 1;
  int _invoice = 900;

  /// An error the next call raises, once.
  Object? failNext;

  /// The calls the screens made, for tests.
  final List<String> calls = [];

  List<_Quote> _of(String workspaceId) =>
      _byWorkspace.putIfAbsent(workspaceId, () => []);

  void _check(String call, {bool write = false}) {
    calls.add(call);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    if (write && !mayIssue()) {
      throw const QuoteRefusal(QuoteRefusalKind.notAllowed);
    }
  }

  _Quote _find(String workspaceId, String id) => _of(workspaceId).firstWhere(
    (q) => q.id == id,
    orElse: () => throw const QuoteRefusal(QuoteRefusalKind.state),
  );

  /// Seeds a sent quote (revision 1) for [subjectId].
  void seedSent(
    String workspaceId, {
    required String subjectId,
    required List<StandaloneLine> lines,
    required DateTime issuedOn,
    required DateTime validUntil,
    // the notes of the first revision, and each later sent revision's lines
    ({String notes, List<List<StandaloneLine>> amendments}) extras = (notes: '', amendments: const []),
  }) {
    final q = _Quote('quote-${_next++}', subjectId);
    q.revisions.add(_Rev(1, issuedOn, validUntil, _withIds(lines), notes: extras.notes));
    for (final later in extras.amendments) {
      q.revisions.add(_Rev(q.revisions.length + 1, issuedOn, validUntil, _withIds(later), notes: extras.notes));
    }
    for (final rev in q.revisions) {
      _freeze(rev);
      rev.superseded = rev != q.revisions.last;
    }
    q
      ..reference = _newReference()
      ..status = QuoteStatus.sent;
    _of(workspaceId).add(q);
  }

  /// Marks the seeded quote [index] (0-based, in seed order) as accepted by the issuer.
  void seedAccepted(String workspaceId, int index, {required DateTime decidedOn, String source = 'email'}) {
    final q = _of(workspaceId)[index];
    q
      ..status = QuoteStatus.accepted
      ..decision = QuoteDecision(
        accepted: true,
        revision: q.revisions.last.revision,
        decidedOn: decidedOn,
        source: source,
        evidence: '',
      );
  }

  /// Seeds a draft (never sent) for [subjectId].
  void seedDraft(
    String workspaceId, {
    required String subjectId,
    required List<StandaloneLine> lines,
    required DateTime issuedOn,
    required DateTime validUntil,
  }) {
    final q = _Quote('quote-${_next++}', subjectId);
    q.revisions.add(_Rev(1, issuedOn, validUntil, lines));
    _of(workspaceId).add(q);
  }

  String _newReference() => 'QUO-${(_reference++).toString().padLeft(4, '0')}';

  /// Freezes the revision as the issuer does: each line's amounts worked out
  /// at the Demo seller's one rate (half up, per line), the total the sum of
  /// the lines.
  void _freeze(_Rev rev) {
    rev
      ..sent = true
      ..frozen = [for (final l in rev.lines) _frozenLine(l)];
    rev.totalCents = rev.frozen.fold<int>(
      0,
      (sum, l) => sum + (l['amount_cents']! as int),
    );
  }

  /// A line as `standalone_invoice_line_v1` freezes it: the invoice line
  /// snapshot (`label`, the exact facts in `commercial`), never the input.
  Map<String, Object?> _frozenLine(StandaloneLine l) {
    final net = ((double.tryParse(l.quantity) ?? 0) *
            (double.tryParse(l.unitPrice) ?? 0) * 100).round();
    final tax = (net * vatPercent / 100).round();
    return {
      'kind': 'service',
      'label': l.description,
      'supply': l.supply,
      'quantity': 1,
      'vat_percent': vatPercent,
      'amount_cents': net + tax,
      'vat_category': 'S',
      'commercial': {
        'version': 1,
        'line_id': l.lineId,
        'quantity': l.quantity,
        'unit': {'code': l.unitCode, 'label': l.unitLabel, 'un_ece_code': l.unEceCode},
        'supply': l.supply,
        'unit_price': {
          'amount': l.unitPrice,
          'currency': currency,
          'basis': l.grossPrice ? 'gross' : 'net',
          'base_quantity': l.baseQuantity,
        },
        'tax_facts': {'category': 'S', 'vat_percent': vatPercent},
        'amounts': {
          'currency': currency,
          'net_minor': '$net',
          'tax_minor': '$tax',
          'gross_minor': '${net + tax}',
          'rule': 'half_up_per_line',
        },
      },
    };
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  /// The quote as `customer_quote_v1` answers it, read back through the same
  /// reader the real repository uses: the Demo cannot drift from the shape.
  CustomerQuote _view(_Quote q) {
    final today = _clock();
    final day = DateTime(today.year, today.month, today.day);
    final current = q.revisions.where((r) => r.sent && !r.superseded).lastOrNull;
    final d = q.decision;
    return CustomerQuote.fromJson({
      'quote_id': q.id,
      'subject_id': q.subjectId,
      'reference': q.reference,
      'status': q.status.name,
      'expired':
          q.status == QuoteStatus.sent &&
          (current == null || current.validUntil.isBefore(day)),
      'revisions': [
        for (final r in q.revisions)
          {
            'revision': r.revision,
            'status': r.sent ? 'sent' : 'draft',
            'draft_version': r.version,
            'issued_on': _day(r.issuedOn),
            'valid_until': _day(r.validUntil),
            'buyer_reference': r.buyerReference,
            'purchase_order': r.purchaseOrder,
            'notes': r.notes,
            'lines': r.sent ? r.frozen : [for (final l in r.lines) l.toWire()],
            'totals': r.sent ? {'total_cents': r.totalCents, 'currency': currency} : null,
            'content_digest': r.sent ? 'demo-${q.id}-${r.revision}' : '',
            'superseded': r.superseded,
          },
      ],
      'decision': d == null
          ? null
          : {
              'decision': d.accepted ? 'accepted' : 'declined',
              'revision': d.revision,
              'decided_on': _day(d.decidedOn),
              'source': d.source,
              'evidence': d.evidence,
            },
      'conversion': q.invoiceId == null ? null : {'invoice_id': q.invoiceId},
    });
  }
  @override
  Future<List<CustomerQuote>> quotes(String workspaceId) async {
    _check('quotes');
    return [for (final q in _of(workspaceId).reversed) _view(q)];
  }

  @override
  Future<CustomerQuote> quote(String workspaceId, String quoteId) async {
    _check('quote');
    return _view(_find(workspaceId, quoteId));
  }

  List<StandaloneLine> _withIds(List<StandaloneLine> lines) => [
    for (final l in lines)
      if (l.lineId == null) l.withLineId('line-${_line++}') else l,
  ];

  @override
  Future<QuoteSaved> saveDraft(
    String workspaceId, {
    required QuoteDraftInput input,
    String? quoteId,
    int? expectedVersion,
  }) async {
    _check('saveDraft', write: true);
    final today = _clock();
    final on = input.issuedOn ?? DateTime(today.year, today.month, today.day);
    final rules = validity();
    final until = input.validUntil ?? rules.defaultEnd(on);
    if (!rules.allows(on, until)) {
      throw const QuoteRefusal(QuoteRefusalKind.incomplete, missing: ['valid_until']);
    }
    final q = quoteId == null
        ? (_Quote('quote-${_next++}', input.subjectId)..revisions.add(_Rev(1, on, until, const [])))
        : _find(workspaceId, quoteId);
    final rev = q.revisions.last;
    if (rev.sent) throw const QuoteRefusal(QuoteRefusalKind.state);
    if (quoteId != null && expectedVersion != rev.version) {
      throw const QuoteRefusal(QuoteRefusalKind.stale);
    }
    rev
      ..issuedOn = on
      ..validUntil = until
      ..buyerReference = input.buyerReference
      ..purchaseOrder = input.purchaseOrder
      ..notes = input.notes
      ..lines = _withIds(input.lines);
    if (quoteId == null) {
      _of(workspaceId).add(q);
    } else {
      rev.version++;
    }
    return QuoteSaved(quoteId: q.id, revision: rev.revision, version: rev.version);
  }

  @override
  Future<QuoteSaved> amend(String workspaceId, String quoteId) async {
    _check('amend', write: true);
    final q = _find(workspaceId, quoteId);
    if (q.status != QuoteStatus.sent || !q.revisions.last.sent) {
      throw const QuoteRefusal(QuoteRefusalKind.state);
    }
    final last = q.revisions.last;
    final next = _Rev(last.revision + 1, last.issuedOn, last.validUntil, last.lines,
        notes: last.notes)
      ..buyerReference = last.buyerReference
      ..purchaseOrder = last.purchaseOrder;
    q.revisions.add(next);
    return QuoteSaved(quoteId: q.id, revision: next.revision, version: next.version);
  }

  @override
  Future<QuoteSent> send(
    String workspaceId,
    String quoteId, {
    required int revision,
    required int version,
  }) async {
    _check('send', write: true);
    final q = _find(workspaceId, quoteId);
    final rev = q.revisions.where((r) => r.revision == revision).firstOrNull;
    if (rev == null) throw const QuoteRefusal(QuoteRefusalKind.state);
    if (rev.sent) {
      return QuoteSent(quoteId: q.id, reference: q.reference ?? '', revision: revision, replayed: true);
    }
    if (rev.version != version) throw const QuoteRefusal(QuoteRefusalKind.stale);
    if (rev.lines.isEmpty ||
        rev.lines.any((l) => l.description.isEmpty || l.quantity.isEmpty || l.unitPrice.isEmpty)) {
      throw const QuoteRefusal(QuoteRefusalKind.incomplete, missing: ['line_1']);
    }
    for (final earlier in q.revisions.where((r) => r.sent)) {
      earlier.superseded = true;
    }
    _freeze(rev);
    q
      ..reference ??= _newReference()
      ..status = QuoteStatus.sent;
    return QuoteSent(quoteId: q.id, reference: q.reference!, revision: revision, replayed: false);
  }

  @override
  Future<void> recordDecision(
    String workspaceId,
    String quoteId,
    QuoteDecisionInput decision,
  ) async {
    _check('recordDecision', write: true);
    final q = _find(workspaceId, quoteId);
    final current = q.revisions.where((r) => r.sent && !r.superseded).lastOrNull;
    if (q.status != QuoteStatus.sent || current == null || current.revision != decision.revision) {
      throw const QuoteRefusal(QuoteRefusalKind.state);
    }
    final today = _clock();
    final day = DateTime(today.year, today.month, today.day);
    if (decision.decidedOn.isAfter(day) || decision.decidedOn.isBefore(current.issuedOn)) {
      throw const QuoteRefusal(QuoteRefusalKind.incomplete, missing: ['decided_on']);
    }
    if (decision.accepted &&
        (decision.decidedOn.isAfter(current.validUntil) || day.isAfter(current.validUntil))) {
      throw const QuoteRefusal(QuoteRefusalKind.expired);
    }
    q
      ..status = decision.accepted ? QuoteStatus.accepted : QuoteStatus.declined
      ..decision = QuoteDecision(
        accepted: decision.accepted,
        revision: decision.revision,
        decidedOn: decision.decidedOn,
        source: decision.source,
        evidence: decision.evidence,
      );
  }

  @override
  Future<QuoteConversionPrep> prepareConversion(
    String workspaceId,
    String quoteId, {
    required DateTime serviceDate,
    required DateTime dueOn,
  }) async {
    _check('prepareConversion', write: true);
    final q = _find(workspaceId, quoteId);
    if (q.status != QuoteStatus.accepted) throw const QuoteRefusal(QuoteRefusalKind.state);
    final accepted = q.revisions.firstWhere((r) => r.revision == q.decision!.revision);
    final commands = invoicing;
    if (commands != null) return _previewInvoice(commands, workspaceId, q, accepted, serviceDate, dueOn);
    return QuoteConversionPrep(
      draftRevision: 1,
      missing: dueOn.isBefore(serviceDate) ? const ['due_on'] : const [],
      acceptedTotalCents: accepted.totalCents,
      wouldBeTotalCents: accepted.totalCents,
      currency: currency,
      contextChanged: false,
      reviewDigest: 'demo-${q.id}-${accepted.totalCents}',
    );
  }

  /// The real invoice of the accepted lines, previewed against what was accepted.
  Future<QuoteConversionPrep> _previewInvoice(
    StandaloneInvoiceCommands commands,
    String workspaceId,
    _Quote q,
    _Rev accepted,
    DateTime serviceDate,
    DateTime dueOn,
  ) async {
    final saved = await commands.saveDraft(
      workspaceId: workspaceId,
      draft: StandaloneDraft(
        draftId: q.conversionDraftId,
        revision: q.conversionRevision,
        subjectMemberId: q.subjectId,
        serviceDate: serviceDate,
        dueOn: dueOn,
        buyerReference: accepted.buyerReference,
        purchaseOrder: accepted.purchaseOrder,
        lines: accepted.lines,
      ),
    );
    q..conversionDraftId = saved.draftId..conversionRevision = saved.revision;
    final preview = await commands.preview(workspaceId: workspaceId, draftId: saved.draftId, revision: saved.revision);
    final changed = preview.missing.isEmpty && preview.totalCents != accepted.totalCents;
    q.conversionDigest = changed ? 'demo-${q.id}-${preview.totalCents}' : '';
    return QuoteConversionPrep(
      draftRevision: saved.revision,
      missing: preview.missing,
      acceptedTotalCents: accepted.totalCents,
      wouldBeTotalCents: preview.totalCents,
      currency: preview.currency.isEmpty ? currency : preview.currency,
      contextChanged: changed,
      reviewDigest: q.conversionDigest ?? '',
    );
  }

  @override
  Future<QuoteConverted> convert(
    String workspaceId,
    String quoteId, {
    required int draftRevision,
    required String requestId,
    String? reviewedDigest,
  }) async {
    _check('convert', write: true);
    final q = _find(workspaceId, quoteId);
    final invoice = q.invoiceId;
    if (invoice != null) {
      return QuoteConverted(invoiceId: invoice, number: q.invoiceNumber, replayed: true);
    }
    if (q.status != QuoteStatus.accepted) throw const QuoteRefusal(QuoteRefusalKind.state);
    final commands = invoicing;
    if (commands != null) {
      final draftId = q.conversionDraftId;
      if (draftId == null) throw const QuoteRefusal(QuoteRefusalKind.state);
      final digest = q.conversionDigest ?? '';
      if (digest.isNotEmpty && reviewedDigest != digest) {
        throw QuoteRefusal(QuoteRefusalKind.needsReview, detail: digest);
      }
      final issued = await commands.issue(workspaceId: workspaceId, draftId: draftId, revision: draftRevision, requestId: requestId);
      q..status = QuoteStatus.converted..invoiceId = issued.invoiceId..invoiceNumber = issued.number;
      return QuoteConverted(invoiceId: issued.invoiceId, number: issued.number, replayed: false);
    }
    q
      ..status = QuoteStatus.converted
      ..invoiceId = 'demo-quote-invoice-${q.id}'
      ..invoiceNumber = 'INV-${(_invoice++).toString().padLeft(4, '0')}';
    return QuoteConverted(invoiceId: q.invoiceId!, number: q.invoiceNumber, replayed: false);
  }

  @override
  Future<void> cancel(String workspaceId, String quoteId) async {
    _check('cancel', write: true);
    final q = _find(workspaceId, quoteId);
    if (q.status != QuoteStatus.sent) throw const QuoteRefusal(QuoteRefusalKind.state);
    q.status = QuoteStatus.cancelled;
  }

  @override
  Future<void> discardDraft(String workspaceId, String quoteId) async {
    _check('discardDraft', write: true);
    final q = _find(workspaceId, quoteId);
    if (q.status != QuoteStatus.draft || q.revisions.any((r) => r.sent)) {
      throw const QuoteRefusal(QuoteRefusalKind.state);
    }
    _of(workspaceId).remove(q);
  }
}

class _Quote {
  _Quote(this.id, this.subjectId);

  final String id;
  final String subjectId;
  String? reference;
  QuoteStatus status = QuoteStatus.draft;
  final List<_Rev> revisions = [];
  QuoteDecision? decision;
  String? invoiceId;
  String? invoiceNumber;
  String? conversionDraftId; // the draft a conversion prepared, and the digest of what differs
  int? conversionRevision;
  String? conversionDigest;
}

class _Rev {
  _Rev(this.revision, this.issuedOn, this.validUntil, List<StandaloneLine> lines, {this.notes = ''})
    : lines = [...lines];

  final int revision;
  DateTime issuedOn;
  DateTime validUntil;
  List<StandaloneLine> lines;
  String notes;
  String buyerReference = '';
  String purchaseOrder = '';
  int version = 1;
  bool sent = false;
  bool superseded = false;
  int totalCents = 0;

  /// The invoice line snapshots of a sent revision.
  List<Map<String, Object?>> frozen = const [];
}
