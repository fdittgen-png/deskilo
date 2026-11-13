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
  // #3619 — at the desk the pane lists its sections beside the one shown:
  // there is no one scroll to rewind.
  final scrolls = find.descendant(of: find.byKey(const PageStorageKey('settings-workspace')), matching: find.byType(Scrollable));
  if (scrolls.evaluate().isEmpty) return;
  tester.state<ScrollableState>(scrolls.first).position.jumpTo(0);
  await tester.pumpAndSettle();
}

/// #3619 — at the desk a settings page lists its sections beside the one
/// shown (hidden ones are offstage, so a finder skips them): [target] is
/// brought into view by choosing each listed section in turn. On a phone
/// (no list) it does nothing. True when [target] is shown.
Future<bool> revealInSettings(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) return true;
  for (final pane in ['workspace', 'personal']) {
    final list = find.byKey(ValueKey('settings-$pane-sections'));
    if (list.evaluate().isEmpty) continue;
    final entries = find.descendant(of: list, matching: find.byType(ListTile));
    for (var i = 0; i < entries.evaluate().length; i++) {
      await tester.tap(entries.at(i));
      await tester.pumpAndSettle();
      if (target.evaluate().isNotEmpty) return true;
    }
  }
  return false;
}
