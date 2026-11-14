// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3943 — on the desk, a page with no control of its own does not keep the
// keyboard: Tab from it reaches the top bar and every entry of the desk's
// navigation (the first one too, whatever the navigation has scrolled) and
// comes back round; Shift+Tab the same the other way (#3946: the same stops
// in reverse). The page here is
// `/reservations/period` opened bare: "No booking in these months", not one
// control.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

/// The name of the stop that has the keyboard: the nearest key it is under.
String _stop() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null || !context.mounted) return '';
  var name = '';
  context.visitAncestorElements((e) {
    final key = e.widget.key;
    if (key is ValueKey<String>) {
      name = key.value;
      return false;
    }
    return true;
  });
  return name;
}

/// The stops [key] walks through, from where the keyboard is, until it is
/// back where it started (or [limit] presses).
Future<({List<String> stops, bool cycled})> _walk(
  WidgetTester tester,
  List<LogicalKeyboardKey> key, {
  int limit = 120,
}) async {
  final start = FocusManager.instance.primaryFocus;
  final stops = <String>[];
  for (var i = 0; i < limit; i++) {
    for (final k in key) {
      await tester.sendKeyDownEvent(k);
    }
    for (final k in key.reversed) {
      await tester.sendKeyUpEvent(k);
    }
    await tester.pump();
    if (FocusManager.instance.primaryFocus == start) {
      return (stops: stops, cycled: true);
    }
    stops.add(_stop());
  }
  return (stops: stops, cycled: false);
}

void main() {
  // The first and the last entry of the navigation (a rail below the
  // large window class) and a control of the top bar.
  const railStops = [
    'rail-back-to-me',
    'rail-drawer-settings',
    'shell-events-bell',
  ];
  const sidebarStops = [
    'drawer-back-to-me',
    'drawer-settings',
    'shell-search-button',
  ];

  for (final width in const [1024.0, 1440.0, 1920.0]) {
    final reached = width < 1200 ? railStops : sidebarStops;
    testWidgets('at ${width.toInt()} Tab and Shift+Tab leave an empty page, '
        'reach the top bar and every navigation entry, and come back', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final features = WorkspaceFeature.values.toSet();
      await pumpRoute(
        tester,
        '/reservations/period',
        size: Size(width, 900),
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in features) f.name: true},
          ),
        ),
      );

      final forward = await _walk(tester, [LogicalKeyboardKey.tab]);
      expect(forward.cycled, isTrue, reason: 'Tab comes back round');
      for (final stop in reached) {
        expect(forward.stops, contains(stop), reason: 'Tab reaches $stop');
      }

      final back = await _walk(tester, [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.tab,
      ]);
      expect(back.cycled, isTrue, reason: 'Shift+Tab comes back round');
      // #3946 — Shift+Tab walks the same stops as Tab, the other way round:
      // the top bar from its last control, then the whole navigation.
      for (final stop in reached) {
        expect(back.stops, contains(stop), reason: 'Shift+Tab reaches $stop');
      }
      expect(
        back.stops.reversed.toList(),
        forward.stops,
        reason: 'Shift+Tab is Tab in reverse',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
