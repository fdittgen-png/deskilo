// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the Demo's till: the server's rules of the counter receipt, in memory. A draft prices each line from the
// reference business's shop catalogue (a price on the GROSS basis, half away from zero once per line, the totals the
// sums of the lines); a sale numbers the receipt from a counter of its own and answers the same sale again under the
// same request id. A country that is not ready is a Demo choice: [ready] false answers the server's `unavailable`.
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'demo_stock_registry.dart';

/// The server's refusal: its SQLSTATE as the code, its words as the message.
PostgrestException _refused(String code, String message) => PostgrestException(message: message, code: code);

class DemoTill implements TillPort {
  DemoTill({required this.currency, required this.vatPercent, this.ready = true, this.minorDigits = 2});

  final String currency;
  final int vatPercent;
  final bool ready;
  final int minorDigits;

  int _revision = 0;
  int _sales = 0;
  final Map<String, TillDraft> _drafts = {};
  final Map<String, TillSold> _done = {};

  @override
  Future<TillReadiness> readiness(String workspaceId) async => TillReadiness(
    country: 'FR',
    fiscalObligation: 'none',
    ready: ready,
    operations: [
      for (final op in const ['issue_receipt', 'correct_receipt', 'reconcile_tender'])
        TillOperation(operation: op, outcome: ready ? 'supported' : 'unavailable', reason: ready ? '' : 'unavailable', note: ''),
    ],
  );

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision}) async {
    final id = receiptId ?? 'demo-receipt-${_drafts.length + _sales + 1}';
    final known = _drafts[id];
    if (receiptId != null && (known == null || known.revision != expectedRevision)) {
      throw _refused('DKL10', 'this receipt changed meanwhile');
    }
    var gross = 0;
    var tax = 0;
    final priced = <TillPricedLine>[];
    for (final l in lines) {
      final unit = DemoStockRegistry.catalogue[l.itemId]?.$2;
      if (unit == null) throw _refused('DKL02', 'line_${priced.length + 1}_unit_price');
      final amount = _times(unit, l.quantity);
      final lineTax = amount - (amount * 100 / (100 + vatPercent)).round();
      gross += amount;
      tax += lineTax;
      priced.add(TillPricedLine(label: l.name, grossMinor: amount, quantity: l.quantity));
    }
    final draft = TillDraft(
      receiptId: id,
      revision: ++_revision,
      totals: TillTotals(netMinor: gross - tax, taxMinor: tax, grossMinor: gross, currency: currency),
      lines: priced,
      issueReceipt: ready ? 'supported' : 'unavailable',
    );
    _drafts[id] = draft;
    return draft;
  }

  /// [unit] (minor units of one inventory unit) times [quantity] (an exact decimal text), half away from zero.
  int _times(int unit, String quantity) {
    final parts = quantity.split('.');
    final fraction = parts.length == 2 ? parts[1].padRight(6, '0') : '000000';
    final millionths = int.parse(parts[0]) * 1000000 + int.parse(fraction);
    return (unit * millionths / 1000000).round();
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    final again = _done[requestId];
    if (again != null) return again;
    final draft = _drafts[receiptId];
    if (!ready) throw _refused('DKL01', 'the country operation is not supported');
    if (draft == null) throw _refused('DKL04', 'this receipt is not an open draft');
    if (draft.revision != expectedRevision) throw _refused('DKL10', 'this receipt changed meanwhile');
    if (tenders.fold<int>(0, (a, t) => a + t.amountMinor) != draft.totals.grossMinor) throw _refused('DKL06', 'tender_sum');
    final sold = TillSold(receiptId: receiptId, number: 'R-${(++_sales).toString().padLeft(5, '0')}', totals: draft.totals);
    _drafts.remove(receiptId);
    return _done[requestId] = sold;
  }
}
