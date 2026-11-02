// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:deskilo/features/money/domain/supplier_payables_page.dart';
import 'package:deskilo/features/money/presentation/widgets/supplier_payables_view.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pages implements SupplierBalanceRepository {
  final seen = <SupplierPayablesCursor?>[];
  bool fail = false;
  bool firstPageChanged = false;

  @override
  Future<List<SupplierBalance>> fetchBalances(String workspaceId) async => [];

  @override
  Future<SupplierPayablesPage> fetchPayables(
    String workspaceId,
    String supplierId, {
    SupplierPayablesCursor? after,
  }) async {
    seen.add(after);
    if (fail) throw StateError('refused');
    return SupplierPayablesPage(
      rows: const [],
      next: after == null && !firstPageChanged
          ? (created: '2026-01-01T00:00:00Z', id: 'last')
          : null,
    );
  }
}

void main() {
  testWidgets('supplier payables request the continuation explicitly', (
    tester,
  ) async {
    final repo = _Pages();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierBalanceRepositoryProvider.overrideWithValue(repo),
          memberLabelsProvider.overrideWithValue({}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SupplierPayablesView(
                workspaceId: 'ws',
                supplierId: 'supplier',
                onOpen: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.seen, [null]);
    await tester.tap(find.byKey(const ValueKey('supplier-payables-more')));
    await tester.pumpAndSettle();
    expect(repo.seen, [null, (created: '2026-01-01T00:00:00Z', id: 'last')]);
    expect(find.byKey(const ValueKey('supplier-payables-more')), findsNothing);
    repo.firstPageChanged = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SupplierPayablesView)),
    );
    container.invalidate(
      supplierPayablesPageProvider((
        workspaceId: 'ws',
        supplierId: 'supplier',
        after: null,
      )),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payables unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Payables unavailable'), findsNothing);
  });

  testWidgets('refusal shows an error and allows a fresh retry', (
    tester,
  ) async {
    final repo = _Pages()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierBalanceRepositoryProvider.overrideWithValue(repo),
          memberLabelsProvider.overrideWithValue({}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SupplierPayablesView(
              workspaceId: 'ws',
              supplierId: 'supplier',
              onOpen: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payables unavailable'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('supplier-payables-more')),
      findsOneWidget,
    );
  });
}
