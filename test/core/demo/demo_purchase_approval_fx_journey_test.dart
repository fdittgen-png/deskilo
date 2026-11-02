// SPDX-License-Identifier: AGPL-3.0-or-later
// A Demo approver recovers, reads an exact foreign rate and decides the bill.
import 'package:deskilo/core/demo/data/purchase_approval_reads.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_approvals_screen.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RetryApprovalReads implements PurchaseApprovalReads {
  _RetryApprovalReads(this.inner);
  final PurchaseApprovalReads inner;
  bool fail = true;
  @override
  Future<PurchaseApprovalPage> page(String workspaceId, {PurchaseApprovalCursor? after}) =>
      inner.page(workspaceId, after: after);
  @override
  Future<PurchaseApprovalDetail> detail(String workspaceId, String purchaseId) {
    if (fail) {
      fail = false;
      return Future.error(StateError('simulated detail refusal'));
    }
    return inner.detail(workspaceId, purchaseId);
  }
}

void main() {
  testWidgets('Demo foreign-currency bill displays its recorded rate before decision', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final demo = seedDemoPurchasing(DateTime(2026, 11, 2));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
        purchaseRepositoryProvider.overrideWithValue(demo.purchases),
        purchaseApprovalReadsProvider.overrideWithValue(_RetryApprovalReads(FakePurchaseApprovalReads(demo.purchases))),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PurchaseApprovalsView(workspaceId: 'ws-1')),
      ),
    ));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('approval-demo-bill-approval-fx'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('approval-detail-retry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 CHF = 1.0456789012 EUR'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-fx-edit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('purchase-approve')));
    await tester.pumpAndSettle();
    expect(row, findsNothing);
  });

}
