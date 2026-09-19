// SPDX-License-Identifier: 0BSD
//
// #1532 — when two writes cannot be one, the irreversible one goes last.
//
// The wizard distributed the expense and then saved the rule. A failure
// on the rule left the expense ALREADY DISTRIBUTED, with the sheet open
// on the same amounts and a message saying it had gone wrong: press Book
// again and every member is charged twice.
//
// These exercise the command rather than the screen, which is the point
// of extracting it (#1449). The wizard's own widget test cannot reach
// this: `_book` returns early when `currentWorkspaceProvider` is null,
// as it is in that harness, so its Book button writes nothing at all.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/book_repartition.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuleRefuses extends FakeMoneyRepository {
  @override
  Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule) {
    throw StateError('the rule could not be saved');
  }
}

class _DistributionRefuses extends FakeMoneyRepository {
  @override
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) {
    throw StateError('the distribution was refused');
  }
}

const _shares = [
  RepartitionShare(
      memberId: 'm-1', memberName: 'Ana', weight: 1, amountCents: 500),
  RepartitionShare(
      memberId: 'm-2', memberName: 'Bo', weight: 1, amountCents: 500),
];

const _rule = RepartitionRule(method: RepartitionMethod.equal);

Future<BookRepartitionOutcome> _book(
  FakeMoneyRepository repo, {
  bool remember = true,
}) =>
    bookRepartition(
      repo,
      workspaceId: 'ws-1',
      title: 'Internet',
      amountCents: 1000,
      period: '2026-09',
      rule: _rule,
      shares: _shares,
      remember: remember,
    );

void main() {
  test('a refused rule distributes nothing at all', () async {
    final repo = _RuleRefuses();

    final outcome = await _book(repo);

    expect(outcome, isA<RepartitionNotBooked>());
    expect(repo.repartitions, isEmpty,
        reason: 'the rule is the cheap write and it goes first, so when '
            'it fails nobody has been charged and pressing Book again '
            'books the expense exactly once instead of twice');
  });

  test('a refused distribution leaves the rule, which is harmless',
      () async {
    final repo = _DistributionRefuses();

    await expectLater(_book(repo), throwsA(isA<StateError>()));

    expect(repo.repartitionRule, _rule,
        reason: 'the leftover of this order is a remembered preference — '
            'which is what the owner ticked the box for — and no money '
            'has moved');
    expect(repo.repartitions, isEmpty);
  });

  test('the happy path saves the rule and distributes once', () async {
    final repo = FakeMoneyRepository();

    final outcome = await _book(repo);

    expect(outcome, isA<RepartitionBooked>());
    expect((outcome as RepartitionBooked).ruleRemembered, isTrue);
    expect(repo.repartitionRule, _rule);
    expect(repo.repartitions, hasLength(1));
  });

  test('without "remember" the rule is left alone', () async {
    // The rule write must not happen at all — not merely be overwritten
    // with the same value — or an owner who declined to remember would
    // silently have their stored rule replaced.
    final repo = _RuleRefuses();

    final outcome = await _book(repo, remember: false);

    expect(outcome, isA<RepartitionBooked>(),
        reason: 'the refusing rule writer is never called');
    expect((outcome as RepartitionBooked).ruleRemembered, isFalse);
    expect(repo.repartitions, hasLength(1));
  });
}
