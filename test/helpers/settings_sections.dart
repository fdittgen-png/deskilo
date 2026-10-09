// SPDX-License-Identifier: AGPL-3.0-or-later
// Navigate the settings scopes and disclosures through their visible headers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSettingsSection(WidgetTester tester, String id, {String pane = 'personal'}) async {
  final section = find.byKey(PageStorageKey('settings-section-$id'));
  final list = find.byKey(PageStorageKey('settings-$pane'));
  final scroll = find.descendant(of: list, matching: find.byType(Scrollable)).first;
  if (section.evaluate().isEmpty) await tester.scrollUntilVisible(section, 160, scrollable: scroll);
  final header = find.descendant(of: section, matching: find.byType(ListTile)).first;
  if (!ExpansibleController.of(tester.element(header)).isExpanded) {
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }
}

Future<void> showWorkspaceSettings(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('settings-workspace-tab'));
  if (tab.evaluate().isEmpty) return;
  await tester.tap(tab);
  await tester.pumpAndSettle();
  for (final id in ['workspace', 'administration', 'governance']) {
    final section = find.byKey(PageStorageKey('settings-section-$id'));
    if (section.evaluate().isEmpty) continue;
    await openSettingsSection(tester, id, pane: 'workspace');
  }
  final scroll = find.descendant(of: find.byKey(const PageStorageKey('settings-workspace')), matching: find.byType(Scrollable)).first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
}
