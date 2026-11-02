// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:deskilo/features/money/presentation/widgets/supplier_balance_line.dart';
import 'package:deskilo/features/money/providers/supplier_balance_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('balance stays currency-separated and opens supplier payables', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierBalancesProvider('ws').overrideWith(
            (ref) async => [
              const SupplierBalance(
                supplierId: 's',
                currency: 'EUR',
                remainingCents: 150,
              ),
              const SupplierBalance(
                supplierId: 's',
                currency: 'GBP',
                remainingCents: 250,
              ),
              const SupplierBalance(
                supplierId: 'other',
                currency: 'USD',
                remainingCents: 300,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SupplierBalanceLine(
              workspaceId: 'ws',
              supplierId: 's',
              onOpenPayables: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Outstanding:'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('supplier-payables-s')));
    expect(opened, isTrue);
  });

  testWidgets('a refused read is not presented as a zero balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierBalancesProvider('ws')
              .overrideWith((ref) async => throw StateError('refused')),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SupplierBalanceLine(
              workspaceId: 'ws',
              supplierId: 's',
              onOpenPayables: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Balance unavailable'), findsOneWidget);
    expect(find.text('No outstanding balance'), findsNothing);
  });
}
