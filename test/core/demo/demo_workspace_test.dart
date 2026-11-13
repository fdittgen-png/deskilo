// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1375 — the Reset control, driven the way a visitor drives it.
//
// The session test proves the semantics; this proves the control is
// wired to them: a screen INSIDE the Demo scope reads the fixture, a tap
// on Reset replaces the scope, and the screen that comes back is reading
// the canonical dataset again without anyone telling it to refresh.
import 'dart:async';

import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/purchase_draft.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    show SupplierDraft;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A screen inside the scope: it reads the repository the scope provides,
/// exactly as a real one does.
class _Levels extends ConsumerStatefulWidget {
  const _Levels();
  @override
  ConsumerState<_Levels> createState() => _LevelsState();
}

class _LevelsState extends ConsumerState<_Levels> {
  int? _count;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final levels =
        await ref.read(floorPlanRepositoryProvider).fetchLevels('ws-1');
    if (mounted) setState(() => _count = levels.length);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('levels: ${_count ?? '…'}')),
      );
}

void main() {
  // The bar names the demo's date; the app's localization delegates load the
  // date data in production, this test mounts the bar without them.
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('Reset restores the dataset the visitor started from', (
    tester,
  ) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final canonical = root.read(demoSessionControllerProvider).fixture;
    expect(find.textContaining('levels: '), findsOneWidget);
    final before = tester.widget<Text>(find.textContaining('levels: ')).data!;

    // A visitor changes something.
    await canonical.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DemoControls.resetKey));
    await tester.pumpAndSettle();

    expect(root.read(demoSessionControllerProvider).generation, 1);
    expect(
      tester.widget<Text>(find.textContaining('levels: ')).data,
      before,
      reason: 'the rebuilt scope handed the screen a fresh fixture',
    );
  });

  testWidgets('View as switches the identity and rebuilds the subtree', (
    tester,
  ) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: _Levels())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The owner'), findsOneWidget);

    // One tap per persona: owner → member, the ring the bar cycles.
    await tester.tap(find.byKey(DemoControls.viewAsKey));
    await tester.pumpAndSettle();

    final session = root.read(demoSessionControllerProvider);
    expect(session.persona, DemoPersona.member);
    expect(session.fixture.auth.currentUserId, DemoPersona.member.userId);
    expect(
      session.generation,
      0,
      reason: 'a viewpoint changed, not the dataset',
    );
    expect(find.text('A member'), findsOneWidget);
  });

  testWidgets('a visitor\'s purchase, supplier, book period and bank match '
      'survive a switch of persona, and a Reset gives the seeded state '
      'again (#3865)', (tester) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);
    late WidgetRef scope;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: DemoWorkspace(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                scope = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = root.read(demoSessionControllerProvider.notifier);

    Future<void> settle() async {
      await tester.pumpAndSettle();
      await scope.read(currentWorkspaceProvider.future);
    }

    await settle();
    // The visitor records: a supplier bill, a supplier, a reopened book
    // period and a matched bank line.
    final billId = await scope.read(purchaseRepositoryProvider).saveDraft(
      'ws-1',
      'req-3865',
      const PurchaseBillDraft(grossCents: 4242, reference: 'SWITCH-3865'),
    );
    final supplierId = await scope
        .read(supplierRepositoryProvider)
        .save('ws-1', const SupplierDraft(name: 'Switch Supplies'));
    final period = (await scope.read(bookPeriodRepositoryProvider).fetch('ws-1'))
        .periods
        .firstWhere((p) => p.closed);
    await scope
        .read(bookPeriodRepositoryProvider)
        .reopen('ws-1', period.id, 'a visitor reopens it');
    final bank = scope.read(bankStatementRepositoryProvider)
        as FakeBankStatementRepository;
    final statement = (await bank.fetchStatements('ws-1')).first;
    final money = root.read(demoSessionControllerProvider).fixture.money;
    // One of the movements that pays an open invoice to the cent.
    final (line, invoice) = [
      for (final l in await bank.fetchLines(statement.id))
        if (l.isMoneyIn && l.status == BankLineStatus.open)
          for (final i in money.invoices)
            if (i.workspaceId == 'ws-1' &&
                i.currency == l.currency &&
                i.totalCents == l.amountCents &&
                !money.invoiceMatchesStore.containsKey(i.id))
              (l, i),
    ].first;
    await bank.matchLine(
      line.id,
      invoiceId: invoice.id,
      resolution: 'exact',
      note: '',
    );

    Future<void> expectKept() async {
      final purchases =
          await scope.read(purchaseRepositoryProvider).fetchPurchases('ws-1');
      expect(purchases.map((p) => p.id), contains(billId));
      final suppliers =
          await scope.read(supplierRepositoryProvider).fetchSuppliers('ws-1');
      expect(suppliers.map((s) => s.id), contains(supplierId));
      final periods =
          (await scope.read(bookPeriodRepositoryProvider).fetch('ws-1')).periods;
      expect(periods.firstWhere((p) => p.id == period.id).closed, isFalse);
      final again = scope.read(bankStatementRepositoryProvider)
          as FakeBankStatementRepository;
      final lines = await again.fetchLines(statement.id);
      expect(
        lines.firstWhere((l) => l.id == line.id).status,
        isNot(BankLineStatus.open),
        reason: 'the matched bank line is still matched',
      );
    }

    await expectKept();
    controller.viewAs(DemoPersona.member);
    await settle();
    controller.viewAs(DemoPersona.owner);
    await settle();
    await expectKept();

    // A Reset is a new dataset: the seeded state, not the visitor's.
    controller.reset();
    await settle();
    expect(
      (await scope.read(purchaseRepositoryProvider).fetchPurchases('ws-1'))
          .map((p) => p.id),
      isNot(contains(billId)),
    );
    expect(
      (await scope.read(supplierRepositoryProvider).fetchSuppliers('ws-1'))
          .map((s) => s.id),
      isNot(contains(supplierId)),
    );
    expect(
      (await scope.read(bookPeriodRepositoryProvider).fetch('ws-1')).periods
          .firstWhere((p) => p.id == period.id)
          .closed,
      isTrue,
    );
  });

  testWidgets('the bar says what this space is, for a screen reader too', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(
        child: DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: SizedBox())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Demo · '), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('demonstration space')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
