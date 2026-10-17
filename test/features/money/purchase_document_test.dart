// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The purchase document on the wire and on screen: the decoded detail (tax
// unknown is not zero), the bill payload (no actor, state or total is sent),
// the command's refusals, and the sheet's capture flow, including a failed
// save that keeps the form and retries under the same request id.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

/// Refuses the first save, then behaves; remembers every request id.
class _FlakyRepository extends FakePurchaseRepository {
  final requestIds = <String>[];
  var _failed = false;

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  ) async {
    requestIds.add(requestId);
    if (!_failed) {
      _failed = true;
      throw StateError('network');
    }
    return super.saveDraft(workspaceId, requestId, draft);
  }
}

void main() {
  test('the permission the money screen asks for is the catalogue\'s', () {
    expect(
      purchaseManagePermission,
      WorkspacePermission.managePurchases.wireName,
    );
  });

  test('a detail decodes; a tax the document did not state stays unknown', () {
    final d = PurchaseDetail.fromJson({
      'id': 'p1',
      'kind': 'member_receipt',
      'state': 'pending',
      'revision': 2,
      'currency': 'EUR',
      'legacy_qualification': 'legacy_unverified',
      'supplier': null,
      'due_on': null,
      'lines': [
        {
          'line_no': 1,
          'description': 'A',
          'gross_cents': 12000,
          'net_cents': 10000,
          'tax_cents': 2000,
          'tax_rate_percent': 20.0,
        },
        {'line_no': 2, 'description': 'B', 'gross_cents': 500},
      ],
      'sources': [
        {'source_kind': 'expense_event', 'source_id': 'e1', 'role': 'origin'},
      ],
    });
    expect(d.summary.kind, PurchaseKind.memberReceipt);
    expect(d.summary.state, PurchaseState.pending);
    expect(d.summary.legacy, isTrue);
    expect(d.grossCents, 12500);
    expect(d.taxCents, 2000);
    expect(d.taxPartial, isTrue);
    expect(d.lines[1].taxStated, isFalse);
    expect(d.sources.single.kind, 'expense_event');
  });

  test('the bill payload carries no actor, state or total', () {
    final payload = PurchaseBillDraft(
      grossCents: 90000,
      taxCents: 15000,
      reference: 'F-7',
      description: 'Rent',
      supplierId: 's1',
      dueOn: DateTime(2026, 11, 30),
    ).toPayload();
    expect(payload['kind'], 'bill');
    expect(payload['due_on'], '2026-11-30');
    for (final forbidden in ['state', 'submitter_member_id', 'total_cents']) {
      expect(payload.containsKey(forbidden), isFalse, reason: forbidden);
    }
    final line = (payload['lines']! as List).single as Map;
    expect(line['net_cents'], 75000);
    final untaxed = const PurchaseBillDraft(grossCents: 100).toPayload();
    expect(
      ((untaxed['lines']! as List).single as Map).containsKey('tax_cents'),
      isFalse,
    );
  });

  test(
    'the command sends nothing for an amount or tax that cannot be',
    () async {
      final repo = FakePurchaseRepository();
      final commands = PurchaseCommands(repo);
      expect(
        await commands.saveBill(
          'ws',
          'r1',
          const PurchaseBillDraft(grossCents: 0),
        ),
        isNull,
      );
      expect(
        await commands.saveBill(
          'ws',
          'r2',
          const PurchaseBillDraft(grossCents: 100, taxCents: 101),
        ),
        isNull,
      );
      expect(await repo.fetchPurchases('ws'), isEmpty);
      final id = await commands.saveBill(
        'ws',
        'r3',
        const PurchaseBillDraft(grossCents: 100, taxCents: 0),
      );
      expect(id, isNotNull);
      // a stated zero is a tax, not an unknown one
      expect((await repo.fetchDetail('ws', id!)).taxPartial, isFalse);
      // the same request id replays instead of doubling
      expect(
        await commands.saveBill(
          'ws',
          'r3',
          const PurchaseBillDraft(grossCents: 100, taxCents: 0),
        ),
        id,
      );
      expect(await repo.fetchPurchases('ws'), hasLength(1));
    },
  );

  testWidgets('a manager captures a bill; it is listed and opens', (
    tester,
  ) async {
    final repo = FakePurchaseRepository();
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: true), [
        purchaseRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('purchase-reference')),
      'F-7',
    );
    await tester.enterText(find.byKey(const ValueKey('purchase-gross')), '900');
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    final id = (await repo.fetchPurchases('ws')).single.id;
    expect(find.byKey(ValueKey('purchase-$id')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('purchase-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-state')), findsOneWidget);
    expect(find.text('Tax not stated'), findsOneWidget);
  });

  testWidgets('a member sees no capture door', (tester) async {
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: false), [
        purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-add-bill')), findsNothing);
    expect(find.text('No purchase yet.'), findsOneWidget);
  });

  testWidgets('a failed save keeps the form; the retry reuses the request id; '
      'changed entries mint a new one', (tester) async {
    final repo = _FlakyRepository();
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: true), [
        purchaseRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('purchase-gross')), '120');
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    // refused: the dialog and its entry are still there
    expect(find.byKey(const ValueKey('purchase-save')), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    expect(repo.requestIds, hasLength(2));
    expect(repo.requestIds[0], repo.requestIds[1]);
    expect(await repo.fetchPurchases('ws'), hasLength(1));
  });

  testWidgets('an invalid entry is explained and nothing is sent', (
    tester,
  ) async {
    final repo = FakePurchaseRepository();
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: true), [
        purchaseRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('purchase-gross')), '10');
    await tester.enterText(find.byKey(const ValueKey('purchase-tax')), '11');
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-invalid')), findsOneWidget);
    expect(await repo.fetchPurchases('ws'), isEmpty);
  });
}
