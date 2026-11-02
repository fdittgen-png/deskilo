// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: a refused decision detail offers retry and respects action flags.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reads implements PurchaseApprovalReads {
  int calls = 0;
  @override
  Future<PurchaseApprovalDetail> detail(
    String workspaceId,
    String purchaseId,
  ) async {
    if (calls++ == 0) throw StateError('denied');
    return const PurchaseApprovalDetail(
      detail: PurchaseDetail(
        summary: PurchaseSummary(
          id: 'own',
          kind: PurchaseKind.bill,
          state: PurchaseState.pending,
          category: '',
          reference: '',
          currency: 'EUR',
        ),
        revision: 1,
        lines: [],
        sources: [],
      ),
      canApprove: true,
      canReject: false,
    );
  }

  @override
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  }) async => const PurchaseApprovalPage(rows: [], count: 0, version: 'v');
}

void main() {
  testWidgets('detail error can retry and own bill cannot be rejected', (
    tester,
  ) async {
    final reads = _Reads();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseApprovalReadsProvider.overrideWithValue(reads)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPurchaseForDecision(context, 'ws', 'own'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('approval-detail-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-reject')), findsNothing);
  });
}
