// SPDX-License-Identifier: AGPL-3.0-or-later
// Switching personas replaces the actual DemoWorkspace container. Orders and
// approved bills and bank records remain on the fixture; only Reset reseeds them.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  testWidgets('commercial writes survive owner, member, owner scope rebuilds',
    (tester) async {
      final root = ProviderContainer();
      addTearDown(root.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: root,
        child: const DemoWorkspace(child: MaterialApp(home:
          SizedBox(key: Key('demo-commerce-content'))))));
      await tester.pumpAndSettle();
      ProviderContainer scope() => ProviderScope.containerOf(
        tester.element(find.byKey(const Key('demo-commerce-content'))));
      Future<void> enter(ProviderContainer c) async {
        c
          ..listen(currentWorkspaceProvider, (_, _) {})
          ..listen(myPermissionsProvider, (_, _) {});
        // This child has no workspace screen to drive provider rebuilds.
        // Pump the newly watched graph before awaiting it in fake async.
        await tester.pumpAndSettle();
        await c.read(activeWorkspaceIdProvider.future);
        // Match DemoWorkspace's deep-link/switcher path: select also moves
        // the account default, so auth resolution cannot restore home.
        await c.read(activeWorkspaceIdProvider.notifier).select('ws-5');
        await tester.pumpAndSettle();
        expect((await c.read(currentWorkspaceProvider.future))?.id, 'ws-5');
        await c.read(myMemberProvider.future);
        final fixture = root.read(demoSessionControllerProvider).fixture;
        expect(c.read(purchaseRepositoryProvider),
          same(fixture.zurich.purchasing.purchases));
        expect(c.read(purchaseOrderRepositoryProvider),
          same(fixture.commerce.orders.zurich));
      }
      final first = scope();
      await enter(first);
      final purchases = first.read(purchaseRepositoryProvider);
      final pending = await purchases.fetchDetail('ws-5', 'ch-bill-pending');
      await purchases.decideBill('ws-5', pending.summary.id, pending.revision,
        approve: true, reason: '', requestId: 'persist-approval');
      final orders = first.read(purchaseOrderRepositoryProvider);
      final draft = (await orders.fetchOrders('ws-5'))
        .firstWhere((o) => o.state == PurchaseOrderState.draft);
      await orders.cancel('ws-5', draft.id, draft.revision,
        'The business no longer needs it', 'persist-cancellation');

      final fixture = root.read(demoSessionControllerProvider).fixture;
      final money = fixture.zurich.money;
      final invoice = money.invoices.firstWhere((invoice) =>
        invoice.memberId == 'member-2' &&
        !money.invoiceMatchesStore.containsKey(invoice.id));
      final bank = first.read(bankStatementRepositoryProvider);
      final seededStatements = (await bank.fetchStatements('ws-5'))
        .map((statement) => statement.statementRef).toSet();
      final imported = await bank.importStatement('ws-5',
        statement: BankStatement(format: BankFileFormat.camt054,
          account: 'PERSISTENT-CH-ACCOUNT', currency: invoice.currency,
          statementId: 'PERSISTENT-CH-STATEMENT', lines: [BankLine(
            position: 1, bookingDate: fixture.seededAt,
            valueDate: fixture.seededAt, amountCents: invoice.totalCents,
            currency: invoice.currency, transactionId: 'persistent-receipt')]),
        sourceSha256: 'persistent-source', fileName: 'persistent.xml');
      await bank.storeOriginal('ws-5', sourceSha256: 'persistent-source',
        bytes: const [1, 2, 3]);
      final line = (await bank.fetchLines(imported.statementId)).single;
      expect(await bank.matchLine(line.id, invoiceId: invoice.id,
        resolution: 'exact', note: ''), BankLineStatus.matched);

      final session = root.read(demoSessionControllerProvider.notifier)
        ..viewAs(DemoPersona.member);
      await tester.pumpAndSettle();
      expect(scope(), isNot(same(first)));
      await enter(scope());
      final memberBank = scope().read(bankStatementRepositoryProvider);
      expect(memberBank, same(bank));
      await expectLater(memberBank.unmatchIn(line.id,
        reason: 'A member cannot undo this receipt', requestId: 'member-refused'),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
      session.viewAs(DemoPersona.owner);
      await tester.pumpAndSettle();
      final returned = scope();
      expect(returned, isNot(same(first)));
      await enter(returned);
      expect(returned.read(purchaseRepositoryProvider), same(purchases));
      expect(returned.read(purchaseOrderRepositoryProvider), same(orders));
      expect((await purchases.fetchDetail('ws-5', pending.summary.id))
        .summary.state, PurchaseState.approved);
      expect((await orders.fetchOrders('ws-5')).singleWhere((o) => o.id == draft.id)
        .state, PurchaseOrderState.cancelled);
      final returnedBank = returned.read(bankStatementRepositoryProvider);
      expect(returnedBank, same(bank));
      final retained = (await returnedBank.fetchLines(imported.statementId)).single;
      expect(retained.status, BankLineStatus.matched);
      expect(retained.invoiceId, invoice.id);
      expect(await returnedBank.fetchOriginal('ws-5', 'persistent-source'), [1, 2, 3]);
      expect(money.invoiceMatchesStore[invoice.id]?.paidCents, invoice.totalCents);

      session.reset();
      await tester.pumpAndSettle();
      final reset = scope();
      await enter(reset);
      expect(reset.read(purchaseRepositoryProvider), isNot(same(purchases)));
      expect((await reset.read(purchaseRepositoryProvider)
        .fetchDetail('ws-5', 'ch-bill-pending')).summary.state,
        PurchaseState.pending);
      final resetBank = reset.read(bankStatementRepositoryProvider);
      expect(resetBank, isNot(same(bank)));
      expect((await resetBank.fetchStatements('ws-5'))
        .map((statement) => statement.statementRef).toSet(), seededStatements);
      await expectLater(resetBank.fetchOriginal('ws-5', 'persistent-source'),
        throwsStateError);
      expect(root.read(demoSessionControllerProvider).fixture.zurich.money
        .invoiceMatchesStore.containsKey(invoice.id), isFalse);
    });
}
