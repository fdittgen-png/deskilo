// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A supplier bill from draft to paid: sent for approval, decided by a second
// person, owed to the supplier, paid in part. What the commands refuse before
// sending, and what each button does on screen.
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
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

PurchaseDetail _bill({
  PurchaseState state = PurchaseState.draft,
  String id = 'b1',
}) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: PurchaseKind.bill,
    state: state,
    category: 'Cleaning',
    reference: 'NC-1',
    currency: 'EUR',
    grossCents: 14400,
  ),
  revision: 1,
  lines: const [
    PurchaseLine(
      lineNo: 1,
      description: 'Cleaning',
      grossCents: 14400,
      netCents: 12000,
      taxCents: 2400,
      taxRatePercent: 20,
    ),
  ],
  sources: const [],
  supplierName: 'Net & Clair',
  supplierNumber: '2',
);

PurchaseDetail _credit({String id = 'c1'}) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: PurchaseKind.creditNote,
    state: PurchaseState.draft,
    category: 'Cleaning',
    reference: 'AV-1',
    currency: 'EUR',
    grossCents: 2400,
  ),
  revision: 1,
  lines: const [
    PurchaseLine(lineNo: 1, description: 'Missed visit', grossCents: 2400),
  ],
  sources: const [],
  supplierName: 'Net & Clair',
  supplierNumber: '2',
);

void main() {
  test('the permission the money screen asks for is the catalogue\'s', () {
    expect(
      purchaseDecidePermission,
      WorkspacePermission.approveExpenses.wireName,
    );
  });

  test(
    'the commands send nothing for a bill that cannot take the step',
    () async {
      final repo = FakePurchaseRepository()..add(_bill());
      final commands = PurchaseCommands(repo);
      expect(
        await commands.submit('ws', _bill(state: PurchaseState.pending), 'r'),
        isNull,
      );
      expect(
        await commands.decide(
          'ws',
          _bill(),
          approve: true,
          reason: '',
          requestId: 'r',
        ),
        isNull,
        reason: 'a draft is not awaiting approval',
      );
      final pending = _bill(state: PurchaseState.pending);
      expect(
        await commands.decide(
          'ws',
          pending,
          approve: false,
          reason: '  ',
          requestId: 'r',
        ),
        isNull,
        reason: 'a rejection needs its reason',
      );
      expect(await commands.submit('ws', _bill(), 'r1'), PurchaseState.pending);
    },
  );

  test(
    'approval files the payable; a part payment leaves the rest owed',
    () async {
      final repo = FakePurchaseRepository()..add(_bill());
      final commands = PurchaseCommands(repo);
      await commands.submit('ws', _bill(), 'r1');
      final pending = await repo.fetchDetail('ws', 'b1');
      expect(pending.summary.state, PurchaseState.pending);
      expect(
        await commands.decide(
          'ws',
          pending,
          approve: true,
          reason: '',
          requestId: 'r2',
        ),
        PurchaseState.approved,
      );
      final payable = (await repo.fetchPayables('ws')).single.obligation;
      expect(payable.creditorKind, CreditorKind.supplier);
      expect(payable.creditorName, 'Net & Clair');
      expect(payable.remainingCents, 14400);
      final after = await commands.reimburse(
        'ws',
        payable,
        ReimbursementCommand(
          obligationId: payable.id,
          amountCents: 9000,
          revision: payable.revision,
          requestId: 'r3',
          paidOn: DateTime(2026, 10, 16),
          creditorKind: CreditorKind.supplier,
        ),
      );
      expect(after?.paidCents, 9000);
      expect(after?.remainingCents, 5400);
    },
  );

  testWidgets('the buttons follow the state and who may', (tester) async {
    final repo = FakePurchaseRepository()..add(_bill());
    Future<void> open({required bool capture, required bool decide}) async {
      await tester.pumpWidget(
        _app(
          PurchasesView(
            workspaceId: 'ws',
            canCapture: capture,
            canPay: true,
            canDecide: decide,
          ),
          [
            purchaseRepositoryProvider.overrideWithValue(repo),
            memberLabelsProvider.overrideWithValue({}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('purchase-b1')));
      await tester.pumpAndSettle();
    }

    await open(capture: false, decide: true);
    expect(find.byKey(const ValueKey('purchase-submit')), findsNothing);
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);

    await open(capture: true, decide: false);
    expect(find.byKey(const ValueKey('purchase-submit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('purchase-submit')));
    await tester.pumpAndSettle();
    expect(repo.payables, isEmpty);
    expect(find.byKey(const ValueKey('purchase-submit')), findsNothing);
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);

    await open(capture: false, decide: true);
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('purchase-reject')));
    await tester.pumpAndSettle();
    // A rejection without a reason is not sent.
    await tester.tap(find.byKey(const ValueKey('purchase-reject-confirm')));
    await tester.pumpAndSettle();
    expect(repo.payables, isEmpty);
    expect(
      (await repo.fetchDetail('ws', 'b1')).summary.state,
      PurchaseState.pending,
    );

    await tester.tap(find.byKey(const ValueKey('purchase-approve')));
    await tester.pumpAndSettle();
    expect(
      (await repo.fetchDetail('ws', 'b1')).summary.state,
      PurchaseState.approved,
    );
    expect(repo.payables.single.obligation.creditorKind, CreditorKind.supplier);
  });

  testWidgets('a supplier payable is listed by its name and can be paid', (
    tester,
  ) async {
    final repo = FakePurchaseRepository()
      ..addApprovedBill(_bill(id: 'b2'), 'sup-1');
    await tester.pumpWidget(
      _app(
        const PurchasesView(workspaceId: 'ws', canCapture: false, canPay: true),
        [
          purchaseRepositoryProvider.overrideWithValue(repo),
          memberLabelsProvider.overrideWithValue({}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('To pay'));
    await tester.pumpAndSettle();
    expect(find.text('Owed to Net & Clair'), findsOneWidget);
    expect(find.byKey(const ValueKey('payables-empty-supplier')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('payable-pay-demo-payable-b2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '90');
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await tester.pumpAndSettle();
    expect(repo.payables.single.obligation.paidCents, 9000);
    expect(repo.payables.single.obligation.remainingCents, 5400);
  });

  testWidgets('a credit note is applied to the payable of its bill', (
    tester,
  ) async {
    final repo = FakePurchaseRepository()
      ..addApprovedBill(_bill(id: 'b3'), 'sup-1')
      ..add(_credit());
    Future<void> open({required bool decide}) async {
      await tester.pumpWidget(
        _app(
          PurchasesView(
            workspaceId: 'ws',
            canCapture: true,
            canPay: true,
            canDecide: decide,
          ),
          [
            purchaseRepositoryProvider.overrideWithValue(repo),
            memberLabelsProvider.overrideWithValue({}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('purchase-c1')));
      await tester.pumpAndSettle();
    }

    await open(decide: false);
    expect(find.byKey(const ValueKey('purchase-apply-credit')), findsNothing);

    await open(decide: true);
    await tester.tap(find.byKey(const ValueKey('purchase-apply-credit')));
    await tester.pumpAndSettle();
    final o = repo.payables.single.obligation;
    expect(o.paidCents, 2400);
    expect(o.remainingCents, 12000);
    expect(o.allocations.single.isCredit, isTrue);
    expect(o.allocations.single.reversible, isFalse);
    expect(
      (await repo.fetchDetail('ws', 'c1')).summary.state,
      PurchaseState.approved,
    );
    expect(find.byKey(const ValueKey('purchase-apply-credit')), findsNothing);
  });

  test('only a draft credit note is sent to be applied', () async {
    final repo = FakePurchaseRepository()..add(_bill());
    final commands = PurchaseCommands(repo);
    expect(await commands.applyCredit('ws', _bill(), 'r'), isNull);
    expect(
      await commands.applyCredit(
        'ws',
        const PurchaseDetail(
          summary: PurchaseSummary(
            id: 'c9',
            kind: PurchaseKind.creditNote,
            state: PurchaseState.approved,
            category: 'Cleaning',
            reference: 'AV-9',
            currency: 'EUR',
            grossCents: 100,
          ),
          revision: 1,
          lines: [],
          sources: [],
        ),
        'r',
      ),
      isNull,
    );
  });
}
