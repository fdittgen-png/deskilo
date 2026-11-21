// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the in-memory customer quotes the Demo and the widget tests
// read, with the server's own rules: a draft has no amounts and no number, a
// send freezes the revision (its amounts worked out at the Demo seller's tax
// rate) and takes the next reference, an amendment is another revision, a stale
// version is refused. Nothing here is a second tax engine: the Demo seller has
// one rate, and the real issuer computes every real amount.
import '../../../features/money/domain/customer_quote.dart';
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
  final DateTime Function() _clock;

  final Map<String, List<_Quote>> _byWorkspace = {};
  int _next = 1;
  int _reference = 1;
  int _line = 1;

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
    String notes = '',
  }) {
    final q = _Quote('quote-${_next++}', subjectId);
    final rev = _Rev(1, issuedOn, validUntil, lines, notes: notes);
    _freeze(rev);
    q
      ..reference = _newReference()
      ..status = QuoteStatus.sent
      ..revisions.add(rev);
    _of(workspaceId).add(q);
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

  /// Worked out from the lines at the Demo seller's one rate; a net line.
  void _freeze(_Rev rev) {
    var net = 0.0;
    for (final l in rev.lines) {
      net += (double.tryParse(l.quantity) ?? 0) * (double.tryParse(l.unitPrice) ?? 0);
    }
    rev
      ..sent = true
      ..totalCents = (net * (100 + vatPercent)).round();
  }

  CustomerQuote _view(_Quote q) {
    final today = _clock();
    final day = DateTime(today.year, today.month, today.day);
    final current = q.revisions.where((r) => r.sent && !r.superseded).lastOrNull;
    return CustomerQuote(
      id: q.id,
      subjectId: q.subjectId,
      reference: q.reference,
      status: q.status,
      expired:
          q.status == QuoteStatus.sent &&
          (current == null || current.validUntil.isBefore(day)),
      revisions: [
        for (final r in q.revisions)
          QuoteRevision(
            revision: r.revision,
            sent: r.sent,
            draftVersion: r.version,
            issuedOn: r.issuedOn,
            validUntil: r.validUntil,
            buyerReference: r.buyerReference,
            purchaseOrder: r.purchaseOrder,
            notes: r.notes,
            lines: r.lines,
            totals: r.sent ? QuoteTotals(totalCents: r.totalCents, currency: currency) : null,
            contentDigest: r.sent ? 'demo-${q.id}-${r.revision}' : '',
            superseded: r.superseded,
          ),
      ],
      decision: null,
      invoiceId: null,
    );
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
    final until = input.validUntil ?? on.add(const Duration(days: 30));
    if (until.isBefore(on) || until.isAfter(on.add(const Duration(days: 365)))) {
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
}
