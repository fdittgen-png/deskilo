// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — a payment credit booked on the wrong member is moved, never
// edited: the command sends only what can be right, the demo books what
// 0688 books, and the member page offers the move to the role that bills.
import 'package:deskilo/core/demo/data/money/demo_credit_moves.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/members/presentation/widgets/member_money_card.dart';
import 'package:deskilo/features/money/application/credit_move_commands.dart';
import 'package:deskilo/features/money/domain/credit_move.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/providers/credit_move_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../helpers/fake_money_repository.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/pump_app.dart';

LedgerEntry _entry({
  String id = 'c-1',
  LedgerKind kind = LedgerKind.credit,
  LedgerCategory category = LedgerCategory.payment,
}) => LedgerEntry(
  id: id,
  memberId: 'member-2',
  kind: kind,
  category: category,
  amountCents: 4200,
  description: 'Bank transfer',
  period: '2026-03',
  createdAt: DateTime.utc(2026, 3, 10),
);

class _Recording implements CreditMoveRepository {
  final calls = <String>[];
  Exception? refusal;

  @override
  Future<CreditMove> moveCredit({
    required String creditId,
    required String toMemberId,
    required String reason,
    required String requestId,
  }) async {
    calls.add('$creditId>$toMemberId:$reason');
    if (refusal != null) throw refusal!;
    return const CreditMove(id: 'mv', reversalId: 'rv', creditId: 'nc');
  }

  @override
  Future<Set<String>> fetchMovedCreditIds(String workspaceId) async => {};
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Bea paid; the reason is said; the move is sent.
Future<void> _chooseBeaAndSend(WidgetTester tester) async {
  await _tap(tester, find.byKey(const ValueKey('credit-move-member')));
  await _tap(tester, find.text('Bea').last);
  await tester.enterText(
    find.byKey(const ValueKey('credit-move-reason')),
    'paid by the colleague',
  );
  await _tap(tester, find.byKey(const ValueKey('credit-move-confirm')));
}

void main() {
  group('the command', () {
    test(
      'sends a payment credit to another member, the reason trimmed and cut',
      () async {
        final repo = _Recording();
        final move = await CreditMoveCommands(repo).move(
          _entry(),
          toMemberId: 'member-3',
          reason: '  ${'x' * 310}  ',
          requestId: 'r-1',
        );
        expect(move?.creditId, 'nc');
        expect(
          repo.calls.single,
          'c-1>member-3:${'x' * creditMoveReasonWidth}',
        );
      },
    );

    test(
      'sends nothing for a charge, a refund, the same member or no reason',
      () async {
        final repo = _Recording();
        final commands = CreditMoveCommands(repo);
        for (final (entry, to, why) in [
          (_entry(kind: LedgerKind.charge), 'member-3', 'paid'),
          (_entry(category: LedgerCategory.refund), 'member-3', 'paid'),
          (_entry(), 'member-2', 'paid'),
          (_entry(), 'member-3', '   '),
        ]) {
          expect(
            await commands.move(
              entry,
              toMemberId: to,
              reason: why,
              requestId: 'r',
            ),
            isNull,
          );
        }
        expect(repo.calls, isEmpty);
      },
    );
  });

  group('the demo', () {
    test('keeps the original, reverses it on the wrong member and credits the right one', () async {
      final money = FakeMoneyRepository()..ledger.add(_entry());
      final moves = DemoCreditMoves(money);
      final move = await moves.moveCredit(
        creditId: 'c-1',
        toMemberId: 'member-3',
        reason: 'paid by the colleague',
        requestId: 'r-1',
      );
      final byId = {for (final e in money.ledger) e.id: e};
      expect(byId['c-1']!.memberId, 'member-2');
      final reversal = byId[move.reversalId]!;
      expect(
        (
          reversal.kind,
          reversal.category,
          reversal.memberId,
          reversal.period,
          reversal.amountCents,
        ),
        (
          LedgerKind.charge,
          LedgerCategory.adjustment,
          'member-2',
          '2026-03',
          4200,
        ),
      );
      final credit = byId[move.creditId]!;
      expect(
        (credit.kind, credit.category, credit.memberId, credit.period),
        (LedgerKind.credit, LedgerCategory.payment, 'member-3', '2026-03'),
      );

      // A retry answers the same move; a second move of the credit is refused.
      final again = await moves.moveCredit(
        creditId: 'c-1',
        toMemberId: 'member-3',
        reason: 'paid by the colleague',
        requestId: 'r-1',
      );
      expect((again.id, again.replayed), (move.id, true));
      expect(money.ledger, hasLength(3));
      await expectLater(
        moves.moveCredit(
          creditId: 'c-1',
          toMemberId: 'member-4',
          reason: 'again',
          requestId: 'r-2',
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            'this credit was already moved',
          ),
        ),
      );
    });

    test('refuses a charge and the same member, in words', () async {
      final money = FakeMoneyRepository()
        ..ledger.addAll([
          _entry(),
          _entry(id: 'ch-1', kind: LedgerKind.charge),
        ]);
      final moves = DemoCreditMoves(money);
      await expectLater(
        moves.moveCredit(
          creditId: 'ch-1',
          toMemberId: 'member-3',
          reason: 'x',
          requestId: 'r-1',
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            'only a payment credit is moved',
          ),
        ),
      );
      await expectLater(
        moves.moveCredit(
          creditId: 'c-1',
          toMemberId: 'member-2',
          reason: 'x',
          requestId: 'r-2',
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '22023'),
        ),
      );
    });
  });

  test(
    'the Demo moves a payment of its own ledger, through the real command',
    () async {
      final fixture = DemoFixture.build();
      final container = ProviderContainer(overrides: demoOverrides(fixture));
      addTearDown(container.dispose);
      container.listen(currentWorkspaceProvider, (_, _) {});
      await container.read(currentWorkspaceProvider.future);
      expect(
        container.read(creditMoveRepositoryProvider),
        isA<DemoCreditMoves>(),
      );
      final ledger = fixture.money.ledger;
      final credit = ledger.firstWhere(CreditMoveCommands.movable);
      final other = ledger
          .firstWhere((e) => e.memberId != credit.memberId)
          .memberId;
      final move = await container
          .read(creditMoveCommandsProvider)
          .move(
            credit,
            toMemberId: other,
            reason: 'paid by the colleague',
            requestId: 'r-demo',
          );
      expect(ledger.firstWhere((e) => e.id == move!.creditId).memberId, other);
      expect(
        ledger.firstWhere((e) => e.id == move!.reversalId).memberId,
        credit.memberId,
      );
    },
  );

  group('the member page', () {
    Future<_Recording> pump(
      WidgetTester tester, {
      bool bankImport = true,
      bool isSelf = false,
    }) async {
      final repo = _Recording();
      final money = FakeMoneyRepository()..ledger.add(_entry());
      final workspace =
          FakeWorkspaceRepository.withWorkspace(
              featureFlags: {if (bankImport) 'bankImport': true},
            )
            ..memberNames = {
              'member-1': 'Flo',
              'member-2': 'Ana',
              'member-3': 'Bea',
            }
            ..otherMembers.add(
              const Member(
                id: 'member-3',
                workspaceId: 'ws-1',
                userId: 'user-3',
                isAdmin: false,
                isOwner: false,
                status: MemberStatus.active,
                subscriptionPct: 50,
              ),
            );
      await pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: MemberMoneyCard(memberId: 'member-2', isSelf: isSelf),
          ),
        ),
        overrides: [
          ...standardTestOverrides(
            money: money,
            workspace: workspace,
            creditMoves: repo,
          ),
        ],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('the role that bills moves a payment to the member who paid', (
      tester,
    ) async {
      final repo = await pump(tester);
      await _tap(tester, find.byKey(const ValueKey('member-payment-move-c-1')));

      // Nothing chosen, nothing said: the dialog names both, sends nothing.
      await _tap(tester, find.byKey(const ValueKey('credit-move-confirm')));
      expect(repo.calls, isEmpty);
      expect(find.text('Choose the member who paid.'), findsOneWidget);
      expect(find.text('Say why the payment moves.'), findsOneWidget);

      await _chooseBeaAndSend(tester);
      expect(repo.calls.single, 'c-1>member-3:paid by the colleague');
      expect(find.text('The payment was moved.'), findsOneWidget);
    });

    testWidgets('a refusal says the payment was not moved', (tester) async {
      final repo = await pump(tester);
      repo.refusal = const PostgrestException(
        message: 'this credit pays an invoice: undo the match first',
        code: '22023',
      );
      await _tap(tester, find.byKey(const ValueKey('member-payment-move-c-1')));
      await _chooseBeaAndSend(tester);
      expect(repo.calls, hasLength(1));
      expect(find.text('The payment was moved.'), findsNothing);
    });

    testWidgets('no move without the bank import, nor on your own page', (
      tester,
    ) async {
      await pump(tester, bankImport: false);
      expect(
        find.byKey(const ValueKey('member-payment-move-c-1')),
        findsNothing,
      );
      await pump(tester, isSelf: true);
      expect(
        find.byKey(const ValueKey('member-payment-move-c-1')),
        findsNothing,
      );
    });
  });
}
