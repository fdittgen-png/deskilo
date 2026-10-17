// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the space owes for approved purchases, on the wire and on screen: the
// strict decode of a claim and of a detail, the To-pay tab (a member claim
// open and one applied to an invoice, the supplier group empty), and the
// claim in the document's detail.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
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

Map<String, Object?> _obligation(
  String id, {
  required int applied,
  Map<String, Object?>? invoice,
}) => {
  'id': id,
  'purchase_id': 'p-$id',
  'creditor_kind': 'member',
  'creditor_id': 'm1',
  'amount_cents': 5000,
  'currency': 'EUR',
  'due_on': null,
  'state': 'open',
  'hold_reason': '',
  'revision': 1,
  'paid_cents': 0,
  'mine': false,
  'allocations': <Object?>[],
  'applied_cents': applied,
  'remaining_cents': 5000 - applied,
  'applied_invoice': invoice,
};

PayableRow _row(Map<String, Object?> obligation) => PayableRow.fromJson({
  'obligation': obligation,
  'purchase': {
    'kind': 'member_receipt',
    'state': 'approved',
    'category': 'coffee',
    'original_reference': '',
    'received_on': '2026-10-17',
    'legacy': true,
  },
});

class _WithDetail extends FakePurchaseRepository {
  @override
  Future<PurchaseDetail> fetchDetail(
    String workspaceId,
    String purchaseId,
  ) async => PurchaseDetail.fromJson({
    'id': purchaseId,
    'kind': 'member_receipt',
    'state': 'approved',
    'revision': 1,
    'currency': 'EUR',
    'lines': [
      {'line_no': 1, 'description': 'Coffee', 'gross_cents': 5000},
    ],
    'sources': <Object?>[],
    'obligations': [_obligation('o1', applied: 0)],
  });
}

void main() {
  test('a claim decodes with the invoice that applied it', () {
    final o = PurchaseObligation.fromJson(
      _obligation(
        'o1',
        applied: 5000,
        invoice: {
          'id': 'i1',
          'number': 'INV-2026-0001',
          'issued_at': '2026-10-17T10:00:00+00:00',
          'total_cents': -6500,
        },
      ),
    );
    expect(o.creditorKind, CreditorKind.member);
    expect(o.remainingCents, 0);
    expect(o.appliedInvoice?.number, 'INV-2026-0001');
    expect(o.appliedInvoice?.totalCents, -6500);
  });

  test('an open claim has no invoice and keeps its amount remaining', () {
    final o = PurchaseObligation.fromJson(_obligation('o2', applied: 0));
    expect(o.appliedInvoice, isNull);
    expect(o.remainingCents, 5000);
    expect(o.state, ObligationState.open);
  });

  test('a claim without its amount is a shape error, not a zero', () {
    final broken = _obligation('o3', applied: 0)..remove('amount_cents');
    expect(
      () => PurchaseObligation.fromJson(broken),
      throwsA(isA<JsonShapeException>()),
    );
  });

  test('a detail without claims decodes to none', () {
    final d = PurchaseDetail.fromJson({
      'id': 'p1',
      'kind': 'bill',
      'state': 'draft',
      'revision': 1,
      'currency': 'EUR',
      'lines': <Object?>[],
      'sources': <Object?>[],
      'obligations': <Object?>[],
    });
    expect(d.obligations, isEmpty);
  });

  testWidgets('the To-pay tab lists open and applied claims, suppliers empty', (
    tester,
  ) async {
    final repo = FakePurchaseRepository()
      ..payables.addAll([
        _row(_obligation('o1', applied: 0)),
        _row(
          _obligation(
            'o2',
            applied: 5000,
            invoice: {
              'id': 'i1',
              'number': 'INV-7',
              'issued_at': '2026-10-17T10:00:00+00:00',
              'total_cents': -1500,
            },
          ),
        ),
      ]);
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: false), [
        purchaseRepositoryProvider.overrideWithValue(repo),
        memberLabelsProvider.overrideWithValue({'m1': 'Alex Martin'}),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payable-o1')), findsNothing);

    await tester.tap(find.text('To pay'));
    await tester.pumpAndSettle();

    expect(find.text('Owed to Alex Martin'), findsNWidgets(2));
    expect(find.textContaining('Applied to invoice INV-7'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('payables-empty-supplier')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('payables-empty-member')), findsNothing);
  });

  testWidgets('a claim opens the document and shows the reimbursement', (
    tester,
  ) async {
    final repo = _WithDetail()
      ..payables.add(_row(_obligation('o1', applied: 0)));
    await tester.pumpWidget(
      _app(const PurchasesView(workspaceId: 'ws', canCapture: false), [
        purchaseRepositoryProvider.overrideWithValue(repo),
        memberLabelsProvider.overrideWithValue({'m1': 'Alex Martin'}),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('To pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payable-o1')));
    await tester.pumpAndSettle();

    expect(find.text('Reimbursement'), findsOneWidget);
    expect(find.byKey(const ValueKey('purchase-claim-o1')), findsOneWidget);
  });
}
