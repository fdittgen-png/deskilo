// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- the Demo's Me › My businesses: the head of the reference
// organisation and its houses answer with what each is still owed, computed from
// that space's own invoices, each in its own currency; no figure is added across
// currencies, and the source carries the Demo installation and the space.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_space_routing.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/money/domain/business_payables.dart';
import 'package:deskilo/features/money/domain/business_receivables.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/business_receivables_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the head answers with what its own invoices still owe, per currency; '
      'the sources carry the Demo installation', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);

    final sources = await container.read(myBusinessReceivablesProvider.future);
    final head = sources.whereType<BusinessReceivablesAnswered>().firstWhere(
      (s) => s.workspaceId == demoFirstSpaceId,
    );
    expect(head.target.installationId, kDemoInstallationId);

    // independent of the fake: the unpaid remainder of the head's invoices
    final money = fixture.space(DemoSpaceKey.home).money;
    final expected = <String, int>{};
    for (final i in money.invoices) {
      if (i.isVoided || i.settledByInvoiceId != null || i.totalCents <= 0) continue;
      final owed = i.totalCents - (money.invoiceMatchesStore[i.id]?.paidCents ?? 0);
      if (owed > 0) expected[i.currency] = (expected[i.currency] ?? 0) + owed;
    }
    expect(expected, isNotEmpty);
    final byCurrency = {
      for (final r in head.summary.rows) r.currency: r.toCollectCents,
    };
    expect(byCurrency, expected);
    // a currency has its own row: nothing was added across them
    expect(head.summary.rows.map((r) => r.currency).toSet().length,
        head.summary.rows.length);
  });

  test('the head also answers with what it has to pay: suppliers and members '
      'apart, from the obligations its purchasing keeps', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);

    final all = await container.read(myBusinessPayablesProvider.future);
    final head = all.firstWhere((p) => p.target.workspaceId == demoFirstSpaceId);
    expect(head.suppliers, isA<PayablesAnswered<dynamic>>());
    expect(head.members, isA<PayablesAnswered<dynamic>>());

    // independent of the fake: the obligations of the head's own purchasing
    final stores = fixture.stores.at(DemoSpaceKey.home);
    final expected = <String, int>{};
    for (final row in stores.buying.purchases.payables) {
      final o = row.obligation;
      if (o.state == ObligationState.cancelled) continue;
      expected[o.currency] = (expected[o.currency] ?? 0) + o.remainingCents;
    }
    expect(expected, isNotEmpty);
    final shown = {for (final c in head.currencies) c.currency: c.totalCents};
    expect(shown, expected);
  });

  test('the rows behind the head\'s figures reach every invoice and obligation '
      'once and sum to the figures', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    final receivables = await container.read(myBusinessReceivablesProvider.future);
    final head = receivables.whereType<BusinessReceivablesAnswered>().firstWhere(
      (s) => s.workspaceId == demoFirstSpaceId,
    );
    final repo = container.read(businessReceivablesRepositoryProvider);
    for (final row in head.summary.rows) {
      final ids = <String>{};
      var sum = 0;
      ReceivablesCursor? after;
      do {
        final page = await repo.page(
          demoFirstSpaceId,
          row.currency,
          state: ReceivableState.toCollect,
          after: after,
        );
        for (final r in page.rows) {
          expect(ids.add(r.invoiceId), isTrue, reason: 'no invoice twice');
          sum += r.stillDueCents;
        }
        after = page.next;
      } while (after != null);
      expect(sum, row.toCollectCents, reason: row.currency);
    }
    final payables = container.read(businessPayablesRepositoryProvider);
    final all = await container.read(myBusinessPayablesProvider.future);
    final headPayables = all.firstWhere((p) => p.target.workspaceId == demoFirstSpaceId);
    for (final c in headPayables.currencies) {
      var sum = 0;
      final ids = <String>{};
      var after = null as ({String created, String id})?;
      do {
        final page = await payables.payablesPage(demoFirstSpaceId, c.currency, after: after);
        for (final r in page.rows) {
          expect(ids.add(r.obligation.id), isTrue);
          sum += r.obligation.remainingCents;
        }
        after = page.next;
      } while (after != null);
      expect(sum, c.totalCents, reason: c.currency);
    }
  });
}
