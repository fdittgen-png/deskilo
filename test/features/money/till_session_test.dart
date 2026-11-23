// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's session against a scripted server: an unpriced basket cannot be paid, overlapping acts are
// served one after the other, a sale or a pricing whose answer was lost is retried under the request id it already
// had, and a receipt the server says moved is priced again once.
import 'dart:async';

import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class _Call {
  _Call(this.requestId, this.receiptId, this.revision, this.lineCount);

  final String requestId;
  final String? receiptId;
  final int? revision;
  final int lineCount;
}

/// A server that answers as a script says: [failNextDraft]/[failNextFinalize] raise the error AFTER recording the call
/// (the answer was lost on the way back), and the same request id is answered from what it already did.
class _Port implements TillPort {
  final drafts = <_Call>[];
  final finals = <_Call>[];
  Exception? failNextDraft;
  Exception? failNextFinalize;
  Completer<void>? holdDrafts;
  int shortBy = 0;
  int _revision = 0;
  int _sold = 0;
  final _answered = <String, TillDraft>{};
  final _made = <String, TillSold>{};

  @override
  Future<TillReadiness> readiness(String workspaceId) => throw UnimplementedError();

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision}) async {
    drafts.add(_Call(requestId, receiptId, expectedRevision, lines.length));
    await holdDrafts?.future;
    final seen = _answered[requestId];
    if (seen != null) return seen;
    if (failNextDraft case final e?) {
      failNextDraft = null;
      throw e;
    }
    if (receiptId != null && expectedRevision != _revision) throw const PostgrestException(message: 'moved', code: 'DKL10');
    final d = TillDraft(
      receiptId: receiptId ?? 'r-1',
      revision: ++_revision,
      totals: TillTotals(netMinor: 100 * lines.length, taxMinor: 0, grossMinor: 100 * lines.length, currency: 'EUR'),
      lines: [for (final l in lines.take(lines.length - shortBy)) TillPricedLine(label: l.name, grossMinor: 100, quantity: l.quantity)],
      issueReceipt: 'supported',
    );
    return _answered[requestId] = d;
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    finals.add(_Call(requestId, receiptId, expectedRevision, 0));
    final seen = _made[requestId];
    if (seen != null) return seen;
    if (_made.isNotEmpty) throw const PostgrestException(message: 'already issued', code: 'DKL04');
    final sold = TillSold(receiptId: receiptId, number: 'R-${++_sold}', totals: TillTotals(netMinor: 0, taxMinor: 0, grossMinor: tenders.single.amountMinor, currency: 'EUR'));
    _made[requestId] = sold;
    if (failNextFinalize case final e?) {
      failNextFinalize = null;
      throw e;
    }
    return sold;
  }
}

TillSession _session(_Port port) {
  var n = 0;
  return TillSession(port: port, workspaceId: 'ws', requestIds: () => 'req-${++n}');
}

Future<void> _ring(TillSession s, String id) => s.add(itemId: id, name: id, unit: 'piece');

void main() {
  test('a basket whose repricing fails has no draft: it cannot be paid, and the sale is not of the older basket', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    expect(s.state.value.draft, isNotNull);
    port.failNextDraft = const PostgrestException(message: 'no price', code: 'DKL02');
    await _ring(s, 'beans');
    expect(s.state.value.draft, isNull);
    expect(s.state.value.problem, isA<PostgrestException>());
    await s.payCash(10000);
    expect(port.finals, isEmpty);
    expect(s.state.value.sold, isNull);
  });

  test('a draft that does not describe the basket is not sold', () async {
    final port = _Port()..shortBy = 1;
    final s = _session(port);
    await _ring(s, 'milk');
    await _ring(s, 'beans');
    expect(s.state.value.draft, isNull);
    expect(s.state.value.problem, isA<TillDraftMismatch>());
    await s.payCash(10000);
    expect(port.finals, isEmpty);
  });

  test('two quick taps are served one after the other: the second continues the receipt the first made', () async {
    final port = _Port()..holdDrafts = Completer<void>();
    final s = _session(port);
    final first = _ring(s, 'milk');
    final second = _ring(s, 'beans');
    await Future<void>.delayed(Duration.zero);
    expect(port.drafts, hasLength(1), reason: 'the second waits for the first');
    port.holdDrafts!.complete();
    await Future.wait([first, second]);
    expect(port.drafts, hasLength(2));
    expect(port.drafts[1].receiptId, 'r-1');
    expect(port.drafts[1].revision, 1);
    expect(s.state.value.problem, isNull);
    expect(s.state.value.draft?.lines, hasLength(2));
    expect(s.state.value.busy, isFalse);
  });

  test('a tap during the sale does not drop the sale that was made', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    final pay = s.payCash(100);
    final tap = _ring(s, 'beans');
    await Future.wait([pay, tap]);
    expect(port.finals, hasLength(1));
    // The sale is shown; the tap that came after it did not reopen a basket that is sold.
    expect(s.state.value.sold?.number, 'R-1');
    expect(port.drafts, hasLength(1));
  });

  test('a sale whose answer was lost is retried under the same request id and is made once', () async {
    final port = _Port()..failNextFinalize = Exception('connection lost');
    final s = _session(port);
    await _ring(s, 'milk');
    await s.payCash(100);
    expect(s.state.value.sold, isNull);
    await s.payCash(100);
    expect(port.finals, hasLength(2));
    expect(port.finals[1].requestId, port.finals[0].requestId);
    expect(s.state.value.sold?.number, 'R-1');
    expect(s.state.value.problem, isNull);
  });

  test('a pricing whose answer was lost is retried under the same request id', () async {
    final port = _Port()..failNextDraft = Exception('connection lost');
    final s = _session(port);
    await _ring(s, 'milk');
    expect(s.state.value.draft, isNull);
    await s.retry();
    expect(port.drafts, hasLength(2));
    expect(port.drafts[1].requestId, port.drafts[0].requestId);
    expect(s.state.value.draft, isNotNull);
  });

  test('a receipt the server says moved is priced again once, as a receipt of its own', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    port._revision = 40;
    await _ring(s, 'beans');
    expect(port.drafts.map((c) => c.receiptId), [null, 'r-1', null]);
    expect(s.state.value.draft, isNotNull);
    expect(s.state.value.problem, isNull);
  });

  test('the next customer starts clean, with no request id kept from the last sale', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    await s.payCash(100);
    s.next();
    expect(s.state.value.lines, isEmpty);
    expect(s.state.value.sold, isNull);
  });
}
