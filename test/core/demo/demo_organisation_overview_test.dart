// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4007 — the Demo organisation's overview: its houses in their own
// currencies (derived from the Demo's businesses, never listed here), each
// line exactly its house's own analysis for the same month, one total per
// currency, and a persona without the finance rights reading the houses
// named without figures.
import 'package:deskilo/core/demo/data/demo_overview_kpi_repository.dart';
import 'package:deskilo/core/demo/data/finance_kpi_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_organisation_overview.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/seed/demo_organisation_seed.dart';
import 'package:deskilo/features/workspace/domain/organisation_overview.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show yearMonth;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the owner reads every house in its own currency, one total per '
      'currency', () async {
    final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
    final organisation = (await demoOrganisations(f.workspaces)).single;
    final month = yearMonth(f.seededAt.year, f.seededAt.month);
    final overview = await demoOrganisationOverview(f, organisation.id, month);

    expect(
      overview.houses.map((h) => h.currencyCode).toSet(),
      organisation.houses.map((h) => h.currencyCode).toSet(),
      reason: 'the houses and their currencies are the Demo businesses\'',
    );
    expect(overview.houses.first.isHead, isTrue);
    expect(
      overview.totals.map((t) => t.currencyCode).toList(),
      overview.houses.map((h) => h.currencyCode).toSet().toList()..sort(),
      reason: 'one total per currency, never one across them',
    );
    expect(
      overview.houses.where((h) => h.withheld == OverviewWithheld.notPermitted),
      isEmpty,
      reason:
          'the owner may read every house; a house whose analysis is off '
          'says so instead',
    );
  });

  test(
    'a house\'s line is exactly its own analysis for the same month',
    () async {
      final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
      final organisation = (await demoOrganisations(f.workspaces)).single;
      // last month: a month the Demo's houses invoiced in
      final last = DateTime(f.seededAt.year, f.seededAt.month - 1);
      final month = yearMonth(last.year, last.month);
      final overview = await demoOrganisationOverview(
        f,
        organisation.id,
        month,
      );
      final house = overview.houses.firstWhere(
        (h) => !h.isHead && (h.invoiced?.minor ?? 0) > 0,
      );
      final space = f.space(DemoSpaceKey.of(house.workspaceId));
      final own = await DemoFinanceKpiRepository(
        money: space.money,
        workspaces: space.workspaces,
        now: f.seededAt,
      ).summary(house.workspaceId, fromMonth: month, toMonth: month);
      final overdue =
          await DemoOverviewKpiRepository(
            workspaces: space.workspaces,
            events: space.events,
            money: space.money,
            now: f.seededAt,
          ).figure(
            house.workspaceId,
            'sales.overdue_receivables',
            fromMonth: month,
            toMonth: month,
          );

      expect(house.invoiced?.minor, own.invoicedMinor);
      expect(house.collected?.minor, own.collectedMinor);
      expect(house.overdue?.minor, overdue.value);
      expect(house.overdue?.isState, isTrue, reason: 'overdue is as of a time');
      expect(house.invoiced?.isState, isFalse, reason: 'invoiced is the month');
    },
  );

  test('every house\'s figures equal that house\'s own data in its own '
      'currency, and a currency\'s total is only its own houses\'', () async {
    final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
    final organisation = (await demoOrganisations(f.workspaces)).single;
    final last = DateTime(f.seededAt.year, f.seededAt.month - 1);
    final month = yearMonth(last.year, last.month);
    final overview = await demoOrganisationOverview(f, organisation.id, month);
    expect(overview.houses.length, organisation.houses.length);

    final owned = <String, ({int invoiced, int collected})>{};
    for (final house in overview.houses) {
      final key = DemoSpaceKey.of(house.workspaceId);
      final space = f.space(key);
      expect(house.currencyCode, key.currency, reason: house.workspaceId);
      if (house.withheld != null) {
        expect(house.invoiced, isNull, reason: '${house.name} says why');
        continue;
      }
      final own = await DemoFinanceKpiRepository(
        money: space.money,
        workspaces: space.workspaces,
        now: f.seededAt,
      ).summary(house.workspaceId, fromMonth: month, toMonth: month);
      final overdue = await DemoOverviewKpiRepository(
        workspaces: space.workspaces,
        events: space.events,
        money: space.money,
        now: f.seededAt,
      ).figure(
        house.workspaceId,
        'sales.overdue_receivables',
        fromMonth: month,
        toMonth: month,
      );
      expect(house.invoiced?.minor, own.invoicedMinor, reason: house.name);
      expect(house.collected?.minor, own.collectedMinor, reason: house.name);
      expect(house.overdue?.minor, overdue.value, reason: house.name);
      owned[house.workspaceId] = (
        invoiced: own.invoicedMinor ?? 0,
        collected: own.collectedMinor ?? 0,
      );
    }

    for (final total in overview.totals) {
      final inCurrency = [
        for (final h in overview.houses)
          if (h.currencyCode == total.currencyCode && h.withheld == null)
            owned[h.workspaceId]!,
      ];
      expect(
        total.houses,
        overview.houses.where((h) => h.currencyCode == total.currencyCode).length,
        reason: total.currencyCode,
      );
      expect(
        total.incomplete,
        overview.houses.any(
          (h) => h.currencyCode == total.currencyCode && h.withheld != null,
        ),
        reason: 'a total that misses a house says so',
      );
      expect(
        total.invoiced,
        inCurrency.fold<int>(0, (sum, o) => sum + o.invoiced),
        reason: '${total.currencyCode}: only its own houses are added',
      );
      expect(
        total.collected,
        inCurrency.fold<int>(0, (sum, o) => sum + o.collected),
        reason: total.currencyCode,
      );
    }
  });

  test('a person without the finance rights reads the houses named without '
      'figures', () async {
    final f = DemoFixture.build()..becomePersona(DemoPersona.member);
    final organisation = (await demoOrganisations(f.workspaces)).single;
    final month = yearMonth(f.seededAt.year, f.seededAt.month);
    final overview = await demoOrganisationOverview(f, organisation.id, month);

    expect(overview.houses, isNotEmpty);
    expect(overview.houses.map((h) => h.withheld).toSet(), {
      OverviewWithheld.notPermitted,
    });
    expect(overview.totals.every((t) => t.incomplete), isTrue);
  });
}
