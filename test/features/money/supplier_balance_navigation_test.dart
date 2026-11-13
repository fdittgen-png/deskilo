// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — Only permitted users with Purchases enabled reach the supplier-scoped payables.

import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_balance_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/screens/suppliers_desk.dart';
import 'package:deskilo/features/money/presentation/screens/suppliers_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

PayableRow _row(String id, String supplier, int remaining) => PayableRow(
  obligation: PurchaseObligation(
    id: id,
    purchaseId: 'purchase-$id',
    creditorKind: CreditorKind.supplier,
    creditorId: supplier,
    amountCents: 1000,
    currency: 'EUR',
    appliedCents: 0,
    remainingCents: remaining,
  ),
  purchase: PurchaseSummary(
    id: 'purchase-$id',
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: '',
    reference: id,
    currency: 'EUR',
    grossCents: 1000,
  ),
);

void main() {
  testWidgets(
    'balance is not read when purchases are off or permission is missing',
    (tester) async {
      final suppliers = FakeSupplierRepository();
      final supplier = await suppliers.save(
        'ws',
        const SupplierDraft(name: 'ACME'),
      );
      final purchases = FakePurchaseRepository();
      var reads = 0;
      for (final (features, permissions) in [
        (
          {WorkspaceFeature.supplyExpenses},
          {WorkspacePermission.managePurchases},
        ),
        (
          {WorkspaceFeature.purchases, WorkspaceFeature.supplyExpenses},
          <WorkspacePermission>{},
        ),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              currentWorkspaceProvider.overrideWith((ref) async => _workspace),
              myMemberProvider.overrideWith((ref) async => null),
              myPermissionsProvider.overrideWithValue(permissions),
              enabledFeaturesSyncProvider.overrideWithValue(features),
              supplierRepositoryProvider.overrideWithValue(suppliers),
              purchaseRepositoryProvider.overrideWithValue(purchases),
              supplierBalancesProvider('ws').overrideWith((ref) async {
                reads++;
                return [];
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SuppliersScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('supplier-payables-$supplier')),
          findsNothing,
        );
      }
      expect(reads, 0);
    },
  );

  testWidgets('supplier balance opens only that supplier’s payables', (
    tester,
  ) async {
    final suppliers = FakeSupplierRepository();
    final supplier = await suppliers.save(
      'ws',
      const SupplierDraft(name: 'ACME'),
    );
    final other = await suppliers.save(
      'ws',
      const SupplierDraft(name: 'Other'),
    );
    final purchases = FakePurchaseRepository()
      ..payables.addAll([
        _row('partial', supplier, 400),
        _row('settled', supplier, 0),
        _row('other', other, 800),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentWorkspaceProvider.overrideWith((ref) async => _workspace),
          myMemberProvider.overrideWith((ref) async => null),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.managePurchases,
          }),
          enabledFeaturesSyncProvider.overrideWithValue({
            WorkspaceFeature.purchases,
            WorkspaceFeature.supplyExpenses,
          }),
          supplierRepositoryProvider.overrideWithValue(suppliers),
          purchaseRepositoryProvider.overrideWithValue(purchases),
          supplierBalanceRepositoryProvider.overrideWithValue(
            FakeSupplierBalanceRepository(
              workspaceId: 'ws',
              purchases: purchases,
            ),
          ),
          memberLabelsProvider.overrideWithValue({}),
        ],
        // #3615 — a supplier opens at its address, its payables a page.
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/money/suppliers',
            routes: [
              GoRoute(
                path: '/money/suppliers',
                builder: (_, _) => const SuppliersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => SupplierRecord(
                      workspaceId: 'ws',
                      supplierId: state.pathParameters['id']!,
                      held: const {'managePurchases'},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('supplier-payables-$supplier')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payable-partial')), findsOneWidget);
    expect(find.byKey(const ValueKey('payable-settled')), findsOneWidget);
    expect(find.byKey(const ValueKey('payable-other')), findsNothing);
  });
}
