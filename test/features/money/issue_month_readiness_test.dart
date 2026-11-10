// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- what the review list knows before anything is issued: a
// customer's own gaps on their row, the business's gaps once, a failed read
// as "unknown" (never blocked), and a bounded number of reads at once.
import 'package:deskilo/features/money/application/issue_month_readiness.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Queries implements InvoiceQueries {
  final Map<String, List<String>> missing = {};
  final Set<String> failing = {};
  int running = 0;
  int peak = 0;

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async {
    running++;
    if (running > peak) peak = running;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    running--;
    if (failing.contains(memberId)) throw StateError('offline');
    return missing[memberId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MonthReadiness> _read(_Queries q, List<String> ids) async {
  var state = const MonthReadiness({});
  await readMonthReadiness(
    queries: q,
    workspaceId: 'ws-1',
    period: '2026-10',
    memberIds: ids,
    onEach: (id, r) => state = state.with_(id, r),
  );
  return state;
}

void main() {
  test('a customer\'s own gap is on their row only', () async {
    final q = _Queries()..missing['ben'] = ['buyer_address'];
    final r = await _read(q, ['anna', 'ben']);
    expect(r.lines['anna'], isA<ReadinessReady>());
    expect(r.customerMissing('ben'), ['buyer_address']);
    expect(r.needsFix('ben'), isTrue);
    expect(r.needsFix('anna'), isFalse);
    expect(r.needsFixCount, 1);
    expect(r.businessMissing, isEmpty);
  });

  test('a business gap shared by everyone is said once, not per row', () async {
    final q = _Queries()
      ..missing['anna'] = ['seller_address']
      ..missing['ben'] = ['seller_address', 'buyer_name'];
    final r = await _read(q, ['anna', 'ben']);
    expect(r.businessMissing, ['seller_address']);
    expect(r.needsFix('anna'), isFalse, reason: 'covered by the one notice');
    expect(r.customerMissing('ben'), ['buyer_name']);
  });

  test('a business gap one customer does not have is not "shared"', () async {
    final q = _Queries()..missing['anna'] = ['seller_address'];
    final r = await _read(q, ['anna', 'ben']);
    expect(r.businessMissing, isEmpty);
    expect(r.customerMissing('anna'), ['seller_address']);
  });

  test(
    'a failed read is unknown: the row stays free, nothing is claimed',
    () async {
      final q = _Queries()..failing.add('ben');
      final r = await _read(q, ['anna', 'ben']);
      expect(r.lines['ben'], isA<ReadinessUnknown>());
      expect(r.needsFix('ben'), isFalse);
      expect(r.businessMissing, isEmpty);
    },
  );

  test('reads run a bounded number at a time', () async {
    final q = _Queries();
    await _read(q, [for (var i = 0; i < 12; i++) 'm$i']);
    expect(q.peak, lessThanOrEqualTo(monthReadinessConcurrency));
    expect(q.peak, greaterThan(1), reason: 'and more than one at once');
  });
}
