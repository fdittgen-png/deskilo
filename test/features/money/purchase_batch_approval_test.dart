// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3615 — approving a selection decides each item on its own (the decision
// on #3615): A applies, B changed since it was shown, C is not the
// person's to approve; nothing claims the whole selection. An item whose
// decision did not answer is retried with the same request identity and
// never decided twice; one decided meanwhile counts as what it became.
import 'package:deskilo/features/money/application/purchase_batch_approval.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseApprovalDetail _detail(
  String id, {
  int gross = 1000,
  PurchaseState state = PurchaseState.pending,
  bool canApprove = true,
}) => PurchaseApprovalDetail(
  detail: PurchaseDetail(
    summary: PurchaseSummary(
      id: id,
      kind: PurchaseKind.bill,
      state: state,
      category: '',
      reference: 'R-$id',
      currency: 'EUR',
      grossCents: gross,
    ),
    revision: 3,
    lines: const [],
    sources: const [],
  ),
  canApprove: canApprove,
  canReject: canApprove,
);

ApprovalItem _shown(String id, {int gross = 1000}) =>
    (id: id, grossCents: gross, currency: 'EUR', reference: 'R-$id');

class _Reads implements PurchaseApprovalReads {
  final Map<String, PurchaseApprovalDetail> now = {};

  @override
  Future<PurchaseApprovalDetail> detail(String workspaceId, String id) async =>
      now[id] ?? (throw StateError('not readable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements PurchaseRepository {
  final List<(String id, int revision, String requestId)> sent = [];
  Exception? failOnce;

  @override
  Future<PurchaseState> decideBill(
    String workspaceId,
    String purchaseId,
    int revision, {
    required bool approve,
    required String reason,
    required String requestId,
  }) async {
    sent.add((purchaseId, revision, requestId));
    final failure = failOnce;
    if (failure != null) {
      failOnce = null;
      throw failure;
    }
    return PurchaseState.approved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Reads reads;
  late _Repo repo;
  late PurchaseBatchApproval batch;
  var counter = 0;

  setUp(() {
    reads = _Reads();
    repo = _Repo();
    counter = 0;
    batch = PurchaseBatchApproval(
      workspaceId: 'ws-1',
      reads: reads,
      commands: PurchaseCommands(repo),
      newRequestId: () => 'req-${++counter}',
    );
  });

  test(
    'a mixed selection: each item its own outcome, only A is sent',
    () async {
      reads.now
        ..['a'] = _detail('a')
        ..['b'] = _detail('b', gross: 1500)
        ..['c'] = _detail('c', canApprove: false);
      final result = await batch.run([_shown('a'), _shown('b'), _shown('c')]);
      expect(result, {
        'a': ApprovalOutcome.applied,
        'b': ApprovalOutcome.changed,
        'c': ApprovalOutcome.refused,
      });
      expect(repo.sent, [
        ('a', 3, 'req-1'),
      ], reason: 'decided at the revision read');
    },
  );

  test('a decision that did not answer is unknown; the retry sends the same '
      'request, and an applied one is never sent again', () async {
    reads.now
      ..['a'] = _detail('a')
      ..['b'] = _detail('b');
    repo.failOnce = Exception('timeout');
    final items = [_shown('a'), _shown('b')];
    final first = await batch.run(items);
    expect(first['a'], ApprovalOutcome.unknown);
    expect(first['b'], ApprovalOutcome.applied);
    expect(batch.uncertain(items).map((i) => i.id), ['a']);

    await batch.run(batch.uncertain(items));
    expect(batch.outcomes['a'], ApprovalOutcome.applied);
    expect(repo.sent.where((s) => s.$1 == 'a').map((s) => s.$3).toSet(), {
      'req-1',
    }, reason: 'the same identity on the retry');
    expect(repo.sent.where((s) => s.$1 == 'b'), hasLength(1));
  });

  test('a retried item the first request did approve counts as applied, '
      'not as refused', () async {
    reads.now['a'] = _detail('a');
    repo.failOnce = Exception('timeout');
    await batch.run([_shown('a')]);
    // The first request did go through: the document is approved now.
    reads.now['a'] = _detail(
      'a',
      state: PurchaseState.approved,
      canApprove: false,
    );
    await batch.run([_shown('a')]);
    expect(batch.outcomes['a'], ApprovalOutcome.applied);
    expect(repo.sent, hasLength(1), reason: 'nothing sent a second time');
  });

  test('an item that cannot be read is unknown, never applied', () async {
    final result = await batch.run([_shown('gone')]);
    expect(result['gone'], ApprovalOutcome.unknown);
    expect(repo.sent, isEmpty);
  });
}
