// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4007 — the Demo organisation's houses side by side, as the server gives
// them (0780): each house's figures are exactly its own analysis's, from the
// same Demo repositories its analysis page reads, for the same month; a
// house where the persona may not read the finances is named without them;
// the totals are per currency, never added across.
import 'package:deskilo/core/demo/data/demo_overview_kpi_repository.dart';
import 'package:deskilo/core/demo/data/finance_kpi_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/seed/demo_organisation_seed.dart';
import 'package:deskilo/core/text/collation.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/organisation_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';

/// The houses of [organisationId] for [month] as the persona of [fixture]
/// reads them; an organisation they are in no house of has none.
Future<OrganisationOverview> demoOrganisationOverview(
  DemoFixture fixture,
  String organisationId,
  String month,
) async {
  final organisation = (await demoOrganisations(fixture.workspaces))
      .where((o) => o.id == organisationId)
      .firstOrNull;
  final memberships = await fixture.workspaces.fetchMyMembers();
  final houses = <OverviewHouse>[];
  for (final house
      in [...?organisation?.houses]..sort(
        (a, b) => a.workspaceId == organisation?.headWorkspaceId
            ? -1
            : b.workspaceId == organisation?.headWorkspaceId
            ? 1
            : compareNames(a.name, b.name),
      )) {
    final workspace = fixture.workspaces.workspaces
        .where((w) => w.id == house.workspaceId)
        .firstOrNull;
    final member = memberships
        .where((m) => m.workspaceId == house.workspaceId)
        .firstOrNull;
    final rights = effectivePermissions(member, workspace);
    final base = (
      id: house.workspaceId,
      name: house.name,
      country: house.countryCode,
      currency: house.currencyCode,
      head: house.workspaceId == organisation?.headWorkspaceId,
    );
    if (!rights.contains(WorkspacePermission.viewFinances) ||
        !rights.contains(WorkspacePermission.viewAnalytics)) {
      houses.add(_house(base, withheld: OverviewWithheld.notPermitted));
      continue;
    }
    final features = effectiveFeatures(
      resolveEnabledFeatures(workspace?.featureFlags ?? const {}),
    );
    final space = fixture.space(DemoSpaceKey.of(house.workspaceId));
    final finance = features.contains(WorkspaceFeature.workspaceStatus)
        ? await DemoFinanceKpiRepository(
            money: space.money,
            workspaces: space.workspaces,
            now: fixture.seededAt,
          ).summary(house.workspaceId, fromMonth: month, toMonth: month)
        : null;
    final overdue = features.contains(WorkspaceFeature.workspaceOverview)
        ? await DemoOverviewKpiRepository(
            workspaces: space.workspaces,
            events: space.events,
            money: space.money,
            now: fixture.seededAt,
            timezoneOf: (_) => workspace?.timezone ?? '',
          ).figure(
            house.workspaceId,
            'sales.overdue_receivables',
            fromMonth: month,
            toMonth: month,
          )
        : null;
    if (finance == null && overdue == null) {
      houses.add(_house(base, withheld: OverviewWithheld.notEnabled));
      continue;
    }
    houses.add(
      OverviewHouse(
        workspaceId: base.id,
        name: base.name,
        countryCode: base.country,
        currencyCode: base.currency,
        isHead: base.head,
        invoiced: _minor(finance?.invoicedMinor),
        collected: _minor(finance?.collectedMinor),
        overdue: switch (overdue?.value) {
          final v? => HouseFigure(minor: v, asOf: overdue?.computedAt),
          null => null,
        },
        unavailable:
            (finance?.quality.contains(KpiQuality.unavailable) ?? false) ||
            (overdue?.quality.contains(KpiQuality.unavailable) ?? false),
      ),
    );
  }
  return OrganisationOverview.ofHouses(
    organisationId: organisationId,
    month: month,
    houses: houses,
  );
}

HouseFigure? _minor(int? minor) =>
    minor == null ? null : HouseFigure(minor: minor);

OverviewHouse _house(
  ({String id, String name, String country, String currency, bool head}) b, {
  required OverviewWithheld withheld,
}) => OverviewHouse(
  workspaceId: b.id,
  name: b.name,
  countryCode: b.country,
  currencyCode: b.currency,
  isHead: b.head,
  withheld: withheld,
);
