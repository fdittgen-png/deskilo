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
import 'package:deskilo/features/money/domain/counter_receipt_document.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../codes/dk_code.dart';
import 'demo_stock_registry.dart';
import 'demo_till_drawer.dart';

/// The server's refusal: its SQLSTATE as the code, its words as the message.
PostgrestException _refused(String code, String message, {String? reason}) =>
    PostgrestException(message: message, code: code, details: reason == null ? null : '{"reason":"$reason"}');

/// #4436 -- the Demo's traced item at the counter: the oat milk is tracked by lot, and a sale takes it from the lot on
/// hand that expires first and is not expired yet (MILK-09 is past its date, so MILK-12; the expiry report's lots). The
/// gift basket is tracked piece by piece: its pieces are of lot BASKET-1, and a sale names each piece scanned by its tag.
const _tracedLots = <String, String>{'demo-item-milk': 'MILK-12', 'demo-item-basket': 'BASKET-1'};

/// The prices of Demo items the stock registry does not carry (the T-shirt the variants are edited on), in cents.
const _unstocked = <String, int>{'demo-item-shirt': 1900, 'demo-item-basket': 3900, 'demo-item-apples': 1800};

/// One registry row of the declared case `none`, as `counter_country_operations` carries it (0893).
typedef _Row = ({String specification, String version, String from, bool supported, String note});

const _supportedOps = ['issue_receipt', 'correct_receipt', 'reconcile_tender'];

const _evidence = {
  'issue_receipt': 'pgTAP 520 (finalize, number once, frozen original) and 521 (totals in 0, 2 and 3 decimals)',
  'correct_receipt': 'pgTAP 522 (a correction is a new receipt citing the original)',
  'reconcile_tender': 'pgTAP 523 (tender states and reconciliation)',
};

/// The country of an installed add-on is the one in its capability id (`invoice_mentions.IT`), so the rows are keyed by
/// the add-on that states the country's law, not by a country literal of this file.
Map<String, _Row> _byCountry(Map<InvoiceMentionsContribution, _Row> rows) => {
  for (final e in rows.entries) e.key.descriptor.capabilityId.split('.').last: e.value,
};

final _registry = _byCountry({
  const FrInvoiceMentions(): (
    specification: 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)',
    version: '2026-11',
    from: '2013-01-01',
    supported: true,
    note: '',
  ),
  const DeInvoiceMentions(): (
    specification: 'Umsatzsteuer-Durchführungsverordnung, § 33 (Rechnungen über Kleinbeträge)',
    version: '2026-11',
    from: '2017-01-01',
    supported: true,
    note: '',
  ),
  const EsInvoiceMentions(): (
    specification: 'Real Decreto 1619/2012, art. 4 y 7 (factura simplificada)',
    version: '2026-11',
    from: '2013-01-01',
    supported: true,
    note: '',
  ),
  const ItInvoiceMentions(): (
    specification: 'Decreto legislativo 127/2015, art. 2 (memorizzazione e trasmissione telematica dei corrispettivi)',
    version: 'D.Lgs. 127/2015',
    from: '2020-01-01',
    supported: false,
    note:
        "The retail sale in Italy is recorded through the telematic transmission of the day's takings; a receipt of this kind is not that, and no adapter transmits it.",
  ),
});


/// #4436 -- one traced line a sale froze: its receipt, when, and the track IDs it took, as `counter_line_tracks` keeps them.
typedef DemoSoldLine = ({String lineId, String receiptId, String number, DateTime at, List<TillTrack> tracks});

class DemoTill implements TillPort, TillOfflinePort {
  DemoTill({required this.country, required this.currency, required this.vatPercent, this.ready = true, this.minorDigits = 2, this.drawer, this.clock});

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
  final Map<String, TillDraft> _drafts = {};
  final Map<String, List<Map<String, Object?>>> _frozenLines = {};
  final Map<String, TillSold> _done = {};
  final Map<String, TillDraft> _answered = {};
  final Map<String, Map<String, Object?>> _frozen = {};

  _Row? get _row => _registry[country];

  bool get _supported => ready && (_row?.supported ?? false);

  /// The basket each open draft priced: what its sale takes.
  final Map<String, List<TillLine>> _lines = {};

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

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async {
    _line();
    final replay = _answered[requestId];
    if (replay != null) return replay;
    if (tillId != null && drawer != null && !drawer!.hasOpenSession(tillId)) {
      throw _refused(DkCode.dkl12, 'open the till first', reason: 'till_open_first');
    }
    final id = receiptId ?? 'demo-receipt-${_drafts.length + _sales + 1}';
    final known = _drafts[id];
    if (receiptId != null && (known == null || known.revision != expectedRevision)) {
      throw _refused(DkCode.dkl10, 'this receipt changed meanwhile');
    }
    var gross = 0;
    var tax = 0;
    final priced = <TillPricedLine>[];
    final frozen = <Map<String, Object?>>[];
    for (final l in lines) {
      final unit = DemoStockRegistry.catalogue[l.itemId]?.$2 ?? _unstocked[l.itemId];
      if (unit == null) throw _refused(DkCode.dkl02, 'line_${priced.length + 1}_unit_price');
      final amount = _times(unit, l.quantity);
      final lineTax = amount - (amount * 100 / (100 + vatPercent)).round();
      gross += amount;
      tax += lineTax;
      priced.add(TillPricedLine(label: l.name, grossMinor: amount, quantity: l.quantity));
      frozen.add(_frozenLine(l, amount, lineTax));
    }
    final draft = TillDraft(
      receiptId: id,
      revision: ++_revision,
      totals: TillTotals(netMinor: gross - tax, taxMinor: tax, grossMinor: gross, currency: currency),
      lines: priced,
      issueReceipt: _supported ? 'supported' : 'unavailable',
    );
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
  int _times(int unit, String quantity) {
    final parts = quantity.split('.');
    final fraction = parts.length == 2 ? parts[1].padRight(6, '0') : '000000';
    final millionths = int.parse(parts[0]) * 1000000 + int.parse(fraction);
    return (unit * millionths / 1000000).round();
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    _line();
    final again = _done[requestId];
    if (again != null) return again;
    final draft = _drafts[receiptId];
    if (!_supported) throw _refused(DkCode.dkl01, 'the country operation is not supported');
    if (draft == null) throw _refused(DkCode.dkl04, 'this receipt is not an open draft');
    if (draft.revision != expectedRevision) throw _refused(DkCode.dkl10, 'this receipt changed meanwhile');
    if (tenders.fold<int>(0, (a, t) => a + t.amountMinor) != draft.totals.grossMinor) throw _refused(DkCode.dkl06, 'tender_sum');
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
    final sold = TillSold(receiptId: receiptId, number: 'R-${(++_sales).toString().padLeft(5, '0')}', totals: draft.totals, lines: traced);
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
}
