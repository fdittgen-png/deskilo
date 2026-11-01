// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3072 — the workspace configuration is ONE form with ONE Save: it asks
// before it is left with edits that were never saved (and only then), and
// its section index shows the section the reader is in.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/workspace_settings_screen.dart'
    show pumpWorkspaceSettings;
import '../../helpers/workspace_settings_groups.dart';

const _save = Key('workspaceSettingsSave');
const _dialog = ValueKey('unsaved-changes-dialog');

Future<void> _back(WidgetTester tester) async {
  unawaited(Navigator.of(tester.element(find.byKey(_save))).maybePop());
  await tester.pumpAndSettle();
}

Future<void> _typeInGroup(WidgetTester tester) async {
  await toggleWorkspaceSettingsGroup(tester, 'community');
  final field = find.byKey(const Key('workspaceSettingsWhatsappGroup'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, 'https://chat.whatsapp.com/abc');
  await tester.pump();
}

bool _selected(WidgetTester tester, String id) => tester
    .widget<TextButton>(find.byKey(ValueKey('workspace-section-$id')))
    .style!
    .backgroundColor !=
    null;

void main() {
  testWidgets('a clean configuration leaves without a question', (tester) async {
    await pumpWorkspaceSettings(tester);
    await _back(tester);
    expect(find.byKey(_dialog), findsNothing);
    expect(find.byKey(_save), findsNothing);
  });

  testWidgets('an edited configuration asks; Keep editing keeps the input, '
      'Discard leaves', (tester) async {
    await pumpWorkspaceSettings(tester, expand: false);
    await _typeInGroup(tester);
    await _back(tester);
    expect(find.byKey(_dialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unsaved-changes-keep')));
    await tester.pumpAndSettle();
    expect(find.text('https://chat.whatsapp.com/abc'), findsOneWidget);
    await _back(tester);
    await tester.tap(find.byKey(const ValueKey('unsaved-changes-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(_save), findsNothing);
  });

  testWidgets('once saved, the configuration is clean again', (tester) async {
    await pumpWorkspaceSettings(tester, expand: false);
    await _typeInGroup(tester);
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.byKey(_dialog), findsNothing);
    expect(find.byKey(_save), findsNothing);
  });

  testWidgets('the section index marks the section in view as the form '
      'scrolls', (tester) async {
    await pumpWorkspaceSettings(tester,
        expand: false, size: const Size(800, 600));
    expect(_selected(tester, 'general'), isTrue);
    expect(_selected(tester, 'danger'), isFalse);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'danger'), isTrue);
    expect(_selected(tester, 'general'), isFalse);
  });
}
