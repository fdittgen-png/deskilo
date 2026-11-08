// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: scoped approvers do not mislabel inaccessible FX as missing, while
// the existing broad purchase path retains its recorded-rate UI and edit door.
import 'package:deskilo/core/demo/data/purchase_approval_reads.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = PurchaseSummary(
  id: 'fx-bill',
  kind: PurchaseKind.bill,
  state: PurchaseState.pending,
  category: 'Supplies',
  reference: 'FX-1',
  currency: 'CHF',
  grossCents: 1200,
);
const _bill = PurchaseDetail(
  summary: _summary,
  revision: 1,
  lines: [PurchaseLine(lineNo: 1, description: 'Supplies', grossCents: 1200)],
  sources: [],
);

class _Purchases extends FakePurchaseRepository {
  bool unavailable = false;
  int rateReads = 0;
  @override
  Future<DocumentExchangeRate?> fetchExchangeRate(
    String workspaceId,
    String purchaseId,
  ) async {
    rateReads++;
    if (unavailable) throw StateError('rate unavailable');
    return super.fetchExchangeRate(workspaceId, purchaseId);
  }
}

Widget _app(_Purchases purchases, {required bool scoped}) => ProviderScope(
  overrides: [
    purchaseRepositoryProvider.overrideWithValue(purchases),
    purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
    purchaseApprovalReadsProvider.overrideWithValue(
      FakePurchaseApprovalReads(purchases),
    ),
    enabledFeatureKeysProvider.overrideWithValue({foreignCurrencyPurchasesKey}),
    spaceCurrencyProvider.overrideWithValue('EUR'),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => scoped
              ? showPurchaseForDecision(context, 'ws-1', 'fx-bill')
              : showPurchasesSheet(
                  context,
                  'ws-1',
                  canCapture: true,
                  canDecide: true,
                ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('scoped approver sees exact recorded rate without editing', (tester) async {
    final purchases = _Purchases()
      ..add(_bill)
      ..rememberRate(_summary, ExchangeRateEntry(
        rate: ExactDecimal.parse('1.0456789012'),
        rateDate: DateTime(2026, 5, 12),
        source: 'bank',
      ));
    await tester.pumpWidget(_app(purchases, scoped: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-line-1')), findsOneWidget);
    expect(find.textContaining('1 CHF = 1.0456789012 EUR'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-approval-fx')), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-fx-edit')), findsNothing);
    expect(find.byKey(const ValueKey('purchase-approval-evidence-unavailable')), findsOneWidget);
  });

  testWidgets('scoped missing rate is distinct from a refused read and retry', (tester) async {
    final purchases = _Purchases()..add(_bill)..unavailable = true;
    await tester.pumpWidget(_app(purchases, scoped: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
    expect(find.textContaining('No exchange rate is recorded'), findsNothing);
    purchases.unavailable = false;
    await tester.tap(find.byKey(const ValueKey('approval-detail-retry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No exchange rate is recorded'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-fx-edit')), findsNothing);
  });

  testWidgets(
    'broad purchase detail retains recorded FX and its edit control',
    (tester) async {
      final purchases = _Purchases()
        ..add(_bill)
        ..rememberRate(
          _summary,
          ExchangeRateEntry(
            rate: ExactDecimal.parse('1.06'),
            rateDate: DateTime(2026, 5, 12),
            source: 'bank',
          ),
        );
      await tester.pumpWidget(_app(purchases, scoped: false));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('purchase-fx-bill')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('purchase-approval-evidence-unavailable')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('purchase-fx')), findsOneWidget);
      expect(find.textContaining('1 CHF = 1.06 EUR'), findsOneWidget);
      expect(find.byKey(const ValueKey('purchase-fx-edit')), findsOneWidget);
      expect(purchases.rateReads, greaterThan(0));
    },
  );
}
