// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: a refused decision detail offers retry and respects action flags.
import 'dart:async';

import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reads implements PurchaseApprovalReads {
  int calls = 0;
  bool deny = false;
  Completer<void>? gate;
  @override
  Future<PurchaseApprovalDetail> detail(
    String workspaceId,
    String purchaseId,
  ) async {
    final pending = gate;
    if (pending != null) await pending.future;
    if (deny || calls++ == 0) throw StateError('denied');
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

class _CountingPurchases extends FakePurchaseRepository {
  int decisions = 0;
  @override
  Future<PurchaseState> decideBill(
    String workspaceId,
    String purchaseId,
    int revision, {
    required bool approve,
    required String reason,
    required String requestId,
  }) async {
    decisions++;
    return PurchaseState.approved;
  }
}

final _canApprove = StateProvider<bool>((ref) => true);
final _purchasesEnabled = StateProvider<bool>((ref) => true);

void main() {
  testWidgets('detail error can retry and own bill cannot be rejected', (
    tester,
  ) async {
    final reads = _Reads();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
          purchaseApprovalReadsProvider.overrideWithValue(reads),
        ],
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
  testWidgets('revoked permission hides previously loaded actions', (
    tester,
  ) async {
    final reads = _Reads()..calls = 1;
    final container = ProviderContainer(
      overrides: [
        purchaseApprovalAccessProvider.overrideWith(
          (ref, id) => ref.watch(_canApprove),
        ),
        purchaseApprovalReadsProvider.overrideWithValue(reads),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    container.read(_canApprove.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
  });

  testWidgets('a refreshed queue refetches detail and hides a revoked item', (
    tester,
  ) async {
    final reads = _Reads()..calls = 1;
    final container = ProviderContainer(
      overrides: [
        purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
        purchaseApprovalReadsProvider.overrideWithValue(reads),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    reads.deny = true;
    container.invalidate(
      purchaseApprovalPageProvider((workspaceId: 'ws', after: null)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
  });
  testWidgets('a revoked detail is rechecked before a decision write', (
    tester,
  ) async {
    final reads = _Reads()..calls = 1;
    final purchases = _CountingPurchases();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseApprovalAccessProvider.overrideWith((ref, id) => true),
          purchaseApprovalReadsProvider.overrideWithValue(reads),
          purchaseRepositoryProvider.overrideWithValue(purchases),
        ],
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
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    reads.deny = true;
    await tester.tap(find.byKey(const ValueKey('purchase-approve')));
    await tester.pumpAndSettle();
    expect(purchases.decisions, 0);
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
  });
  testWidgets('switching purchases off hides actions in an open sheet', (
    tester,
  ) async {
    final reads = _Reads()..calls = 1;
    final purchases = _CountingPurchases();
    final container = ProviderContainer(
      overrides: [
        currentWorkspaceProvider.overrideWith(
          (ref) async => const Workspace(
            id: 'ws',
            name: 'Space',
            countryCode: 'FR',
            currencyCode: 'EUR',
            timezone: 'UTC',
            inviteCode: '',
          ),
        ),
        myMemberProvider.overrideWith(
          (ref) async => const Member(
            id: 'm',
            workspaceId: 'ws',
            userId: 'u',
            isAdmin: false,
            isOwner: false,
            status: MemberStatus.active,
          ),
        ),
        myPermissionsProvider.overrideWith(
          (ref) => {WorkspacePermission.approveExpenses},
        ),
        enabledFeaturesSyncProvider.overrideWith(
          (ref) =>
              ref.watch(_purchasesEnabled) ? {WorkspaceFeature.purchases} : {},
        ),
        purchaseApprovalReadsProvider.overrideWithValue(reads),
        purchaseRepositoryProvider.overrideWithValue(purchases),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    await container.read(myMemberProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.byKey(const ValueKey('purchase-approve')), findsOneWidget);
    reads.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('purchase-approve')));
    await tester.pump();
    container.read(_purchasesEnabled.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-approve')), findsNothing);
    expect(find.byKey(const ValueKey('approval-detail-retry')), findsOneWidget);
    reads.gate!.complete();
    await tester.pumpAndSettle();
    expect(purchases.decisions, 0);
  });
}
