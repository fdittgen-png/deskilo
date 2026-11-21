// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 -- the rows behind a figure of My businesses: invoices and obligations
// paged with the server's own continuation, a failure with Try again, a refusal
// said, and the amount of each row in its own currency. No row is dropped or
// repeated between pages, and a failed page is not an empty list.
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/features/money/domain/business_payables.dart';
import 'package:deskilo/features/money/domain/business_receivables.dart';
import 'package:deskilo/features/money/domain/supplier_balance.dart';
import 'package:deskilo/features/money/domain/supplier_payables_page.dart';
import 'package:deskilo/features/money/presentation/widgets/business_detail_sheet.dart';
import 'package:deskilo/features/money/providers/business_receivables_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

ReceivableInvoiceRow _row(String id, int due) => ReceivableInvoiceRow(
  invoiceId: id,
  number: 'N-$id',
  issuedAt: DateTime.utc(2026, 10),
  dueOn: null,
  memberName: 'Customer $id',
  currency: 'EUR',
  totalCents: due,
  stillDueCents: due,
  awaitingCents: 0,
  state: ReceivableState.toCollect,
);

class _Receivables implements BusinessReceivablesRepository {
  _Receivables(this._pages);

  final List<Object> _pages; // a page, or an error to throw once
  final afters = <ReceivablesCursor?>[];
  final states = <ReceivableState?>[];
  var _i = 0;

  @override
  Future<BusinessReceivables> summary(String workspaceId) => throw UnimplementedError();

  @override
  Future<ReceivablesPage> page(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) async {
    afters.add(after);
    states.add(state);
    final next = _pages[_i++];
    if (next is ReceivablesPage) return next;
    throw next as Exception;
  }
}

class _Payables implements BusinessPayablesRepository {
  _Payables(this.page);

  final SupplierPayablesPage page;
  String? kind;

  @override
  Future<List<SupplierBalance>> supplierBalances(String workspaceId) => throw UnimplementedError();

  @override
  Future<MemberReimbursements> memberReimbursements(String workspaceId) => throw UnimplementedError();

  @override
  Future<SupplierPayablesPage> payablesPage(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  }) async {
    kind = creditorKind;
    return page;
  }
}

final _target = WorkspaceTarget.local(installationId: 'inst-1', workspaceId: 'ws-a');

void main() {
  testWidgets('invoices page with the server\'s continuation, none dropped or '
      'repeated, the state asked for goes to the server', (tester) async {
    final repo = _Receivables([
      ReceivablesPage(
        rows: [_row('a', 34200), _row('b', 1000)],
        next: (issuedAt: '2026-10-01T10:00:00Z', id: 'b'),
      ),
      ReceivablesPage(rows: [_row('c', 500)], next: null),
    ]);
    await pumpApp(
      tester,
      Scaffold(
        body: BusinessDetailSheet(
          detail: ReceivablesDetail(_target, 'Studio A', 'EUR', ReceivableState.toCollect),
        ),
      ),
      overrides: [businessReceivablesRepositoryProvider.overrideWithValue(repo)],
      size: const Size(800, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('business-detail-row-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-detail-row-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-detail-row-c')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('business-detail-amount-a'))).data,
      contains('342'),
    );
    await tester.tap(find.byKey(const ValueKey('business-detail-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('business-detail-row-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-detail-more')), findsNothing);
    expect(repo.afters, [null, (issuedAt: '2026-10-01T10:00:00Z', id: 'b')]);
    expect(repo.states, [ReceivableState.toCollect, ReceivableState.toCollect]);
  });

  testWidgets('a failed page is not an empty list: it says so and tries again',
      (tester) async {
    final repo = _Receivables([
      Exception('offline'),
      ReceivablesPage(rows: [_row('a', 100)], next: null),
    ]);
    await pumpApp(
      tester,
      Scaffold(
        body: BusinessDetailSheet(detail: ReceivablesDetail(_target, 'Studio A', 'EUR', null)),
      ),
      overrides: [businessReceivablesRepositoryProvider.overrideWithValue(repo)],
      size: const Size(800, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('business-detail-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-detail-row-a')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('business-detail-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('business-detail-failed')), findsNothing);
    expect(find.byKey(const ValueKey('business-detail-row-a')), findsOneWidget);
  });

  testWidgets('a refused read is said and shows no row', (tester) async {
    final repo = _Receivables([const BusinessReceivablesRefusal()]);
    await pumpApp(
      tester,
      Scaffold(
        body: BusinessDetailSheet(detail: ReceivablesDetail(_target, 'Studio A', 'EUR', null)),
      ),
      overrides: [businessReceivablesRepositoryProvider.overrideWithValue(repo)],
      size: const Size(800, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('business-detail-refused')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-detail-rows')), findsNothing);
  });

  testWidgets('the creditor kind of a tapped payables line goes to the server',
      (tester) async {
    final repo = _Payables(const SupplierPayablesPage(rows: [], next: null));
    await pumpApp(
      tester,
      Scaffold(
        body: BusinessDetailSheet(detail: PayablesDetail(_target, 'Studio A', 'EUR', 'member')),
      ),
      overrides: [businessPayablesRepositoryProvider.overrideWithValue(repo)],
      size: const Size(800, 1200),
    );
    await tester.pumpAndSettle();
    expect(repo.kind, 'member');
    // an answered empty page is "no rows", not a failure
    expect(find.byKey(const ValueKey('business-detail-failed')), findsNothing);
    expect(find.text('No rows.'), findsOneWidget);
  });
}
