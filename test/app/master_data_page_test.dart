// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 -- Settings > Master data as a person uses it, at a phone (390), a
// tablet (1024) and a desk (1440): every kind of master data is a card that
// opens its own screen; a member who may not open a kind's screen sees no card
// for it; the units are listed and open with the units feature off; a count
// that cannot be read shows the read failure, never a zero.
import 'package:deskilo/app/master_data/master_data_kinds.dart';
import 'package:deskilo/app/master_data/master_data_page.dart';
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/core/navigation/routes.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/stock/providers/workspace_units_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _sizes = [Size(390, 844), Size(1024, 768), Size(1440, 900)];

const _ws = 'ws-1';

/// The page at [Routes.settingsMasterData], each kind's screen a stand-in
/// that names its address.
GoRouter _router() => GoRouter(
  initialLocation: Routes.settingsMasterData,
  routes: [
    GoRoute(
      path: Routes.settingsMasterData,
      builder: (_, _) => const MasterDataPage(),
    ),
    for (final k in MasterDataKind.values)
      GoRoute(
        path: k.route,
        builder: (_, _) => Scaffold(body: Text('opened ${k.route}')),
      ),
  ],
);

List<Override> _reads({Exception? unitsFail}) => [
  workspaceUnitListProvider(_ws).overrideWith(
    (ref) async => unitsFail == null ? builtInUnits : throw unitsFail,
  ),
  vatRatesProvider.overrideWith((ref) async => const []),
  stockItemsProvider(_ws).overrideWith((ref) async => const []),
  itemGroupListProvider(_ws).overrideWith((ref) async => const []),
  allServicesProvider.overrideWith((ref) async => const []),
  stockPlaceConfigsProvider(_ws).overrideWith((ref) async => const []),
  tillDrawerProvider(_ws).overrideWith((ref) async => const []),
  suppliersProvider(_ws).overrideWith((ref) async => const []),
  billingCustomersProvider(_ws).overrideWith((ref) async => const []),
  sitesProvider.overrideWith((ref) async => const []),
];

Future<GoRouter> _open(
  WidgetTester tester,
  Size size, {
  Set<WorkspaceFeature>? features,
  Set<WorkspacePermission>? held,
  Exception? unitsFail,
}) async {
  final router = _router();
  await pumpApp(
    tester,
    null,
    router: router,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      enabledFeaturesSyncProvider.overrideWithValue(
        features ?? WorkspaceFeature.values.toSet(),
      ),
      myPermissionsProvider.overrideWithValue(
        held ?? WorkspacePermission.values.toSet(),
      ),
      ..._reads(unitsFail: unitsFail),
    ],
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _card(MasterDataKind k) =>
    find.byKey(ValueKey('master-data-card-${k.name}'));

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('master-data-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in _sizes) {
    final w = size.width.toInt();

    testWidgets('at $w every card opens its own screen', (tester) async {
      final router = await _open(tester, size);
      for (final k in MasterDataKind.values) {
        await _reveal(tester, _card(k));
        expect(find.text(k.title(_en)), findsWidgets, reason: k.name);
        await tester.tap(_card(k));
        await tester.pumpAndSettle();
        expect(find.text('opened ${k.route}'), findsOneWidget, reason: k.name);
        router.go(Routes.settingsMasterData);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('at $w a member who may not open a kind sees no card for it', (
      tester,
    ) async {
      for (final k in MasterDataKind.values) {
        final held = WorkspacePermission.values.toSet().difference(
          routePermissions[k.route]!,
        );
        await _open(tester, size, held: held);
        expect(_card(k), findsNothing, reason: k.name);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      // a kind whose feature is off has no card either
      await _open(
        tester,
        size,
        features: WorkspaceFeature.values.toSet()
          ..remove(WorkspaceFeature.vatManagement),
      );
      expect(_card(MasterDataKind.vatRates), findsNothing);
    });

    testWidgets(
      'at $w the units are listed and open with the units feature off',
      (tester) async {
        await _open(
          tester,
          size,
          features: WorkspaceFeature.values.toSet()
            ..remove(WorkspaceFeature.unitsOfMeasure),
        );
        expect(_card(MasterDataKind.units), findsOneWidget);
        expect(
          find.text(_en.masterDataCount(builtInUnits.length)),
          findsOneWidget,
        );
        await tester.tap(_card(MasterDataKind.units));
        await tester.pumpAndSettle();
        expect(find.text('opened ${Routes.settingsUnits}'), findsOneWidget);
      },
    );

    testWidgets(
      'at $w a count that cannot be read shows the read failure, never zero',
      (tester) async {
        await _open(tester, size, unitsFail: Exception('down'));
        // the units' failure, with its own Try again; no count, not a zero
        expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('master-data-retry-units')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('master-data-count-units')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: _card(MasterDataKind.units),
            matching: find.text(_en.masterDataCount(0)),
          ),
          findsNothing,
        );
        // the card still opens its screen
        expect(_card(MasterDataKind.units), findsOneWidget);
        // the other kinds still count
        expect(
          find.byKey(const ValueKey('master-data-count-vatRates')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('the search narrows the cards by name', (tester) async {
    await _open(tester, _sizes.first);
    await tester.enterText(
      find.byKey(const ValueKey('master-data-search')),
      _en.bookRoleSuppliers.toLowerCase(),
    );
    await tester.pumpAndSettle();
    expect(_card(MasterDataKind.suppliers), findsOneWidget);
    expect(_card(MasterDataKind.units), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('master-data-search')),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('master-data-no-match')), findsOneWidget);
  });

  testWidgets('one column on a phone, three at the desk', (tester) async {
    await _open(tester, _sizes.first);
    final phone = [
      for (final k in [MasterDataKind.items, MasterDataKind.itemGroups])
        tester.getRect(_card(k)),
    ];
    expect(phone[1].top, greaterThan(phone[0].top));
    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester, _sizes.last);
    final desk = [
      for (final k in [
        MasterDataKind.items,
        MasterDataKind.itemGroups,
        MasterDataKind.services,
      ])
        tester.getRect(_card(k)),
    ];
    expect(desk.map((r) => r.top).toSet(), hasLength(1));
  });

  test('the page opens to whom one of its kinds opens: its route asks the union of theirs', () {
    expect(routePermissions[Routes.settingsMasterData], {
      for (final k in MasterDataKind.values) ...routePermissions[k.route]!,
    });
  });
}
