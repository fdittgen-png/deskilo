// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the Demo answers every analysis of the catalogue, and its figures
// are the ones its own pages list.
//
//   * The registry: in each of the five spaces, every analysis id of the
//     catalogue reads an answer (a figure, or a figure the rule says is
//     unknown) unless it is named in `demoServerOnlyAnalyses`; a new
//     analysis cannot ship with the Demo unable to show it.
//   * The pages: the active memberships are the members list's active
//     rows; the overdue receivables are the invoicing page's overdue
//     amount, per currency, less what a hold sets apart (the server keeps a
//     held invoice out of the figure, `kpi_overdue_receivables` 0536); the
//     operating costs of a month are the operating lines of the documents
//     the purchases page lists for it, per currency.
import 'package:deskilo/core/demo/data/demo_cost_kpi_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_analyses.dart';

/// The Demo's five spaces: their name and id.
const _spaces = [
  ('Pézenas', 'ws-1'),
  ('Leipzig', 'ws-2'),
  ('London', 'ws-3'),
  ('New York', 'ws-4'),
  ('the development twin', 'ws-1-dev'),
];

/// A container on the Demo looking at space [id], its overview on.
Future<(ProviderContainer, Workspace)> _open(
  DemoFixture fixture,
  String id,
) async {
  final all = fixture.workspaces.workspaces;
  final i = all.indexWhere((w) => w.id == id);
  all[i] = all[i].copyWith(
    featureFlags: {...all[i].featureFlags, 'workspaceOverview': true},
  );
  final workspace = all[i];
  final container = ProviderContainer(
    overrides: [
      ...demoOverrides(fixture),
      currentWorkspaceProvider.overrideWith((ref) async => workspace),
    ],
  );
  addTearDown(container.dispose);
  await container.read(currentWorkspaceProvider.future);
  return (container, workspace);
}

/// The month before [d], as `YYYY-MM`.
String _lastMonth(DateTime d) {
  final m = DateTime(d.year, d.month - 1);
  return yearMonth(m.year, m.month);
}

void main() {
  final fixture = DemoFixture.build();

  group('every analysis of the catalogue has a Demo answer', () {
    for (final (name, id) in _spaces) {
      test('in $name', () async {
        final (container, _) = await _open(fixture, id);
        final failed = <String, Object>{};
        for (final module in biModules) {
          if (demoServerOnlyAnalyses.contains(module.id)) continue;
          try {
            final r = await container.read(
              biModuleResultProvider(
                id,
                module.id,
                const BiQueryContext(),
              ).future,
            );
            expect(r.total.current, isA<BiMeasure>());
          } on Object catch (e) {
            failed[module.id] = e;
          }
        }
        expect(
          failed,
          isEmpty,
          reason:
              'an analysis the Demo cannot answer is either computed from '
              'its data or named in demoServerOnlyAnalyses',
        );
      });
    }
  });

  group('the figures are the ones the pages list', () {
    for (final (name, id) in _spaces) {
      test('active memberships in $name: the members list', () async {
        final (container, _) = await _open(fixture, id);
        final listed = await container.read(workspaceMembersProvider.future);
        final f = await container
            .read(overviewKpiRepositoryProvider)
            .figure(
              id,
              'people.active_memberships_current',
              fromMonth: yearMonth(
                fixture.seededAt.year,
                fixture.seededAt.month,
              ),
              toMonth: yearMonth(fixture.seededAt.year, fixture.seededAt.month),
            );
        final active = listed
            .where((m) => m.status == MemberStatus.active)
            .length;
        expect(active, greaterThan(0));
        expect(f.value, active);
      });

      test('overdue receivables in $name: the invoicing page', () async {
        final (container, workspace) = await _open(fixture, id);
        // The invoices the page lists, read as its receivables by the
        // page's own reader once the matches, reminders, transmissions,
        // declarations and holds it reads have answered.
        for (final keep in [
          container.listen(invoiceMatchesProvider, (_, _) {}),
          container.listen(invoiceRemindersProvider, (_, _) {}),
          container.listen(invoiceTransmissionsProvider, (_, _) {}),
          container.listen(eventsProvider, (_, _) {}),
          container.listen(dunningHoldsProvider, (_, _) {}),
          container.listen(myMemberProvider, (_, _) {}),
        ]) {
          addTearDown(keep.close);
        }
        await container.read(invoiceMatchesProvider.future);
        await container.read(invoiceRemindersProvider.future);
        await container.read(invoiceTransmissionsProvider.future);
        await container.read(eventsProvider.future);
        await container.read(dunningHoldsProvider.future);
        // The reader's rights decide which invoices the page lists.
        await container.read(myMemberProvider.future);
        final keep = container.listen(invoicingReaderProvider, (_, _) {});
        addTearDown(keep.close);
        final invoices = await container
            .read(invoiceQueriesProvider)
            .fetchInvoices(id);
        final receivables = container
            .read(invoicingReaderProvider)
            .read(invoices);
        final now = container.read(clockProvider).now();
        final today = DateTime(now.year, now.month, now.day);
        final owed = owedOf(receivables.where((r) => !r.onHold), today);
        final month = yearMonth(now.year, now.month);
        final f = await container
            .read(overviewKpiRepositoryProvider)
            .figure(
              id,
              'sales.overdue_receivables',
              fromMonth: month,
              toMonth: month,
            );
        final currency = workspace.currencyCode;
        final page = {
          for (final o in owed)
            o.currency: o.buckets[OwedBucket.overdue]?.minor ?? 0,
        };
        expect(
          page.keys.where((c) => c != currency && page[c]! > 0),
          isEmpty,
          reason: 'the space owes in its own currency only',
        );
        expect(f.currency, currency);
        expect(f.value, page[currency] ?? 0);
        if (const {'ws-1', 'ws-3', 'ws-4'}.contains(id)) {
          expect(f.value, greaterThan(0), reason: '$name has late invoices');
        }
      });

      test('operating costs in $name: the purchases page', () async {
        final (container, workspace) = await _open(fixture, id);
        final month = _lastMonth(fixture.seededAt);
        final repo = container.read(purchaseRepositoryProvider);
        final listed = await container.read(purchasesProvider(id).future);
        // Each listed document as the page opens it, its operating lines
        // at their cost in the space's currency; a credit note subtracts.
        final byCurrency = <String, int>{};
        for (final s in listed) {
          final d = await repo.fetchDetail(id, s.id);
          final dated = s.originalDate ?? s.receivedOn;
          if (s.state != PurchaseState.approved ||
              dated == null ||
              yearMonth(dated.year, dated.month) != month) {
            continue;
          }
          final sign = s.kind == PurchaseKind.creditNote ? -1 : 1;
          for (final l in d.lines.where(
            (l) => l.recognitionKind == 'operating',
          )) {
            byCurrency[s.currency] =
                (byCurrency[s.currency] ?? 0) +
                sign * DemoCostKpiRepository.lineCost(l);
          }
        }
        final k = await container
            .read(costKpiRepositoryProvider)
            .summary(id, fromMonth: month, toMonth: month);
        expect(k.currency, workspace.currencyCode);
        expect(byCurrency.keys.where((c) => c != k.currency), isEmpty);
        expect(k.quality, isNot(contains(KpiQuality.unavailable)));
        expect(k.operatingCostsMinor, byCurrency[k.currency] ?? 0);
        if (id == 'ws-3' || id == 'ws-4') {
          expect(
            k.operatingCostsMinor,
            greaterThan(0),
            reason: '$name classifies its bills: last month cost something',
          );
        }
      });
    }
  });
}
