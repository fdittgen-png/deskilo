// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the approvals queue: only the documents waiting for a decision,
// an empty state when nothing waits, and a refusal that says so.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/features/money/presentation/screens/purchase_approvals_screen.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseSummary _doc(String id, PurchaseState state) => PurchaseSummary(
  id: id,
  kind: PurchaseKind.bill,
  state: state,
  category: '',
  reference: 'F-$id',
  currency: 'EUR',
  grossCents: 1200,
);

Widget _app(Future<List<PurchaseSummary>> Function() read) => ProviderScope(
  overrides: [
    purchaseApprovalPageProvider.overrideWith((ref, key) async {
      final all = await read();
      final pending = [
        for (final d in all)
          if (d.state == PurchaseState.pending && d.kind == PurchaseKind.bill)
            d,
      ];
      return PurchaseApprovalPage(
        rows: pending,
        count: pending.length,
        version: 'v',
      );
    }),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PurchaseApprovalsView(workspaceId: 'ws')),
  ),
);

void main() {
  testWidgets('lists only the documents waiting for a decision', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        () async => [
          _doc('1', PurchaseState.pending),
          _doc('2', PurchaseState.approved),
          _doc('3', PurchaseState.draft),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('approval-2')), findsNothing);
    expect(find.byKey(const ValueKey('approval-3')), findsNothing);
  });

  testWidgets('nothing waiting shows the empty state', (tester) async {
    await tester.pumpWidget(
      _app(() async => [_doc('2', PurchaseState.approved)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('No supplier bills await your approval.'), findsOneWidget);
  });

  testWidgets('a failed read says so instead of an empty list', (tester) async {
    await tester.pumpWidget(_app(() async => throw StateError('refused')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approvals-error')), findsOneWidget);
    expect(find.text('No supplier bills await your approval.'), findsNothing);
  });
  testWidgets(
    'page continuation detects equal-count queue change and offers retry',
    (tester) async {
      const cursor = (created: '2026-01-01T00:00:00Z', id: '1');
      var bad = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseApprovalPageProvider.overrideWith((ref, key) async {
              if (key.after == null) {
                return PurchaseApprovalPage(
                  rows: [_doc('1', PurchaseState.pending)],
                  count: 2,
                  version: 'v1',
                  next: cursor,
                );
              }
              return PurchaseApprovalPage(
                rows: [_doc('2', PurchaseState.pending)],
                count: 2,
                version: bad ? 'v2' : 'v1',
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PurchaseApprovalsView(workspaceId: 'ws')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('approval-load-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('approval-2')), findsOneWidget);
      bad = true;
      ProviderScope.containerOf(
        tester.element(find.byType(PurchaseApprovalsView)),
      ).invalidate(
        purchaseApprovalPageProvider((workspaceId: 'ws', after: cursor)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('approvals-error')), findsOneWidget);
      bad = false;
      await tester.tap(find.byKey(const ValueKey('approvals-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('approval-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('approval-load-more')), findsOneWidget);
    },
  );
}
