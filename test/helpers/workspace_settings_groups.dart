// SPDX-License-Identifier: AGPL-3.0-or-later
// Interaction helpers for the form's deliberate task disclosures.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> toggleWorkspaceSettingsGroup(WidgetTester tester, String id, {bool settle = true}) async {
  if (settle) await tester.pumpAndSettle();
  final group = find.byKey(ValueKey('workspace-group-$id'));
  final header = find.descendant(of: group, matching: find.byType(ListTile)).first;
  await tester.ensureVisible(header);
  if (settle) { await tester.pumpAndSettle(); } else { await tester.pump(kThemeAnimationDuration); }
  await tester.tap(header);
  await tester.pump();
  await tester.pump(kThemeAnimationDuration);
  if (settle) await tester.pumpAndSettle();
}

Future<void> openWorkspaceSettingsGroups(WidgetTester tester, {List<String> ids = const ['payments', 'community', 'appearance', 'membership', 'tools', 'danger']}) async {
  for (final id in ids) {
    await toggleWorkspaceSettingsGroup(tester, id, settle: false);
  }
  await tester.ensureVisible(find.byKey(const Key('workspaceSettingsCountry')));
  await tester.pump(kThemeAnimationDuration);
}

/// Picks [country] in the settings form. A country that does not offer a
/// feature that is on asks first (#2454); [confirm] answers it.
Future<void> pickWorkspaceCountry(
  WidgetTester tester,
  String country, {
  bool confirm = true,
}) async {
  await tester.tap(find.byKey(const Key('workspaceSettingsCountry')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(country).last);
  await tester.pumpAndSettle();
  final dialog = find.byKey(
    Key(confirm ? 'country-change-confirm' : 'country-change-cancel'),
  );
  if (dialog.evaluate().isNotEmpty) {
    await tester.tap(dialog);
    await tester.pumpAndSettle();
  }
}
