// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3060 F5 — the Demo's invoice register answers like the server's
// `invoices_select` (0131): a member without viewFinances or issueInvoices
// reads only their own invoices; a finance reader reads them all.
import 'package:deskilo/core/demo/data/money/demo_invoice_queries.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/providers/money_queries_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(String id, String member) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: member,
  number: 'INV-$id',
  issuedAt: DateTime(2026, 4, 2),
  period: '2026-03',
  title: 'March',
  lines: const [],
  totalCents: 1000,
  currency: 'EUR',
  memberName: member,
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
);

void main() {
  test(
    'the adapter narrows to one member when asked, and shows all otherwise',
    () async {
      final money = FakeMoneyRepository()
        ..invoices.addAll([_invoice('a', 'm-1'), _invoice('b', 'm-2')]);
      expect((await DemoInvoiceQueries(money).fetchInvoices('ws-1')).length, 2);
      final own = await DemoInvoiceQueries(
        money,
        ownOnlyFor: () => 'm-1',
      ).fetchInvoices('ws-1');
      expect(own.map((i) => i.id), ['a']);
      final unknown = await DemoInvoiceQueries(
        money,
        ownOnlyFor: () => '',
      ).fetchInvoices('ws-1');
      expect(unknown, isEmpty, reason: 'unknown reads nothing, not everything');
    },
  );

  test('the demo wiring: a plain member reads their own invoices, a finance '
      'reader all of them', () async {
    final fixture = DemoFixture.build();
    final all = fixture.money.invoices;
    expect(
      all.map((i) => i.memberId).toSet().length,
      greaterThan(1),
      reason: 'the dataset has invoices of several members',
    );

    Future<List<Invoice>> read(Set<WorkspacePermission> rights) async {
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(fixture),
          myPermissionsProvider.overrideWithValue(rights),
        ],
      );
      addTearDown(container.dispose);
      await container.read(myMemberProvider.future);
      return container.read(invoiceQueriesProvider).fetchInvoices('ws-1');
    }

    final me = (await fixture.workspaces.fetchMyMember('ws-1'))!.id;
    final plain = await read(const {});
    expect(plain.every((i) => i.memberId == me), isTrue);
    expect(plain.length, lessThan(all.length));
    expect((await read({WorkspacePermission.viewFinances})).length, all.length);
    expect(
      (await read({WorkspacePermission.issueInvoices})).length,
      all.length,
    );
  });
}
