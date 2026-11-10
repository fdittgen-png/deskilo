// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — a business without places never meets a seat. With placeBooking
// off: no Reserve button, every place route refuses like any feature-off
// route, and the setup guide's place steps do not apply. With it on (every
// existing workspace) all of them stay.
//
// The booking flags that keep no place parent (seriesBooking, bookForOthers,
// bookingPolicies, bookingGate, workingHours — a later booking type reuses
// them) live today only on surfaces that serve place bookings: the Reserve
// hub and its sheets, and the availability screen. Those surfaces are rows of
// the table below, so the flags go with them.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Every place surface: its route and the flags whose UI it carries.
const _placeRoutes = <(String, String)>[
  (
    '/reserve',
    'the hub: seriesBooking, bookForOthers, bookingGate, '
        'bookingPolicies, every place flag of the plan',
  ),
  ('/editor', 'the floor plan editor: planDecor, planObjectDelete'),
  ('/availability', 'workingHours, bookingPolicies'),
  ('/accessories', 'accessorySupplements'),
  ('/money/guest-passes', 'guestPasses'),
];

/// The setup steps that set places up.
const _placeSteps = {'places', 'first_booking'};

Future<GoRouter> _pump(WidgetTester tester, {required bool places}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {
            'placeBooking': places,
            'accessorySupplements': true,
            'guestPasses': true,
            'invoicing': true,
          },
        ),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Future<String> _visit(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  // Some screens keep a progress indicator running: pump, do not settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return router.routeInformationProvider.value.uri.path;
}

void main() {
  for (final places in [false, true]) {
    final state = places ? 'on' : 'off';
    testWidgets('placeBooking $state: the Reserve button '
        '${places ? 'stays' : 'is gone'}', (tester) async {
      await _pump(tester, places: places);
      expect(
        find.byType(ShellCenterButton),
        places ? findsOneWidget : findsNothing,
      );
    });

    for (final (path, carries) in _placeRoutes) {
      testWidgets('placeBooking $state: $path ($carries) '
          '${places ? 'opens' : 'refuses'}', (tester) async {
        final router = await _pump(tester, places: places);
        final landed = await _visit(tester, router, path);
        if (places) {
          expect(landed, path);
        } else {
          expect(landed, isNot(path));
        }
      });
    }

    test('placeBooking $state: the setup guide '
        '${places ? 'keeps' : 'drops'} the place steps', () {
      final status = demoSetupStatus({'placeBooking': places}, ready: const {});
      final notApplicable = {
        for (final s in status.steps)
          if (s.state == SetupStepState.notApplicable) s.step,
      };
      for (final step in _placeSteps) {
        expect(notApplicable.contains(step), !places, reason: step);
      }
    });
  }
}
