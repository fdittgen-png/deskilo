// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's session against a scripted server: an unpriced basket cannot be paid, overlapping acts are
// served one after the other, a sale or a pricing whose answer was lost is retried under the request id it already
// had, and a receipt the server says moved is priced again once.
import 'dart:async';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/features/money/domain/counter_receipt_document.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Exception? refuseNextFinalize;
  Completer<void>? holdFinalize;
  Completer<void>? holdDrafts;
  int shortBy = 0;
  String? lastTillId;
  String? quantityAs;
  int _revision = 0;
  int _sold = 0;
  final _answered = <String, TillDraft>{};
  final _made = <String, TillSold>{};

  @override
  Future<TillCardAsked> requestCard(String workspaceId, {required String requestId, required String receiptId, required int amountMinor}) =>
      throw UnimplementedError('this fake takes no card');

  @override
  Future<({String state, String? reconciliation})> resolveCard(String workspaceId, {required String requestId, required String tenderId, required String outcome, String providerRef = ''}) =>
      throw UnimplementedError('this fake takes no card');

  @override
  Future<TillReadiness> readiness(String workspaceId) => throw UnimplementedError();

  @override
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId) => throw UnimplementedError();

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async {
    lastTillId = tillId;
    drafts.add(_Call(requestId, receiptId, expectedRevision, lines.length));
    await holdDrafts?.future;
    final seen = _answered[requestId];
    if (seen != null) return seen;
    if (failNextDraft case final e?) {
      failNextDraft = null;
      throw e;
    }
    if (receiptId != null && expectedRevision != _revision) throw const PostgrestException(message: 'moved', code: DkCode.dkl10);
    final d = TillDraft(
      receiptId: receiptId ?? 'r-1',
      revision: ++_revision,
      totals: TillTotals(netMinor: 100 * lines.length, taxMinor: 0, grossMinor: 100 * lines.length, currency: 'EUR'),
      lines: [for (final l in lines.take(lines.length - shortBy)) TillPricedLine(label: l.name, grossMinor: 100, quantity: quantityAs ?? l.quantity)],
      issueReceipt: 'supported',
    );
    return _answered[requestId] = d;
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) async {
    finals.add(_Call(requestId, receiptId, expectedRevision, 0));
    await holdFinalize?.future;
    if (refuseNextFinalize case final e?) {
      refuseNextFinalize = null;
      throw e;
    }
    final seen = _made[requestId];
    if (seen != null) return seen;
    if (_made.isNotEmpty) throw const PostgrestException(message: 'already issued', code: DkCode.dkl04);
    final sold = TillSold(receiptId: receiptId, number: 'R-${++_sold}', totals: TillTotals(netMinor: 0, taxMinor: 0, grossMinor: tenders.single.amountMinor, currency: 'EUR'));
    _made[requestId] = sold;
    if (failNextFinalize case final e?) {
      failNextFinalize = null;
      throw e;
    }
    return sold;
  }
}

TillSession _session(TillPort port, {Duration timeout = const Duration(seconds: 20)}) {
  var n = 0;
  return TillSession(port: port, workspaceId: 'ws', requestIds: () => 'req-${++n}', callTimeout: timeout);
}

Future<void> _ring(TillSession s, String id) => s.add(itemId: id, name: id, unit: 'piece');

void main() {
  test('the till the sale is made on goes with every pricing, and a business without sessions sends none', () async {
    final port = _Port();
    final s = _session(port);
    await s.add(itemId: 'a', name: 'A', unit: 'pc');
    expect(port.lastTillId, isNull);
    s.tillId = 'till-1';
    await s.add(itemId: 'b', name: 'B', unit: 'pc');
    expect(port.lastTillId, 'till-1');
  });

  test('a basket whose repricing fails has no draft: it cannot be paid, and the sale is not of the older basket', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    expect(s.state.value.draft, isNotNull);
    port.failNextDraft = const PostgrestException(message: 'no price', code: DkCode.dkl02);
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

  test('a sale whose answer was lost waits to be confirmed: nothing else is done to the basket, and confirming makes it once', () async {
    final port = _Port()..failNextFinalize = Exception('connection lost');
    final s = _session(port);
    await _ring(s, 'milk');
    await s.payCash(100);
    expect(s.state.value.sold, isNull);
    expect(s.state.value.unconfirmed, isTrue);
    // A tap, a quantity and a removal change nothing while the sale may have been made.
    await _ring(s, 'beans');
    expect(await s.setQuantity(0, '3'), isTrue);
    await s.remove(0);
    expect(s.state.value.lines, hasLength(1));
    expect(port.drafts, hasLength(1));
    s.next();
    expect(s.state.value.unconfirmed, isTrue, reason: 'the next customer waits for the sale');
    await s.confirmSale();
    expect(port.finals, hasLength(2));
    expect(port.finals[1].requestId, port.finals[0].requestId);
    expect(s.state.value.sold?.number, 'R-1');
    expect(s.state.value.unconfirmed, isFalse);
    expect(s.state.value.problem, isNull);
  });

  test('the session of a business is kept: opened again while a sale waits, it is the same one, and confirming sells once', () async {
    final port = _Port()..failNextFinalize = Exception('connection lost');
    final container = ProviderContainer(overrides: [tillPortProvider.overrideWithValue(port)]);
    addTearDown(container.dispose);
    final first = container.read(tillSessionProvider('ws'));
    await _ring(first, 'milk');
    await first.payCash(100);
    first.leave();
    final again = container.read(tillSessionProvider('ws'));
    expect(identical(again, first), isTrue);
    expect(again.state.value.unconfirmed, isTrue);
    expect(identical(container.read(tillSessionProvider('other')), first), isFalse);
    await again.confirmSale();
    expect(port.finals, hasLength(2));
    expect(again.state.value.sold?.number, 'R-1');
  });

  test('a sale the server answered with a refusal of its own is definite: nothing waits to be confirmed', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    port.refuseNextFinalize = const PostgrestException(message: 'bad', code: PgCode.invalidParameterValue);
    await s.payCash(100);
    expect(s.state.value.unconfirmed, isFalse);
    expect(s.state.value.problem, isA<PostgrestException>());
    expect(s.state.value.sold, isNull);
  });

  test('paying while a sale waits confirms it as it was sent, with the cash typed before', () async {
    final port = _Port()..failNextFinalize = Exception('connection lost');
    final s = _session(port);
    await _ring(s, 'milk');
    await s.payCash(500);
    expect(s.state.value.unconfirmed, isTrue);
    await s.payCash(100);
    expect(port.finals, hasLength(2));
    expect(port.finals[1].requestId, port.finals[0].requestId);
    expect(s.state.value.sold?.number, 'R-1');
    expect(s.state.value.change, 400);
  });

  test('leaving the till keeps a sale that waits and drops a basket nobody pays', () async {
    final port = _Port()..failNextFinalize = Exception('connection lost');
    final s = _session(port);
    await _ring(s, 'milk');
    s.leave();
    expect(s.state.value.lines, isEmpty);
    await _ring(s, 'milk');
    await s.payCash(100);
    s.leave();
    expect(s.state.value.unconfirmed, isTrue);
    expect(s.state.value.lines, hasLength(1));
    await s.confirmSale();
    expect(s.state.value.sold?.number, 'R-1');
  });

  test('a sale refused as moved or closed is priced again: no dead end', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    port.refuseNextFinalize = const PostgrestException(message: 'moved', code: DkCode.dkl10);
    await s.payCash(100);
    expect(s.state.value.unconfirmed, isFalse);
    expect(s.state.value.sold, isNull);
    expect(s.state.value.draft, isNotNull, reason: 'priced again as a receipt of its own');
    expect(port.drafts.last.receiptId, isNull);
    await s.payCash(100);
    expect(s.state.value.sold?.number, 'R-1');
  });

  test('a moved receipt priced again as a new one, whose answer is lost, is retried under the same request id', () async {
    final inner = _Port();
    var lost = false;
    final port = _OnceLost(inner, () => lost, () => lost = true);
    final s = _session(port);
    await _ring(s, 'milk');
    inner._revision = 40;
    await _ring(s, 'beans');
    expect(s.state.value.draft, isNull);
    await s.retry();
    final ids = inner.drafts.map((c) => c.requestId).toList();
    expect(ids.where((i) => i == ids.last), hasLength(2), reason: 'the retry reuses the request id of the lost re-pricing');
    expect(s.state.value.draft, isNotNull);
  });

  test('a call that hangs is a problem to retry, not a till that waits for ever', () async {
    final port = _Port()..holdDrafts = Completer<void>();
    final s = _session(port, timeout: const Duration(milliseconds: 50));
    await _ring(s, 'milk');
    expect(s.state.value.busy, isFalse);
    expect(s.state.value.problem, isA<TimeoutException>());
    port.holdDrafts = null;
    await s.retry();
    expect(s.state.value.draft, isNotNull);
  });

  test('a sale that hangs waits to be confirmed', () async {
    final port = _Port()..holdFinalize = Completer<void>();
    final s = _session(port, timeout: const Duration(milliseconds: 50));
    await _ring(s, 'milk');
    await s.payCash(100);
    expect(s.state.value.unconfirmed, isTrue);
    port.holdFinalize = null;
    await s.confirmSale();
    expect(s.state.value.sold?.number, 'R-1');
  });

  test('a sale that completes after the till was closed does not throw', () async {
    final port = _Port();
    final s = _session(port);
    await _ring(s, 'milk');
    port.holdFinalize = Completer<void>();
    final pay = s.payCash(100);
    await Future<void>.delayed(Duration.zero);
    s.dispose();
    port.holdFinalize!.complete();
    await pay;
    expect(port.finals, hasLength(1));
  });

  test('a draft that prices another quantity than the basket says is not sold', () async {
    final port = _Port()..quantityAs = '9';
    final s = _session(port);
    await _ring(s, 'milk');
    expect(s.state.value.draft, isNull);
    expect(s.state.value.problem, isA<TillDraftMismatch>());
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

/// A port whose first re-pricing after the receipt moved is lost on the way back: the call is made, nothing answers.
class _OnceLost implements TillPort {
  _OnceLost(this._inner, this._lost, this._markLost);

  final _Port _inner;
  final bool Function() _lost;
  final void Function() _markLost;

  List<_Call> get drafts => _inner.drafts;

  @override
  Future<TillCardAsked> requestCard(String workspaceId, {required String requestId, required String receiptId, required int amountMinor}) =>
      _inner.requestCard(workspaceId, requestId: requestId, receiptId: receiptId, amountMinor: amountMinor);

  @override
  Future<({String state, String? reconciliation})> resolveCard(String workspaceId, {required String requestId, required String tenderId, required String outcome, String providerRef = ''}) =>
      _inner.resolveCard(workspaceId, requestId: requestId, tenderId: tenderId, outcome: outcome, providerRef: providerRef);

  @override
  Future<TillReadiness> readiness(String workspaceId) => _inner.readiness(workspaceId);

  @override
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId) => _inner.receipt(workspaceId, receiptId);

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async {
    if (receiptId == null && _inner.drafts.isNotEmpty && !_lost()) {
      _markLost();
      _inner.drafts.add(_Call(requestId, null, null, lines.length));
      throw Exception('connection lost');
    }
    return _inner.draft(workspaceId, requestId: requestId, lines: lines, receiptId: receiptId, expectedRevision: expectedRevision);
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) =>
      _inner.finalize(workspaceId, requestId: requestId, receiptId: receiptId, expectedRevision: expectedRevision, tenders: tenders);
}
