// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3788 — the phone's top bar at 390, through the app, on the five tabs in
// the five languages: the page's name is painted whole on one line; the
// controls that left the bar are the overflow's entries, under the labels
// they carry as buttons; the inbox (with its count) and the account never
// leave; the overflow opens by keyboard and names its entries to a screen
// reader. Measured in the app's own font, the web build's bar (menu button).
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/events/providers/attention_providers.dart';
import 'package:deskilo/features/profile/providers/personal_appearance_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

/// The five tab pages.
const _tabs = ['/messages', '/calendar', '/directory', '/money', '/reserve'];

/// Every control the bar can hold, by its button's key: what is on the bar
/// and what is behind the overflow together are these, nothing lost.
const _leaving = [
  'reserve-scan-button',
  'shell-editor-button',
  'shell-settings-button',
];

const _count = 7;

Future<void> _open(WidgetTester tester, String path, Locale locale) async {
  final features = WorkspaceFeature.values.toSet();
  await pumpRoute(
    tester,
    path,
    size: const Size(390, 844),
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      personalLocaleProvider.overrideWithValue(locale),
      webShellProvider.overrideWithValue(true),
      workspaceAttentionProvider.overrideWithValue(
        (total: _count, updates: _count, pending: 0, money: 0),
      ),
    ],
  );
}

Finder _onBar(String key) => find.descendant(
  of: find.byType(AppBar),
  matching: find.byKey(ValueKey(key)),
);

void main() {
  setUpAll(loadRealFonts);

  for (final locale in AppLocalizations.supportedLocales) {
    for (final path in _tabs) {
      testWidgets('$path at 390 in ${locale.languageCode}: the name is '
          'whole, what left the bar is behind the overflow', (tester) async {
        await _open(tester, path, locale);
        final page = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('space-chip-page')),
            matching: find.byType(RichText),
          ),
        );
        expect(page.didExceedMaxLines, isFalse);
        // The inbox with its count and the account stay.
        expect(_onBar('shell-events-bell'), findsOneWidget);
        expect(
          find.descendant(
            of: _onBar('shell-events-bell'),
            matching: find.text('$_count'),
          ),
          findsOneWidget,
        );
        expect(_onBar('shell-back-to-me'), findsOneWidget);
        final shown = {
          for (final key in _leaving)
            if (_onBar(key).evaluate().isNotEmpty) key,
        };
        final overflow = find.byKey(const ValueKey('shell-overflow-button'));
        if (overflow.evaluate().isEmpty) {
          // Nothing left the bar: the settings door is always there.
          expect(shown, contains('shell-settings-button'));
          return;
        }
        // The overflow opens from the keyboard.
        Focus.of(
          tester.element(
            find.descendant(of: overflow, matching: find.byType(Icon)),
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final entries = {
          for (final key in _leaving)
            if (find
                .byKey(ValueKey('shell-overflow-$key'))
                .evaluate()
                .isNotEmpty)
              key,
        };
        expect(entries, isNotEmpty);
        expect(entries.intersection(shown), isEmpty);
        // Scan and the editor are Reserve's; the settings door is everywhere.
        expect(
          {...shown, ...entries},
          path == '/reserve'
              ? _leaving.toSet()
              : {'shell-settings-button'},
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a screen reader reaches each overflow entry as an action of '
      'the button, named as the button was', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, '/reserve', const Locale('de'));
    final overflow = find.byKey(const ValueKey('shell-overflow-button'));
    expect(overflow, findsOneWidget);
    final node = tester.getSemantics(
      find.ancestor(of: overflow, matching: find.byType(Semantics)).first,
    );
    final labels = <String>{
      for (final id in node.getSemanticsData().customSemanticsActionIds ?? <int>[])
        CustomSemanticsAction.getAction(id)!.label!,
    };
    // The editor's and the scanner's own words, as their buttons say them.
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));
    expect(labels, containsAll([l10n.editorOpenTooltip, l10n.spaceScanTitle]));
    await tester.tap(overflow);
    await tester.pumpAndSettle();
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    semantics.dispose();
  });
}
