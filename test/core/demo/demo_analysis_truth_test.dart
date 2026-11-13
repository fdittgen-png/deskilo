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
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/room_rental.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/features/money/providers/asset_providers.dart';
import 'package:deskilo/features/money/providers/asset_valuation_providers.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/book_profile_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/room_rental_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_overview.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_analyses.dart';

/// The calendar's "due" items in London: the four quarter invoices, open
/// since they were issued, and the one other unpaid invoice (#3785).
const _londonDueItems = 5;

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
  // The space's own features, as the pages read them once it has loaded.
  container.read(enabledFeaturesSyncProvider);
  await container.read(enabledFeaturesProvider.future);
  return (container, workspace);
}

/// The month before [d], as `YYYY-MM`.
String _lastMonth(DateTime d) {
  final m = DateTime(d.year, d.month - 1);
  return yearMonth(m.year, m.month);
}

/// What the lease and rooms pages of space [id] still expect over [months]
/// months from [from]: month by month, each term in force at what its
/// listed occurrence of the month (found by its term, never by its amount)
/// still expects, or at its amount while none is listed; each room rented
/// at a fixed cost per month at what its listed occurrence of the month
/// still expects, or at its cost while none is listed.
Future<int> _stillExpected(
  ProviderContainer container,
  String id,
  DateTime from,
  int months,
) async {
  final commitments = container.read(leaseCommitmentRepositoryProvider);
  final leases = [
    for (final l in await container
        .read(premisesLeaseRepositoryProvider)
        .fetchLeases(id))
      if (l.status != LeaseStatus.draft) l,
  ];
  final rentals = (await container
          .read(roomRentalRepositoryProvider)
          .fetchOverview(id))
      .rentals;
  final listed = {
    for (final l in leases)
      l.id: (await commitments.fetchCommitments(id, l.id)).occurrences,
    for (final r in rentals)
      r.id: (await commitments.fetchCommitments(id, r.id)).occurrences,
  };
  var expected = 0;
  for (var m = 0; m < months; m++) {
    final first = DateTime(from.year, from.month + m);
    final last = DateTime(from.year, from.month + m + 1, 0);
    bool covers(DateTime start, DateTime? end) =>
        !start.isAfter(last) && (end == null || !end.isBefore(first));
    int left(Iterable<CommitmentOccurrence> listed, int amount) {
      final o = listed
          .where((o) => !o.dueOn.isBefore(first) && !o.dueOn.isAfter(last))
          .firstOrNull;
      final rest = o?.remainingCents ?? amount;
      return rest < 0 ? 0 : rest;
    }

    for (final lease in leases) {
      for (final t in lease.terms) {
        expect(t.everyMonths, 1, reason: 'the Demo terms are monthly');
        if (!covers(t.effectiveFrom, t.effectiveTo ?? lease.effectiveEnd)) {
          continue;
        }
        expected += left(
          listed[lease.id]!.where((o) => o.termId == t.id),
          t.amountCents,
        );
      }
    }
    for (final r in rentals) {
      if (r.status != RoomRentalStatus.active ||
          r.costKind != 'fixed_per_period' ||
          r.costCents <= 0 ||
          r.period != 'month' ||
          !covers(r.availableFrom, r.availableUntil)) {
        continue;
      }
      expected += left(listed[r.id]!, r.costCents);
    }
  }
  return expected;
}

/// The ids of what space [id] lists on its purchases, lease and register
/// pages.
Future<Set<String>> _recordIds(ProviderContainer container, String id) async =>
    {
      for (final p in await container.read(purchasesProvider(id).future))
        'purchase:${p.id}',
      for (final l in await container
          .read(premisesLeaseRepositoryProvider)
          .fetchLeases(id))
        'lease:${l.id}',
      for (final a in await container
          .read(workspaceAssetRepositoryProvider)
          .fetchAssets(id))
        'asset:${a.id}',
    };

void main() {
  final fixture = DemoFixture.build();

  test('Leipzig keeps its own books: a period closed there, its book profile '
      'and its accounting connection never reach the main space (#3866)', () async {
    final fix = DemoFixture.build();
    var space = fix.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1');
    final container = ProviderContainer(
      overrides: [
        ...demoOverrides(fix),
        currentWorkspaceProvider.overrideWith((ref) async => space),
      ],
    );
    addTearDown(container.dispose);
    Future<void> look(String id) async {
      space = fix.workspaces.workspaces.firstWhere((w) => w.id == id);
      container.invalidate(currentWorkspaceProvider);
      await container.read(currentWorkspaceProvider.future);
    }

    await look('ws-1');
    final mainPeriods = (await container
            .read(bookPeriodRepositoryProvider)
            .fetch('ws-1'))
        .periods
        .length;
    final mainBook = container.read(bookProfileRepositoryProvider);
    expect(
      await container
          .read(accountingConnectionRepositoryProvider)
          .fetchConnections('ws-1'),
      isNotEmpty,
      reason: 'the main space is connected',
    );

    await look('ws-2');
    final books = container.read(bookPeriodRepositoryProvider);
    expect((await books.fetch('ws-2')).periods, isEmpty);
    expect(
      await container
          .read(accountingConnectionRepositoryProvider)
          .fetchConnections('ws-2'),
      isEmpty,
    );
    final day = fix.seededAt;
    await books.close(
      'ws-2',
      DateTime(day.year - 1),
      DateTime(day.year - 1, 1, 31),
    );
    expect((await books.fetch('ws-2')).periods, hasLength(1));
    expect(
      identical(container.read(bookProfileRepositoryProvider), mainBook),
      isFalse,
      reason: "Leipzig's book profile is its own",
    );

    await look('ws-1');
    expect(
      (await container.read(bookPeriodRepositoryProvider).fetch('ws-1')).periods,
      hasLength(mainPeriods),
      reason: 'a period closed in Leipzig is not closed in the main space',
    );
  });

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

  test('London: its quarter invoices fall due in the calendar, frozen at '
      'issue (#3785)', () {
    final calendar = fixture.london.calendar..beforeRead?.call();
    final due = [
      for (final i in calendar.items)
        if (i.kind == CalendarKind.due) i,
    ];
    final quarter = [
      for (final i in fixture.london.money.invoices)
        if (i.number.startsWith('CY-')) i,
    ];
    expect(quarter, hasLength(4));
    for (final i in quarter) {
      expect(
        due.where((d) => d.id == 'cal-due-${i.id}').single.at,
        i.dueOn,
        reason: '${i.number} is due on the day frozen at its issue',
      );
    }
    // The four quarter invoices and the space's one other unpaid one.
    expect(due, hasLength(_londonDueItems));
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
        final listed = await container.read(purchasesProvider(id).future);
        // Each document the page lists, opened as the page opens it; its
        // operating lines at their net plus the tax not recovered (the
        // whole tax while the recoverable share is unknown, the gross when
        // no tax is stated), a credit note subtracting; by currency.
        final byCurrency = <String, int>{};
        for (final s in listed) {
          final key = (workspaceId: id, purchaseId: s.id);
          final keep = container.listen(purchaseDetailProvider(key), (_, _) {});
          addTearDown(keep.close);
          final d = await container.read(purchaseDetailProvider(key).future);
          final dated = s.originalDate ?? s.receivedOn;
          if (s.state != PurchaseState.approved ||
              dated == null ||
              yearMonth(dated.year, dated.month) != month) {
            continue;
          }
          for (final l in d.lines) {
            if (l.recognitionKind != 'operating') continue;
            final net = l.netCents;
            final tax = l.taxCents ?? 0;
            final cost = net == null
                ? l.grossCents
                : net + tax - (l.recoverableTaxCents ?? 0);
            byCurrency[s.currency] =
                (byCurrency[s.currency] ?? 0) +
                (s.kind == PurchaseKind.creditNote ? -cost : cost);
          }
        }
        final k = await container
            .read(costKpiRepositoryProvider)
            .summary(id, fromMonth: month, toMonth: month);
        expect(k.currency, workspace.currencyCode);
        expect(byCurrency.keys.where((c) => c != k.currency), isEmpty);
        expect(k.quality, isNot(contains(KpiQuality.unavailable)));
        expect(k.operatingCostsMinor, byCurrency[k.currency] ?? 0);
        if (id == 'ws-1' || id == 'ws-3' || id == 'ws-4') {
          expect(
            k.operatingCostsMinor,
            greaterThan(0),
            reason: '$name classifies its bills: last month cost something',
          );
        }
      });

      // #3794 — this month, and the three months before it, where every
      // occurrence of the lease and the studio is matched by its bill.
      for (final (window, back, months) in [
        ('this month', 0, 1),
        ('the three months before', 3, 3),
      ]) {
        test(
          'leases still expected in $name over $window: the lease and '
          'rooms pages',
          () async {
            final (container, _) = await _open(fixture, id);
            final now = fixture.seededAt;
            final from = DateTime(now.year, now.month - back);
            final to = DateTime(now.year, now.month - back + months - 1);
            final features = container.read(enabledFeaturesSyncProvider);
            final k = await container
                .read(costKpiRepositoryProvider)
                .summary(
                  id,
                  fromMonth: yearMonth(from.year, from.month),
                  toMonth: yearMonth(to.year, to.month),
                );
            if (!features.contains(WorkspaceFeature.premisesLease) &&
                !features.contains(WorkspaceFeature.externalRooms)) {
              // No lease or room in use here: the rule answers unknown.
              expect(k.unbilledMinor, isNull);
              return;
            }
            final expected = await _stillExpected(container, id, from, months);
            expect(k.unbilledMinor, expected);
            if (back == 0 && (id == 'ws-1' || id == 'ws-4')) {
              expect(expected, greaterThan(0), reason: '$name holds a lease');
            }
            if (back > 0 && id == 'ws-1') {
              expect(
                expected,
                0,
                reason: 'every past occurrence is matched by its bill',
              );
            }
          },
        );
      }

      test(
        'pending actions in $name: the requests and the members lists',
        () async {
          final (container, _) = await _open(fixture, id);
          final keep = container.listen(myMemberProvider, (_, _) {});
          addTearDown(keep.close);
          await container.read(myMemberProvider.future);
          final events = container.listen(eventsProvider, (_, _) {});
          addTearDown(events.close);
          final requests = await container.read(eventsProvider.future);
          final members = await container.read(workspaceMembersProvider.future);
          final listed =
              requests.where((e) => e.status == EventStatus.pending).length +
              members.where((m) => m.status == MemberStatus.pending).length;
          final month = yearMonth(
            fixture.seededAt.year,
            fixture.seededAt.month,
          );
          final f = await container
              .read(overviewKpiRepositoryProvider)
              .figure(
                id,
                'operations.pending_actions_current',
                fromMonth: month,
                toMonth: month,
              );
          expect(f.value, listed);
        },
      );
    }
  });

  group('the first business classifies what it buys (#3794)', () {
    /// The page's approved documents of [month] with their lines, as the
    /// purchases page lists and opens them.
    Future<List<PurchaseDetail>> approvedIn(
      ProviderContainer container,
      String month,
    ) async => [
      for (final s in await container.read(purchasesProvider('ws-1').future))
        if (s.state == PurchaseState.approved &&
            switch (s.originalDate ?? s.receivedOn) {
              final d? => yearMonth(d.year, d.month) == month,
              null => false,
            })
          await container
              .read(purchaseRepositoryProvider)
              .fetchDetail('ws-1', s.id),
    ];

    int cost(PurchaseLine l) => switch (l.netCents) {
      null => l.grossCents,
      final net => net + (l.taxCents ?? 0) - (l.recoverableTaxCents ?? 0),
    };

    String monthsBack(int back) {
      final m = DateTime(fixture.seededAt.year, fixture.seededAt.month - back);
      return yearMonth(m.year, m.month);
    }

    test('this month: operating costs, acquisitions and contribution are '
        'figures, each what its page lists', () async {
      final (container, _) = await _open(fixture, 'ws-1');
      final month = monthsBack(0);
      final docs = await approvedIn(container, month);
      final capitalised = {
        for (final a in await container
            .read(workspaceAssetRepositoryProvider)
            .fetchAssets('ws-1'))
          if (a.decision == AssetDecision.capitalise)
            '${a.purchaseId}#${a.lineNo}',
      };
      var operating = 0, acquisitions = 0;
      for (final d in docs) {
        expect(d.summary.currency, 'EUR', reason: 'Pézenas buys in euros');
        final sign = d.summary.kind == PurchaseKind.creditNote ? -1 : 1;
        for (final l in d.lines) {
          if (l.recognitionKind == 'operating') operating += sign * cost(l);
          if (l.recognitionKind == 'asset' &&
              capitalised.contains('${d.summary.id}#${l.lineNo}')) {
            acquisitions += sign * cost(l);
          }
        }
      }
      final k = await container
          .read(costKpiRepositoryProvider)
          .summary('ws-1', fromMonth: month, toMonth: month);
      expect(k.operatingCostsMinor, operating);
      expect(k.operatingCostsMinor, greaterThan(0));
      expect(k.acquisitionsMinor, acquisitions);
      expect(k.acquisitionsMinor, greaterThan(0));
      expect(k.contributionMinor, k.netSalesMinor! - k.operatingCostsMinor!);
      expect(k.contributionMinor, isNot(0));
      // The month under way is not closed: no confirmed book values cover
      // it, and the analysis says so.
      expect(k.bookDepreciationMinor, isNull);
      expect(k.reasons, contains('book_coverage_incomplete'));
    });

    test('last month: the depreciation is the confirmed book values of the '
        'month', () async {
      final (container, _) = await _open(fixture, 'ws-1');
      final month = monthsBack(1);
      final books = container.read(assetValuationRepositoryProvider);
      var depreciation = 0;
      for (final b in await books.fetchBatches('ws-1')) {
        if (b.status != ValuationStatus.confirmed ||
            yearMonth(b.periodFrom.year, b.periodFrom.month) != month) {
          continue;
        }
        for (final r in await books.fetchRows('ws-1', b.id)) {
          depreciation += r.depreciationMinor!;
        }
      }
      final k = await container
          .read(costKpiRepositoryProvider)
          .summary('ws-1', fromMonth: month, toMonth: month);
      expect(depreciation, greaterThan(0));
      expect(k.bookDepreciationMinor, depreciation);
      expect(k.afterDepreciationMinor, k.contributionMinor! - depreciation);
    });

    test('no cost figure is zero while the purchases page lists approved '
        'bills of the month', () async {
      final (container, _) = await _open(fixture, 'ws-1');
      for (var back = 0; back < 12; back++) {
        final month = monthsBack(back);
        final docs = await approvedIn(container, month);
        final k = await container
            .read(costKpiRepositoryProvider)
            .summary('ws-1', fromMonth: month, toMonth: month);
        if (docs.any((d) => d.lines.any((l) => l.recognitionKind == 'operating'))) {
          expect(k.operatingCostsMinor, isNot(0), reason: month);
        }
        expect(
          docs.expand((d) => d.lines).where(
            (l) => l.recognitionKind == 'unresolved',
          ),
          isEmpty,
          reason: 'every approved line of $month is classified',
        );
      }
    });
  });

  group('each business reads its own records (#3797)', () {
    test('no two businesses list the same purchase, lease or asset, and a '
        'read for another business finds none of them', () async {
      final ids = <String, Set<String>>{};
      for (final (_, id) in _spaces) {
        final (container, _) = await _open(fixture, id);
        ids[id] = await _recordIds(container, id);
        final purchases = container.read(purchaseRepositoryProvider);
        for (final (_, other) in _spaces) {
          if (other == id) continue;
          expect(
            await purchases.fetchPurchases(other),
            isEmpty,
            reason: 'a read of $id\'s purchases for $other',
          );
        }
      }
      for (final (a, x) in _spaces) {
        for (final (b, y) in _spaces) {
          if (x.compareTo(y) >= 0) continue;
          expect(
            ids[x]!.intersection(ids[y]!),
            isEmpty,
            reason: '$a and $b share records',
          );
        }
      }
      expect(ids['ws-1'], isNotEmpty);
      expect(ids['ws-2'], isEmpty, reason: 'Leipzig has bought nothing yet');
    });

    test('Leipzig\'s cost analyses read its own purchases: none', () async {
      final (container, _) = await _open(fixture, 'ws-2');
      final month = yearMonth(fixture.seededAt.year, fixture.seededAt.month);
      final k = await container
          .read(costKpiRepositoryProvider)
          .summary('ws-2', fromMonth: month, toMonth: month);
      expect(k.operatingCostsMinor, 0);
      expect(k.unresolvedLines, 0);
      expect(await container.read(purchasesProvider('ws-2').future), isEmpty);
    });
  });

  test('the month is each business\'s own: at the first hour of a month in '
      'UTC, New York still answers for the month before (#3797)', () async {
    final clock = DemoFixture.build(now: DateTime.utc(2026, 6, 1, 0, 30));
    const may = '2026-05';
    Future<(CostSummaryKpi, OverviewFigure)> read(String id) async {
      final (container, _) = await _open(clock, id);
      return (
        await container
            .read(costKpiRepositoryProvider)
            .summary(id, fromMonth: may, toMonth: may),
        await container
            .read(overviewKpiRepositoryProvider)
            .figure(
              id,
              'people.active_memberships_current',
              fromMonth: may,
              toMonth: may,
            ),
      );
    }

    // 20:30 on 31 May in New York: May is not over, and it is the month the
    // current figures belong to.
    final (nyCosts, nyPeople) = await read('ws-4');
    expect(nyCosts.reasons, contains('period_not_over'));
    expect(nyPeople.quality, isNot(contains(KpiQuality.notRecorded)));
    // 02:30 on 1 June in Pézenas: May is over.
    final (homeCosts, homePeople) = await read('ws-1');
    expect(homeCosts.reasons, isNot(contains('period_not_over')));
    expect(homePeople.quality, contains(KpiQuality.notRecorded));
  });
}
