// SPDX-License-Identifier: MIT
//
// Sparkilo-style notched bottom bar with the docked Reserve button (#207):
// the tabs split around the centre gap by index halving, the raised button
// pushes the /reserve placeholder, feature gating keeps dropping tabs, and
// the bar geometry is pinned so a stray edit cannot silently reshape it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, dynamic>? featureFlags,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: featureFlags == null
            ? null
            : FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> tabLabels(WidgetTester tester) => tester
    .widgetList<ShellBarTab>(find.byType(ShellBarTab))
    .map((t) => t.destination.label)
    .toList();

/// Labels of the tabs laid out left / right of the centre Reserve button.
(List<String>, List<String>) splitAroundButton(WidgetTester tester) {
  final buttonDx = tester.getCenter(find.byTooltip('Reserve')).dx;
  final left = <String>[];
  final right = <String>[];
  for (final element in find.byType(ShellBarTab).evaluate()) {
    final tab = element.widget as ShellBarTab;
    final dx = tester.getCenter(find.byWidget(tab)).dx;
    (dx < buttonDx ? left : right).add(tab.destination.label);
  }
  return (left, right);
}

void main() {
  test('bar metrics are pinned (spec of #207, Sparkilo geometry)', () {
    expect(ShellBarMetrics.barHeight, 64);
    expect(ShellBarMetrics.rise, 24);
    expect(ShellBarMetrics.centerGap, 76);
    expect(ShellBarMetrics.buttonDiameter, 56);
    expect(ShellBarMetrics.notchMargin, 6);
    expect(ShellBarMetrics.notchRadius, 56 / 2 + 6);
  });

  testWidgets('four tabs split 2+2 around the raised Reserve button (#230)',
      (tester) async {
    await pumpApp(tester);

    expect(find.byType(ShellBottomBar), findsOneWidget);
    final (left, right) = splitAroundButton(tester);
    expect(left, ['Plan', 'Calendar']);
    expect(right, ['Members', 'Money']);
  });

  testWidgets('three visible tabs split 2+1 (index halving)', (tester) async {
    await pumpApp(tester, featureFlags: const {'moneyTab': false});

    final (left, right) = splitAroundButton(tester);
    expect(left, ['Plan', 'Calendar']);
    expect(right, ['Members']);
  });

  testWidgets('a feature-disabled workspace still hides its tab',
      (tester) async {
    await pumpApp(tester, featureFlags: const {'calendarTab': false});

    expect(tabLabels(tester), ['Plan', 'Members', 'Money']);
  });

  testWidgets(
      'the bar indicates the loaded form: on the boot hub no side tab is '
      'highlighted and the centre button reads selected; switching to Plan '
      'flips both', (tester) async {
    await pumpApp(tester);

    // Boot lands on the Reserve hub: NO side tab may claim selection —
    // the centre button is the active indicator (filled seat icon).
    expect(
      tester
          .widgetList<ShellBarTab>(find.byType(ShellBarTab))
          .where((t) => t.selected),
      isEmpty,
    );
    expect(find.byIcon(Icons.event_seat), findsOneWidget);
    expect(find.byIcon(Icons.event_seat_outlined), findsNothing);

    // Switching to Plan highlights Plan and demotes the centre button.
    await tester.tap(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: find.text('Plan'),
      ),
    );
    await tester.pumpAndSettle();

    final selected = tester
        .widgetList<ShellBarTab>(find.byType(ShellBarTab))
        .where((t) => t.selected)
        .toList();
    expect(selected, hasLength(1));
    expect(selected.single.destination.label, 'Plan');
    expect(find.byIcon(Icons.event_seat_outlined), findsOneWidget);
    expect(find.byIcon(Icons.event_seat), findsNothing);

    // And back: the centre button reclaims the indication.
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ShellBarTab>(find.byType(ShellBarTab))
          .where((t) => t.selected),
      isEmpty,
    );
    expect(find.byIcon(Icons.event_seat), findsOneWidget);
  });

  testWidgets('tapping Reserve opens the hub with the bar still visible',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();

    // Shell branch: the bar (and its centre button) never disappears.
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.byTooltip('Reserve'), findsOneWidget);
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Reserve'),
    );
    expect(appBarTitle, findsOneWidget);
    // The hub replaced the placeholder body (#208): assert its view switch.
    expect(find.byKey(const ValueKey('reserve-view-switch')), findsOneWidget);
  });

  testWidgets('tab tap still switches the branch through the gating map',
      (tester) async {
    await pumpApp(tester, featureFlags: const {'calendarTab': false});

    // 'Members' is at visible position 1 but branch index 2 — the tap must
    // land on the directory branch, not Calendar.
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Members'),
    );
    expect(appBarTitle, findsOneWidget);
  });
}
