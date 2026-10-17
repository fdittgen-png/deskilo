// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Recording cash against a member's claim: the decode of payments and their
// reversals, what the command refuses before sending, and the dialogs -- a
// failed save keeps the form and retries under the same request id, a
// success reads the real remaining amount, who sees the buttons.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

Map<String, Object?> _claim(
  String id, {
  int amount = 12000,
  int paid = 0,
  bool mine = false,
  Object? invoice,
  List<Map<String, Object?>> allocations = const [],
}) => {
  'id': id,
  'purchase_id': 'p-$id',
  'creditor_kind': 'member',
  'creditor_id': 'm1',
  'amount_cents': amount,
  'currency': 'EUR',
  'due_on': null,
  'state': 'open',
  'hold_reason': '',
  'revision': 1,
  'paid_cents': paid,
  'mine': mine,
  'allocations': allocations,
  'applied_cents': invoice == null ? 0 : amount - paid,
  'remaining_cents': invoice == null ? amount - paid : 0,
  'applied_invoice': invoice,
};

PayableRow _row(Map<String, Object?> claim) => PayableRow.fromJson({
  'obligation': claim,
  'purchase': {
    'kind': 'member_receipt',
    'state': 'approved',
    'category': 'cleaning',
    'original_reference': '',
    'received_on': '2026-10-17',
    'legacy': false,
  },
});

/// Refuses the first save, then behaves; remembers every request id.
class _Flaky extends FakePurchaseRepository {
  final requestIds = <String>[];
  var _failed = false;

  @override
  Future<PurchaseObligation> recordReimbursement(
    String workspaceId,
    ReimbursementCommand command,
  ) async {
    requestIds.add(command.requestId);
    if (!_failed) {
      _failed = true;
      throw StateError('network');
    }
    return super.recordReimbursement(workspaceId, command);
  }
}

class _Counting extends FakePurchaseRepository {
  int sent = 0;

  @override
  Future<PurchaseObligation> recordReimbursement(
    String workspaceId,
    ReimbursementCommand command,
  ) {
    sent++;
    return super.recordReimbursement(workspaceId, command);
  }
}

ReimbursementCommand _cmd(int cents, {String id = 'r1', int revision = 1}) =>
    ReimbursementCommand(
      obligationId: 'o1',
      amountCents: cents,
      revision: revision,
      requestId: id,
      paidOn: DateTime(2026, 10, 16),
    );

void main() {
  test('the permission the money screen asks for is the catalogue\'s', () {
    expect(
      purchasePayPermission,
      WorkspacePermission.recordOutgoingPayments.wireName,
    );
  });

  test('a claim decodes with its payments and their reversals', () {
    final o = PurchaseObligation.fromJson(
      _claim(
        'o1',
        paid: 3000,
        mine: true,
        allocations: [
          {
            'id': 'a1',
            'kind': 'payment',
            'amount_cents': 5000,
            'method': 'cash',
            'reference': 'r',
            'paid_on': '2026-10-16',
            'reversed': true,
          },
          {
            'id': 'a2',
            'kind': 'reversal',
            'amount_cents': -5000,
            'method': 'cash',
            'reference': '',
            'paid_on': '2026-10-16',
            'reversed': false,
          },
          {
            'id': 'a3',
            'kind': 'payment',
            'amount_cents': 3000,
            'method': 'bank_transfer',
            'reference': '',
            'paid_on': '2026-10-17',
            'reversed': false,
          },
        ],
      ),
    );
    expect(o.paidCents, 3000);
    expect(o.mine, isTrue);
    expect(o.allocations.map((a) => a.reversible), [false, false, true]);
    expect(o.allocations[1].amountCents, -5000);
    expect(o.payable, isTrue);
  });

  test('a claim without its paid amount is a shape error', () {
    final broken = _claim('o1')..remove('paid_cents');
    expect(() => PurchaseObligation.fromJson(broken), throwsA(isA<Object>()));
  });

  test('an applied or paid-up claim is not payable', () {
    expect(
      PurchaseObligation.fromJson(
        _claim(
          'o1',
          invoice: {
            'id': 'i',
            'number': 'N',
            'issued_at': '2026-10-17T00:00:00Z',
            'total_cents': -1,
          },
        ),
      ).payable,
      isFalse,
    );
    expect(
      PurchaseObligation.fromJson(_claim('o1', paid: 12000)).payable,
      isFalse,
    );
  });

  test('the command sends nothing for an amount that cannot be paid', () async {
    final repo = _Counting();
    final claim = PurchaseObligation.fromJson(_claim('o1'));
    repo.payables.add(_row(_claim('o1')));
    final commands = PurchaseCommands(repo);
    expect(await commands.reimburse('ws', claim, _cmd(0)), isNull);
    expect(await commands.reimburse('ws', claim, _cmd(-1)), isNull);
    expect(await commands.reimburse('ws', claim, _cmd(12001)), isNull);
    expect(repo.sent, 0);
    final after = await commands.reimburse('ws', claim, _cmd(5000));
    expect(after?.paidCents, 5000);
    expect(after?.remainingCents, 7000);
    expect(after?.revision, 2);
    expect(repo.sent, 1);
  });

  test('the same request id answers the payment already made', () async {
    final repo = FakePurchaseRepository()..payables.add(_row(_claim('o1')));
    final first = await repo.recordReimbursement('ws', _cmd(5000));
    final again = await repo.recordReimbursement('ws', _cmd(5000));
    expect(again.paidCents, first.paidCents);
    expect(repo.payables.single.obligation.paidCents, 5000);
  });

  testWidgets('who sees the Record payment button', (tester) async {
    final repo = FakePurchaseRepository()
      ..payables.addAll([
        _row(_claim('o1')),
        _row(_claim('o2', mine: true)),
        _row(_claim('o3', paid: 12000)),
      ]);
    Future<void> open({required bool canPay}) async {
      await tester.pumpWidget(
        _app(
          PurchasesView(workspaceId: 'ws', canCapture: false, canPay: canPay),
          [
            purchaseRepositoryProvider.overrideWithValue(repo),
            memberLabelsProvider.overrideWithValue({'m1': 'Alex Martin'}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('To pay'));
      await tester.pumpAndSettle();
    }

    await open(canPay: false);
    expect(find.byKey(const ValueKey('payable-pay-o1')), findsNothing);

    await open(canPay: true);
    expect(find.byKey(const ValueKey('payable-pay-o1')), findsOneWidget);
    expect(find.byKey(const ValueKey('payable-pay-o2')), findsNothing);
    expect(find.byKey(const ValueKey('payable-pay-o3')), findsNothing);
  });

  testWidgets('a failed save keeps the form; the retry reuses the request', (
    tester,
  ) async {
    final repo = _Flaky()..payables.add(_row(_claim('o1')));
    await tester.pumpWidget(
      _app(
        const PurchasesView(workspaceId: 'ws', canCapture: false, canPay: true),
        [
          purchaseRepositoryProvider.overrideWithValue(repo),
          memberLabelsProvider.overrideWithValue({'m1': 'Alex Martin'}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('To pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payable-pay-o1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '50');
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-save')), findsOneWidget);
    expect(find.widgetWithText(TextField, '50'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await tester.pumpAndSettle();
    expect(repo.requestIds, hasLength(2));
    expect(repo.requestIds[0], repo.requestIds[1]);
    expect(find.byKey(const ValueKey('pay-save')), findsNothing);
    final claim = repo.payables.single.obligation;
    expect(claim.paidCents, 5000);
    expect(claim.remainingCents, 7000);
  });

  testWidgets('an amount above what remains is refused in the form', (
    tester,
  ) async {
    final repo = _Counting()..payables.add(_row(_claim('o1')));
    await tester.pumpWidget(
      _app(
        const PurchasesView(workspaceId: 'ws', canCapture: false, canPay: true),
        [
          purchaseRepositoryProvider.overrideWithValue(repo),
          memberLabelsProvider.overrideWithValue({'m1': 'Alex Martin'}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('To pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payable-pay-o1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '120.01');
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-invalid')), findsOneWidget);
    expect(repo.sent, 0);
  });
}
