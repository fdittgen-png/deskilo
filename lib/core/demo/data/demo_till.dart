// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the Demo's till: the server's rules of the counter receipt, in memory. A draft prices each line from the
// reference business's shop catalogue (a price on the GROSS basis, half away from zero once per line, the totals the
// sums of the lines); a sale numbers the receipt from a counter of its own and answers the same sale again under the
// same request id. A country that is not ready is a Demo choice: [ready] false answers the server's `unavailable`.
//
// #4184 -- the readiness is the server's registry for the case the Demo's owners declared (no fiscal register
// obligation): France, Germany and Spain are supported with the specification each row rests on, Italy is
// unavailable, and a country the registry does not name has no operation at all. A sale freezes its version-1
// document, read back through the same versioned reader as the server's.
import 'dart:math' show pow;

import 'package:deskilo/features/money/domain/counter_book.dart';
import 'package:deskilo/features/money/domain/counter_receipt_document.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_keypad.dart';
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../codes/dk_code.dart';
import '../../jurisdiction/installed_invoice_mentions.dart';
import 'demo_stock_registry.dart';
import 'demo_till_drawer.dart';

/// The server's refusal: its SQLSTATE as the code, its words as the message.
PostgrestException _refused(String code, String message, {String? reason, int? max}) => PostgrestException(
  message: message,
  code: code,
  details: reason == null ? null : '{"reason":"$reason"${max == null ? '' : ',"max":$max'}}',
);

/// #4436 -- the Demo's traced item at the counter: the oat milk is tracked by lot, and a sale takes it from the lot on
/// hand that expires first and is not expired yet (MILK-09 is past its date, so MILK-12; the expiry report's lots). The
/// gift basket is tracked piece by piece: its pieces are of lot BASKET-1, and a sale names each piece scanned by its tag.
const _tracedLots = <String, String>{'demo-item-milk': 'MILK-12', 'demo-item-basket': 'BASKET-1'};

/// The Demo's bag of coffee beans, which the seeded book sells.
const _beansName = 'Coffee beans';

/// The prices, in cents, of Demo items the stock registry does not carry (the variants' T-shirt, the counter's day desk).
const _unstocked = <String, int>{'demo-item-shirt': 1900, 'demo-item-basket': 3900, 'demo-item-apples': 1800, demoDayDeskItem: 2500};

/// #4185 -- the service the Demo's counter sells: a day at a hot desk, no stock behind it.
@visibleForTesting
const demoDayDeskItem = 'demo-service-day-desk';

/// One registry row of the declared case `none`, as `counter_country_operations` carries it (0893).
typedef _Row = ({String specification, String version, String from, bool supported, String note});

const _supportedOps = ['issue_receipt', 'correct_receipt', 'reconcile_tender'];

const _evidence = {
  'issue_receipt': 'pgTAP 520 (finalize, number once, frozen original) and 521 (totals in 0, 2 and 3 decimals)',
  'correct_receipt': 'pgTAP 522 (a correction is a new receipt citing the original)',
  'reconcile_tender': 'pgTAP 523 (tender states and reconciliation)',
};

/// The rows by the module id of the installed add-on that states the country's law: a country with no installed add-on has
/// no row (the country is the one in the add-on's capability id, `invoice_mentions.IT`).
const _registry = <String, _Row>{
  'fr.invoice_mentions': (
    specification: 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)',
    version: '2026-11',
    from: '2013-01-01',
    supported: true,
    note: '',
  ),
  'de.invoice_mentions': (
    specification: 'Umsatzsteuer-Durchführungsverordnung, § 33 (Rechnungen über Kleinbeträge)',
    version: '2026-11',
    from: '2017-01-01',
    supported: true,
    note: '',
  ),
  'es.invoice_mentions': (
    specification: 'Real Decreto 1619/2012, art. 4 y 7 (factura simplificada)',
    version: '2026-11',
    from: '2013-01-01',
    supported: true,
    note: '',
  ),
  'it.invoice_mentions': (
    specification: 'Decreto legislativo 127/2015, art. 2 (memorizzazione e trasmissione telematica dei corrispettivi)',
    version: 'D.Lgs. 127/2015',
    from: '2020-01-01',
    supported: false,
    note:
        "The retail sale in Italy is recorded through the telematic transmission of the day's takings; a receipt of this kind is not that, and no adapter transmits it.",
  ),
};


/// A receipt of the Demo's book, as the server holds it.
class _Rec {
  _Rec({required this.id, required this.kind, required this.lines, required this.totals, this.revision = 1, this.correctsId, this.reason = ''});

  final String id;
  final String kind;
  List<CounterBookLine> lines;
  TillTotals totals;
  int revision;
  String state = 'draft';
  String number = '';
  DateTime? finalizedAt;
  final String? correctsId;
  final String reason;
  String? tillId;
  final List<CounterBookTender> tenders = [];
  int refunded = 0;
  final Map<String, int> returned = {};

  CounterBookReceipt read() => CounterBookReceipt(
    id: id,
    kind: kind,
    state: state,
    currency: totals.currency,
    totalMinor: totals.grossMinor,
    taxMinor: totals.taxMinor,
    revision: revision,
    lines: lines,
    tenders: List.unmodifiable(tenders),
    number: number,
    finalizedAt: finalizedAt,
    correctsId: correctsId,
    reason: reason,
    tillId: tillId,
    refundedMinor: refunded,
    returned: {for (final e in returned.entries) e.key: counterQuantityText(e.value)},
  );
}

/// #4436 -- one traced line a sale froze: its receipt, when, and the track IDs it took, as `counter_line_tracks` keeps them.
typedef DemoSoldLine = ({String lineId, String receiptId, String number, DateTime at, List<TillTrack> tracks});

class DemoTill implements TillPort, TillOfflinePort, CounterBookPort {
  DemoTill({
    required this.country,
    required this.currency,
    required this.vatPercent,
    this.ready = true,
    this.minorDigits = 2,
    this.drawer,
    this.clock,
    this.maxDiscountPercent = demoMaxDiscountPercent,
    this.mayChangePrice = true,
  });

  /// #4476 -- the Demo business's `counter.max_discount_percent`: the largest discount at its tills.
  static const demoMaxDiscountPercent = 10;
  final int maxDiscountPercent;

  /// #4476 -- whether the Demo's cashier holds the right to change a price at the till (the Demo's owner does).
  final bool mayChangePrice;

  final String country;
  final String currency;
  final int vatPercent;

  /// False makes every operation unavailable, whatever the registry says.
  final bool ready;
  final int minorDigits;

  /// The cash drawer of this business: with its sessions on, a sale needs an open session on its till, and a cash sale
  /// goes into it.
  final DemoTillDrawer? drawer;
  final Map<String, String> _tillOf = {};

  /// The Demo's clock, stamping a sale; without it a sale is not kept for the trace.
  final DateTime Function()? clock;

  final List<DemoSoldLine> _soldLines = [];

  /// The traced lines sold so far, oldest first: what the trace finds from a track ID (#4436).
  List<DemoSoldLine> get soldLines => List.unmodifiable(_soldLines);

  /// #4373 -- the Demo's connection: while it is down every call to the server gets no answer at all, as when the line is lost.
  bool connected = true;

  void _line() {
    if (!connected) throw StateError('no connection');
  }

  int _revision = 0;
  int _sales = 0;
  int _tenderSeq = 0;
  final Map<String, TillDraft> _drafts = {};
  final Map<String, List<Map<String, Object?>>> _frozenLines = {};
  final Map<String, TillSold> _done = {};
  final Map<String, TillDraft> _answered = {};
  final Map<String, Map<String, Object?>> _frozen = {};

  _Row? get _row {
    for (final addOn in installedInvoiceMentions) {
      if (addOn.descriptor.capabilityId == 'invoice_mentions.$country') return _registry[addOn.descriptor.moduleId];
    }
    return null;
  }

  bool get _supported => ready && (_row?.supported ?? false);

  /// The basket each open draft priced: what its sale takes.
  final Map<String, List<TillLine>> _lines = {};
  final Map<String, Object?> _replayed = {};
  final Map<String, _Rec> _book = {};

  @override
  Future<TillReadiness> readiness(String workspaceId) async {
    _line();
    final row = _row;
    if (row == null) return TillReadiness(country: country, fiscalObligation: 'none', ready: false, operations: const []);
    final ok = ready && row.supported;
    return TillReadiness(
      country: country,
      fiscalObligation: 'none',
      ready: ok,
      operations: [
        for (final op in _supportedOps)
          TillOperation(
            operation: op,
            outcome: ok ? 'supported' : 'unavailable',
            reason: ok ? '' : 'unavailable',
            note: row.note,
            specification: row.specification,
            specificationVersion: row.version,
            effectiveFrom: row.from,
            adapter: row.supported ? 'counter_receipt_v1' : '',
            evidence: row.supported ? _evidence[op]! : 'tests: pgTAP 519 (the registry says unavailable)',
          ),
      ],
    );
  }

  int _tax(int gross) => gross - (gross * 100 / (100 + vatPercent)).round();

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async {
    _line();
    final replay = _answered[requestId];
    if (replay != null) return replay;
    if (tillId != null && drawer != null && !drawer!.hasOpenSession(tillId)) {
      throw _refused(DkCode.dkl12, 'open the till first', reason: 'till_open_first');
    }
    final id = receiptId ?? 'demo-receipt-${_drafts.length + _book.length + _sales + 1}';
    final known = _drafts[id];
    if (receiptId != null && (known == null || known.revision != expectedRevision)) {
      throw _refused(DkCode.dkl10, 'this receipt changed meanwhile');
    }
    var gross = 0;
    var tax = 0;
    final priced = <TillPricedLine>[];
    final frozen = <Map<String, Object?>>[];
    final booked = <CounterBookLine>[];
    for (final l in lines) {
      final unit = DemoStockRegistry.catalogue[l.itemId]?.$2 ?? _unstocked[l.itemId];
      if (unit == null) throw _refused(DkCode.dkl02, 'line_${priced.length + 1}_unit_price');
      final amount = _times(_priceOf(l, unit), l.quantity);
      gross += amount;
      tax += _tax(amount);
      priced.add(TillPricedLine(label: l.name, grossMinor: amount, quantity: l.quantity));
      frozen.add(_frozenLine(l, amount, _tax(amount)));
      booked.add(CounterBookLine(
        id: '$id-line-${booked.length + 1}',
        lineNo: booked.length + 1,
        label: l.name,
        quantity: l.quantity,
        unit: l.unit,
        grossMinor: amount,
        goods: DemoStockRegistry.catalogue.containsKey(l.itemId),
      ));
    }
    final totals = TillTotals(netMinor: gross - tax, taxMinor: tax, grossMinor: gross, currency: currency);
    final draft = TillDraft(receiptId: id, revision: ++_revision, totals: totals, lines: priced, issueReceipt: _supported ? 'supported' : 'unavailable');
    final rec = _book[id] ??= _Rec(id: id, kind: 'sale', lines: booked, totals: totals);
    rec
      ..lines = booked
      ..totals = totals
      ..revision = draft.revision
      ..tillId = tillId ?? rec.tillId;
    // money accepted for the offer as it was waits for an explicit reconciliation
    for (var i = 0; i < rec.tenders.length; i++) {
      final t = rec.tenders[i];
      if (t.kind == 'card' && t.state == 'accepted' && t.reconciliation == null) rec.tenders[i] = _with(t, reconciliation: 'needed');
    }
    _drafts[id] = draft;
    if (tillId != null) _tillOf[id] = tillId;
    _lines[id] = lines;
    _frozenLines[id] = frozen;
    _answered[requestId] = draft;
    return draft;
  }

  /// A line as the server freezes it: the `commercial` v1 facts, amounts as decimal strings of minor units.
  Map<String, Object?> _frozenLine(TillLine l, int gross, int tax) => {
    'kind': 'goods',
    'label': l.name,
    'amount_cents': gross,
    'vat_percent': vatPercent,
    'commercial': {
      'version': 1,
      'quantity': l.quantity,
      'unit': {'code': l.unit, 'label': l.unit},
      'amounts': {'currency': currency, 'net_minor': '${gross - tax}', 'tax_minor': '$tax', 'gross_minor': '$gross', 'rule': 'half_up_per_line'},
    },
  };

  /// [unit] (minor units of one inventory unit) times [quantity] (an exact decimal text), half away from zero.
  /// #4476 -- the unit price of [l] in minor units: the item's [listed] one, another with the right and a reason, or a
  /// discount within the limit; refused as the server refuses it.
  int _priceOf(TillLine l, int listed) {
    const million = 1000 * 1000;
    final discount = l.discount;
    if (discount != null) {
      if (l.price != null) throw _refused(DkCode.dkl02, 'a discount or a price, not both', reason: 'price_and_discount');
      final pct = tillMillionths(discount);
      if (pct == null || pct <= 0 || pct > 100 * million) throw _refused(DkCode.dkl02, 'a discount is a percentage', reason: 'discount');
      if (pct > maxDiscountPercent * million) throw _refused(DkCode.dkn01, 'beyond the limit', reason: 'discount_limit', max: maxDiscountPercent);
      return (listed * (100 * million - pct) / (100 * million)).round();
    }
    final price = l.price == null ? null : tillMillionths(l.price!);
    if (price == null) return listed;
    final minor = (price * pow(10, minorDigits) / million).round();
    if (minor == listed) return listed;
    if (!mayChangePrice) throw _refused(DkCode.dkn01, 'not allowed to change a price', reason: 'price');
    if ((l.priceReason ?? '').trim().isEmpty) throw _refused(DkCode.dkl02, 'a changed price needs its reason', reason: 'price_reason');
    return minor;
  }

  int _times(int unit, String quantity) => (unit * counterQuantityUnits(quantity) / 1000000).round();

  CounterBookTender _with(CounterBookTender t, {String? state, String? reconciliation, String? providerRef}) => CounterBookTender(
    id: t.id,
    part: t.part,
    kind: t.kind,
    amountMinor: t.amountMinor,
    state: state ?? t.state,
    reconciliation: reconciliation ?? t.reconciliation,
    providerKey: t.providerKey,
    providerRef: providerRef ?? t.providerRef,
  );

  ({_Rec rec, int at}) _tender(String tenderId) {
    for (final r in _book.values) {
      final at = r.tenders.indexWhere((t) => t.id == tenderId);
      if (at >= 0) return (rec: r, at: at);
    }
    throw _refused(DkCode.dkl04, 'not a card tender of this business');
  }

  String _number() => 'R-${(++_sales).toString().padLeft(5, '0')}';

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    _line();
    final again = _done[requestId];
    if (again != null) return again;
    final draft = _drafts[receiptId];
    if (!_supported) throw _refused(DkCode.dkl01, 'the country operation is not supported');
    final rec = _book[receiptId];
    if (draft == null || rec == null || rec.state != 'draft') throw _refused(DkCode.dkl04, 'this receipt is not an open draft');
    if (draft.revision != expectedRevision) throw _refused(DkCode.dkl10, 'this receipt changed meanwhile');
    if (rec.tenders.any((t) => t.open)) throw _refused(DkCode.dkl06, 'tender_open');
    var sum = 0;
    for (final t in tenders) {
      if (t.tenderId == null) {
        sum += t.amountMinor;
        continue;
      }
      final named = rec.tenders.where((x) => x.id == t.tenderId);
      if (named.isEmpty || !named.first.settles) throw _refused(DkCode.dkl06, 'tender_state');
    }
    // every accepted card tender of the sale is money taken: it counts, named or not
    sum += rec.tenders.where((t) => t.kind == 'card' && t.settles).fold<int>(0, (a, t) => a + t.amountMinor);
    if (sum != draft.totals.grossMinor) throw _refused(DkCode.dkl06, 'tender_sum');
    for (final t in tenders) {
      if (t.tenderId == null) {
        rec.tenders.add(CounterBookTender(id: 'demo-tender-${++_tenderSeq}', part: rec.tenders.length + 1, kind: t.kind, amountMinor: t.amountMinor, state: 'accepted'));
      }
    }
    final traced = [
      for (final (i, l) in (_lines[receiptId] ?? const <TillLine>[]).indexed)
        if (_tracedLots[l.itemId] case final lot?)
          TillSoldLine(
            lineNo: i + 1,
            tracks: [
              TillTrack(kind: 'lot', code: lot, quantity: l.quantity),
              for (final tag in [...l.pieces]..sort()) TillTrack(kind: 'piece', code: tag),
            ],
          ),
    ];
    final sold = TillSold(receiptId: receiptId, number: _number(), totals: draft.totals, lines: traced);
    final at = clock?.call();
    if (at != null) {
      for (final l in traced) {
        _soldLines.add((lineId: '$receiptId-line-${l.lineNo}', receiptId: receiptId, number: sold.number, at: at, tracks: l.tracks));
      }
    }
    _lines.remove(receiptId);
    final row = _row!;
    final t = draft.totals;
    _frozen[receiptId] = {
      'version': 1,
      'number': sold.number,
      'currency': currency,
      'price_basis': 'gross',
      'lines': _frozenLines.remove(receiptId),
      'totals': {'net_minor': '${t.netMinor}', 'tax_minor': '${t.taxMinor}', 'gross_minor': '${t.grossMinor}', 'currency': currency},
      'tax_breakdown': [
        {'percent': vatPercent, 'category': 'S', 'gross_minor': '${t.grossMinor}', 'net_minor': '${t.netMinor}', 'tax_minor': '${t.taxMinor}'},
      ],
      'source': {'kind': 'counter', 'ref': ''},
      'operation': {
        'country': country,
        'operation': 'issue_receipt',
        'regime': 'none',
        'specification': row.specification,
        'specification_version': row.version,
        'effective_from': row.from,
        'adapter': 'counter_receipt_v1',
        'confirmed': false,
      },
      'corrects': null,
    };
    rec
      ..state = 'finalized'
      ..number = sold.number
      ..finalizedAt = DateTime.utc(2026, 11, 23, 10, _sales);
    _drafts.remove(receiptId);
    final till = _tillOf.remove(receiptId);
    if (till != null) drawer?.recordCashSale(till, tenders.where((t) => t.kind == 'cash').fold(0, (a, t) => a + t.amountMinor), number: sold.number);
    return _done[requestId] = sold;
  }

  // #4373 -- the offline sales: the server's rules in memory (cash only, an item's price as it is now, each request once, a gap reported).
  final Map<String, OfflineSaleResult> _offlineByRequest = {};
  final Map<String, List<OfflineSaleRow>> _offlineRows = {};

  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) async {
    _line();
    final rows = _offlineRows.putIfAbsent(sessionId, () => []);
    final results = <OfflineSaleResult>[];
    for (final sale in sales) {
      final again = _offlineByRequest[sale.requestId];
      if (again != null) {
        results.add(OfflineSaleResult(seq: again.seq, requestId: again.requestId, accepted: again.accepted, reason: again.reason, number: again.number, replayed: true));
        continue;
      }
      // a session already closed takes no new sale, not even a refused one: its counted cash never moves
      if (drawer != null && !drawer!.sessionIsOpen(sessionId)) throw _refused(DkCode.dkl12, 'open the till first');
      final priced = [for (final l in sale.lines) DemoStockRegistry.catalogue[l.itemId]?.$2 ?? _unstocked[l.itemId]];
      final reason = [for (var i = 0; i < priced.length; i++) if (priced[i] == null) 'item' else if (priced[i] != sale.lines[i].unitMinor) 'price'].firstOrNull ?? '';
      final number = reason.isEmpty ? 'R-${(++_sales).toString().padLeft(5, '0')}' : '';
      final result = OfflineSaleResult(seq: sale.seq, requestId: sale.requestId, accepted: reason.isEmpty, reason: reason, number: number, replayed: false);
      _offlineByRequest[sale.requestId] = result;
      results.add(result);
      drawer?.recordOfflineSale(sessionId, cashMinor: reason.isEmpty ? sale.totalMinor : sale.cashGivenMinor - sale.changeMinor, accepted: reason.isEmpty, number: number);
      rows.add(OfflineSaleRow(
        seq: sale.seq, accepted: reason.isEmpty, reason: reason, number: number, totalMinor: reason.isEmpty ? sale.totalMinor : null,
        cashGivenMinor: sale.cashGivenMinor, changeMinor: sale.changeMinor, occurredAt: sale.occurredAt,
      ));
    }
    return OfflineSyncAnswer(results: results, gaps: _gapsOf(rows));
  }

  @override
  Future<OfflineList> list(String workspaceId, {required String sessionId}) async {
    _line();
    final rows = [...?_offlineRows[sessionId]]..sort((a, b) => a.seq.compareTo(b.seq));
    return OfflineList(sales: rows, gaps: _gapsOf(rows));
  }

  List<int> _gapsOf(List<OfflineSaleRow> rows) {
    final seen = {for (final r in rows) r.seq};
    final top = seen.fold<int>(0, (a, b) => a > b ? a : b);
    return [for (var n = 1; n <= top; n++) if (!seen.contains(n)) n];
  }

  @override
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId) async {
    _line();
    final frozen = _frozen[receiptId];
    if (frozen == null) throw _refused(DkCode.dkl04, 'this receipt is not finalized');
    return CounterReceiptDocument.decode(frozen);
  }

  @override
  Future<TillCardAsked> requestCard(String workspaceId, {required String requestId, required String receiptId, required int amountMinor}) async {
    final again = _replayed[requestId];
    if (again is TillCardAsked) return again;
    final rec = _book[receiptId];
    if (rec == null || rec.state != 'draft') throw _refused(DkCode.dkl04, 'this receipt is not an open draft');
    if (rec.tenders.any((t) => t.state == 'unknown')) throw _refused(DkCode.dkl11, 'an authorization of this sale is unknown');
    final held = rec.tenders.where((t) => t.state == 'requested' || t.state == 'accepted').fold<int>(0, (a, t) => a + t.amountMinor);
    if (held + amountMinor > rec.totals.grossMinor) throw _refused(DkCode.dkl06, 'tender_sum');
    final tender = CounterBookTender(
      id: 'demo-tender-${++_tenderSeq}',
      part: rec.tenders.length + 1,
      kind: 'card',
      amountMinor: amountMinor,
      state: 'requested',
      providerKey: 'dk-$requestId',
    );
    rec.tenders.add(tender);
    _offered[tender.id] = rec.revision;
    return _replayed[requestId] = TillCardAsked(tenderId: tender.id, providerKey: tender.providerKey, amountMinor: amountMinor);
  }

  /// The revision each card authorization was asked for.
  final Map<String, int> _offered = {};

  @override
  Future<({String state, String? reconciliation})> resolveCard(String workspaceId, {required String requestId, required String tenderId, required String outcome, String providerRef = ''}) async {
    final again = _replayed[requestId];
    if (again is ({String state, String? reconciliation})) return again;
    final (:rec, :at) = _tender(tenderId);
    final t = rec.tenders[at];
    if (t.state != 'requested' && t.state != 'unknown') throw _refused(DkCode.dkl11, 'this authorization is already settled');
    if (t.state == 'unknown' && outcome == 'unknown') throw _refused(DkCode.dkl11, 'this authorization is already unknown');
    final moved = outcome == 'accepted' && (rec.state != 'draft' || rec.revision != _offered[tenderId]);
    rec.tenders[at] = _with(t, state: outcome, reconciliation: moved ? 'needed' : null, providerRef: providerRef);
    final answer = (state: outcome, reconciliation: moved ? 'needed' : null);
    _replayed[requestId] = answer;
    return answer;
  }

  // ── the book ──

  @override
  Future<CounterBookReceipt?> openDraft(String workspaceId) async =>
      _book.values.where((r) => r.state == 'draft' && r.lines.isNotEmpty).lastOrNull?.read();

  @override
  Future<CounterBook> book(String workspaceId) async {
    final shown = [
      for (final r in _book.values)
        if (r.state == 'finalized' || r.tenders.any((t) => t.kind == 'card' && t.state != 'refused')) r.read(),
    ]..sort((a, b) => (b.finalizedAt ?? DateTime.utc(9999)).compareTo(a.finalizedAt ?? DateTime.utc(9999)));
    return CounterBook(shown);
  }

  @override
  Future<String> correct(String workspaceId, {required String requestId, required String originalId, required List<CounterBookQuantity> lines, required String reason}) async {
    final again = _replayed[requestId];
    if (again is String) return again;
    final orig = _book[originalId];
    if (orig == null || orig.state != 'finalized' || orig.kind != 'sale') throw _refused(DkCode.dkl04, 'only a finalized sale is corrected');
    final view = CounterBook([for (final r in _book.values) r.read()]);
    final made = <CounterBookLine>[];
    var gross = 0;
    var tax = 0;
    for (final q in lines) {
      final line = orig.lines.where((l) => l.id == q.lineId).firstOrNull;
      if (line == null || made.any((m) => m.correctsLineId == line.id)) throw _refused(DkCode.dkl08, '{"reason":"line_unknown"}');
      final units = counterQuantityUnits(q.quantity);
      final left = counterQuantityUnits(view.leftOf(line));
      if (units <= 0) throw _refused(DkCode.dkl08, '{"reason":"quantity"}');
      if (units > left) throw _refused(DkCode.dkl08, '{"reason":"beyond_original","left":"${counterQuantityText(left)}"}');
      final credited = _credited(line.id);
      final amount = units == left ? line.grossMinor - credited : (line.grossMinor * units / counterQuantityUnits(line.quantity)).round();
      gross += amount;
      tax += _tax(amount);
      made.add(CounterBookLine(
        id: 'demo-correction-${_book.length + 1}-line-${made.length + 1}',
        lineNo: made.length + 1,
        label: line.label,
        quantity: counterQuantityText(units),
        unit: line.unit,
        grossMinor: amount,
        goods: line.goods,
        correctsLineId: line.id,
      ));
    }
    if (made.isEmpty || gross <= 0) throw _refused(DkCode.dkl08, '{"reason":"empty"}');
    final rec = _Rec(
      id: 'demo-correction-${_book.length + 1}',
      kind: 'correction',
      lines: made,
      totals: TillTotals(netMinor: gross - tax, taxMinor: tax, grossMinor: gross, currency: orig.totals.currency),
      correctsId: orig.id,
      reason: reason,
    )
      ..state = 'finalized'
      ..number = _number()
      ..finalizedAt = DateTime.utc(2026, 11, 23, 10, _sales);
    _book[rec.id] = rec;
    return _replayed[requestId] = rec.number;
  }

  /// What the finalized corrections of [lineId] already credit.
  int _credited(String lineId) => [
    for (final r in _book.values)
      if (r.kind == 'correction')
        for (final l in r.lines)
          if (l.correctsLineId == lineId) l.grossMinor,
  ].fold(0, (a, b) => a + b);

  _Rec _correction(String id) {
    final rec = _book[id];
    if (rec == null || rec.kind != 'correction' || rec.state != 'finalized') throw _refused(DkCode.dkl04, 'this follows a finalized correction');
    return rec;
  }

  @override
  Future<void> refund(String workspaceId, {required String requestId, required String correctionId, required List<CounterRefundPart> parts}) async {
    if (_replayed.containsKey(requestId)) return;
    final rec = _correction(correctionId);
    final sum = parts.fold<int>(0, (a, p) => a + p.amountMinor);
    if (parts.any((p) => p.amountMinor <= 0 || (p.kind != 'cash' && p.kind != 'other'))) throw _refused(DkCode.dkl06, 'refund_part');
    if (rec.refunded + sum > rec.totals.grossMinor) throw _refused(DkCode.dkl08, '{"reason":"refund_beyond"}');
    rec.refunded += sum;
    _replayed[requestId] = true;
  }

  @override
  Future<void> returnGoods(String workspaceId, {required String requestId, required String correctionId, required List<CounterBookQuantity> lines}) async {
    if (_replayed.containsKey(requestId)) return;
    final rec = _correction(correctionId);
    final moves = <String, int>{};
    for (final q in lines) {
      final line = rec.lines.where((l) => l.id == q.lineId && l.goods).firstOrNull;
      if (line == null || moves.containsKey(line.id)) throw _refused(DkCode.dkl08, '{"reason":"line_unknown"}');
      final units = counterQuantityUnits(q.quantity);
      if (units <= 0 || units > counterQuantityUnits(line.quantity) - (rec.returned[line.id] ?? 0)) {
        throw _refused(DkCode.dkl08, '{"reason":"return_beyond"}');
      }
      moves[line.id] = units;
    }
    for (final e in moves.entries) {
      rec.returned[e.key] = (rec.returned[e.key] ?? 0) + e.value;
    }
    _replayed[requestId] = true;
  }

  @override
  Future<void> resolveTender(String workspaceId, {required String requestId, required String tenderId, required String outcome, required String providerRef}) =>
      resolveCard(workspaceId, requestId: requestId, tenderId: tenderId, outcome: outcome, providerRef: providerRef);

  @override
  Future<void> reconcileTender(String workspaceId, {required String requestId, required String tenderId}) async {
    if (_replayed.containsKey(requestId)) return;
    final (:rec, :at) = _tender(tenderId);
    if (!rec.tenders[at].needsReconciliation) throw _refused(DkCode.dkl11, 'this tender does not wait for a reconciliation');
    rec.tenders[at] = _with(rec.tenders[at], reconciliation: 'done');
    _replayed[requestId] = true;
  }

  @override
  Future<String> complete(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<String> tenderIds}) async {
    final sold = await finalize(
      workspaceId,
      requestId: requestId,
      receiptId: receiptId,
      expectedRevision: expectedRevision,
      tenders: [for (final id in tenderIds) TillTender(kind: 'card', amountMinor: 0, tenderId: id)],
    );
    return sold.number;
  }

  /// The Demo's book as a visitor finds it: two oat milks and a bag of beans sold for cash, and a bag of beans whose
  /// card answer was lost at the terminal, waiting for the terminal's journal to be read.
  /// Opens the book with one cash sale and one sale whose card answer was lost.
  void seed() {
    TillTotals totals(int gross) => TillTotals(netMinor: gross - _tax(gross), taxMinor: _tax(gross), grossMinor: gross, currency: currency);
    CounterBookLine line(String receipt, int no, String label, String quantity, String unit, int gross) =>
        CounterBookLine(id: '$receipt-line-$no', lineNo: no, label: label, quantity: quantity, unit: unit, grossMinor: gross, goods: true);
    final milk = DemoStockRegistry.catalogue['demo-item-milk']!.$2;
    final beans = DemoStockRegistry.catalogue['demo-item-beans']!.$2;
    const sold = 'demo-receipt-seed-1';
    final cash = _Rec(id: sold, kind: 'sale', lines: [line(sold, 1, 'Oat milk', '2', 'l', 2 * milk), line(sold, 2, _beansName, '1', 'kg', beans)], totals: totals(2 * milk + beans))
      ..state = 'finalized'
      ..number = _number()
      ..finalizedAt = DateTime.utc(2026, 11, 23, 9);
    cash.tenders.add(CounterBookTender(id: 'demo-tender-${++_tenderSeq}', part: 1, kind: 'cash', amountMinor: 2 * milk + beans, state: 'accepted'));
    _book[sold] = cash;
    const open = 'demo-receipt-seed-2';
    final waiting = _Rec(id: open, kind: 'sale', lines: [line(open, 1, _beansName, '1', 'kg', beans)], totals: totals(beans), revision: ++_revision);
    final card = CounterBookTender(
      id: 'demo-tender-${++_tenderSeq}',
      part: 1,
      kind: 'card',
      amountMinor: beans,
      state: 'unknown',
      providerKey: 'dk-demo-terminal-0001',
    );
    waiting.tenders.add(card);
    _offered[card.id] = waiting.revision;
    _book[open] = waiting;
    _drafts[open] = TillDraft(
      receiptId: open,
      revision: waiting.revision,
      totals: waiting.totals,
      lines: [TillPricedLine(label: _beansName, grossMinor: beans, quantity: '1')],
      issueReceipt: 'supported',
    );
  }
}
