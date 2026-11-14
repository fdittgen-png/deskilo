// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3863 — a business without places (placeBooking off) meets no place
// surface: at the desk the calendar is the one it has on every window, not a
// grid of places; the Sales group offers no Guest passes (a pass is a day at
// a place, and its route refuses it); the setup guide's hours step offers no
// way on to the Availability page, which the router refuses. With places on,
// each is there as before.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/desk_calendar/desk_calendar_page.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_drawer_tiles.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

Future<GoRouter> _pump(WidgetTester tester, {required bool places}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final features = {
    for (final f in WorkspaceFeature.values)
      if (places || f != WorkspaceFeature.placeBooking) f,
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              for (final f in WorkspaceFeature.values)
                f.name: features.contains(f),
            },
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(features),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider);
}

Future<void> _visit(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Finder _group(String id) => find.byWidgetPredicate(
  (widget) => widget is DrawerGroup && widget.id == id,
);

void main() {
  for (final places in [false, true]) {
    final business = places ? 'with places' : 'without places';

    testWidgets('$business, the desk calendar is '
        '${places ? '' : 'not '}a grid of places', (tester) async {
      final router = await _pump(tester, places: places);
      await _visit(tester, router, '/calendar');
      expect(
        find.byType(DeskCalendarPage),
        places ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('$business, the Sales group '
        '${places ? 'offers' : 'does not offer'} Guest passes', (tester) async {
      final router = await _pump(tester, places: places);
      await _visit(tester, router, '/invoices');
      final sales = _group('sales');
      expect(sales, findsOneWidget);
      final title = tester.widget<DrawerGroup>(sales).title;
      final heading = find.descendant(of: sales, matching: find.text(title));
      await tester.ensureVisible(heading.first);
      await tester.tap(heading.first);
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('drawer-guest-passes')),
        places ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('$business, the hours step '
        '${places ? 'offers' : 'does not offer'} the Availability page', (
      tester,
    ) async {
      final router = await _pump(tester, places: places);
      await _visit(tester, router, '/setup/step/hours');
      expect(
        find.byKey(const ValueKey('setup-hours-open-availability')),
        places ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const ValueKey('setup-hours-failed')), findsNothing);
    });
  }
}
