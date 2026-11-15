// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4007 — the overview page: the houses side by side for one month, each
// amount in its own currency; a house without figures named with the reason
// in words; one total per currency, an incomplete one naming the houses it
// misses, never a line across currencies; a single house said so; the month
// moves back and not past this one.
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/domain/organisation_overview.dart';
import 'package:deskilo/features/workspace/presentation/screens/organisation_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _org = 'org-1';

OverviewHouse _house(
  String id,
  String name,
  String country,
  String currency, {
  bool head = false,
  int? invoiced,
  OverviewWithheld? withheld,
}) => OverviewHouse(
  workspaceId: id,
  name: name,
  countryCode: country,
  currencyCode: currency,
  isHead: head,
  invoiced: invoiced == null ? null : HouseFigure(minor: invoiced),
  collected: invoiced == null ? null : HouseFigure(minor: invoiced ~/ 2),
  overdue: invoiced == null
      ? null
      : HouseFigure(minor: 1000, asOf: DateTime.utc(2026, 11, 15, 9, 30)),
  withheld: withheld,
);

Future<List<String>> _pump(
  WidgetTester tester,
  List<OverviewHouse> houses, {
  Size size = const Size(1280, 900),
}) async {
  final months = <String>[];
  final repository = FakeOrganisationRepository(
    organisations: const [
      Organisation(
        id: _org,
        name: 'Atelier group',
        headWorkspaceId: 'ws-paris',
        houses: [],
      ),
    ],
    overviewOf: (organisation, month) async {
      months.add(month);
      return OrganisationOverview.ofHouses(
        organisationId: organisation,
        month: month,
        houses: houses,
      );
    },
  );
  await pumpApp(
    tester,
    const OrganisationOverviewScreen(organisationId: _org),
    size: size,
    overrides: [
      organisationRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 15))),
    ],
  );
  await tester.pumpAndSettle();
  return months;
}

void main() {
  final houses = [
    _house('ws-paris', 'Paris', 'FR', 'EUR', head: true, invoiced: 150000),
    _house('ws-zurich', 'Zurich', 'CH', 'CHF', invoiced: 90000),
    _house(
      'ws-milan',
      'Milan',
      'IT',
      'EUR',
      withheld: OverviewWithheld.notPermitted,
    ),
  ];

  testWidgets('the houses side by side, each in its currency, totals per '
      'currency and none across them', (tester) async {
    final months = await _pump(tester, houses);

    expect(months, ['2026-11'], reason: 'this month by default');
    expect(find.text('Atelier group'), findsOneWidget);
    expect(find.text('Paris (head)'), findsOneWidget);
    expect(find.textContaining('1,500.00'), findsWidgets);
    expect(find.textContaining('CHF'), findsWidgets);
    expect(find.byKey(const ValueKey('withheld-ws-milan')), findsOneWidget);
    expect(find.text("You may not read this house's finances"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('organisation-total-EUR')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('organisation-total-CHF')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('organisation-incomplete-EUR')),
      findsOneWidget,
    );
    expect(find.textContaining('Incomplete: Milan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('organisation-incomplete-CHF')),
      findsNothing,
    );
    expect(find.textContaining('as of'), findsWidgets);
  });

  testWidgets('the month moves back, never past this month', (tester) async {
    final months = await _pump(tester, houses);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('organisation-overview-next')),
    );
    expect(next.onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey('organisation-overview-previous')),
    );
    await tester.pumpAndSettle();
    expect(months.last, '2026-10');
  });

  testWidgets('one house: the page says so', (tester) async {
    await _pump(tester, [houses.first]);
    expect(
      find.byKey(const ValueKey('organisation-overview-one-house')),
      findsOneWidget,
    );
  });

  testWidgets('on a phone each house is a card with its lines', (tester) async {
    await _pump(tester, houses, size: const Size(390, 844));
    expect(find.text('Paris (head)'), findsOneWidget);
    expect(find.textContaining('Invoiced:'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text("You may not read this house's finances"),
      200,
      scrollable: find
          .ancestor(of: find.text('Zurich'), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text("You may not read this house's finances"), findsOneWidget);
  });
}
