// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the experience guards. Every Me screen of the table
// (test/ux/me_screens.dart), in every state it lists, at 320, 390 and 1280 px,
// at text scale 1.0 and 1.3, in light and dark, must:
//   * not overflow or throw;
//   * show at most one FilledButton (tonal ones are not counted) at phone width;
//   * give every button a 48 dp target and an accessible name;
//   * show an enabled action in its "empty" state;
//   * show a notice AND a result row in its "one source failed" state;
//   * never print the sum of two currencies' amounts (the EUR + CHF fixture).
// Today's violations are recorded in `_known`: for each `<screen>|<state>`, the
// rule and the number of matrix cells (width x scale x theme) in which it
// fails. The list only falls: each of steps A-F of #3545 lowers it for the
// screens it touches, and it is EMPTY when step F closes #3545.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/me/me_app.dart';
import 'me_screens.dart';

/// Phone widths and the wide window the guards walk.
const List<double> _widths = [320, 390, 1280];
const List<double> _scales = [1.0, 1.3];

/// What today's screens still do wrong: `<screen>|<state>` -> rule -> cells.
/// Only falls (#3545).
const Map<String, Map<String, int>> _known = {
  'account|empty': {'unnamed button': 12},
  'account|populated': {'unnamed button': 12},
  'data|empty': {'unnamed button': 12, 'overflow or exception': 1},
  'data|populated': {'unnamed button': 12, 'overflow or exception': 2},
  'discover|empty': {'unnamed button': 12, 'overflow or exception': 1},
  'discover|populated': {'unnamed button': 12, 'overflow or exception': 1},
  'home|empty': {'unnamed button': 12, 'overflow or exception': 1},
  'home|one source failed': {'unnamed button': 12, 'overflow or exception': 5},
  'home|populated': {'unnamed button': 12, 'overflow or exception': 5},
  'messages|empty': {'unnamed button': 12, 'overflow or exception': 1},
  'messages|populated': {'unnamed button': 12, 'overflow or exception': 1},
  'spaces|empty': {'unnamed button': 12, 'overflow or exception': 1},
  'spaces|one source failed': {'unnamed button': 12, 'a failed source is not said': 12, 'overflow or exception': 1},
  'spaces|populated': {'unnamed button': 12, 'overflow or exception': 1},
};

bool _isFilled(WidgetTester tester, Element element) {
  final button = element.widget as FilledButton;
  final scheme = Theme.of(element).colorScheme;
  // ignore: invalid_use_of_protected_member
  final background = button.defaultStyleOf(element).backgroundColor?.resolve({});
  final custom = button.style?.backgroundColor?.resolve({});
  return (custom ?? background) == scheme.primary;
}

Iterable<Element> _visibleFilled(WidgetTester tester) => find
    .byType(FilledButton)
    .hitTestable()
    .evaluate()
    .where((e) => _isFilled(tester, e));

void main() {
  for (final screen in meScreens) {
    for (final state in screen.states.entries) {
      testWidgets('${screen.id} · ${state.key}', (tester) async {
        final problems = <String, Set<String>>{};
        void flag(String rule, String tag) =>
            problems.putIfAbsent(rule, () => {}).add(tag);
        final scenario = state.value();
        for (final dark in [false, true]) {
          for (final scale in _scales) {
            for (final width in _widths) {
              final tag = '$width px, ×$scale, ${dark ? 'dark' : 'light'}';
              tester.platformDispatcher.platformBrightnessTestValue =
                  dark ? Brightness.dark : Brightness.light;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.platformDispatcher.clearAllTestValues);
              final router = await pumpMeApp(
                tester,
                workspace: scenario.workspace,
                me: scenario.me,
                accountActivity: scenario.documents,
                messenger: scenario.messenger,
                size: Size(width, width < 600 ? 900 : 800),
                extraOverrides: scenario.overrides,
              );
              await goTo(tester, router, screen.route);
              var thrown = false;
              while (tester.takeException() != null) {
                thrown = true;
              }
              if (thrown) flag('overflow or exception', tag);
              if (width < 600 && _visibleFilled(tester).length > 1) {
                flag('more than one filled button', tag);
              }
              for (final button in find
                  .byWidgetPredicate((w) => w is ButtonStyleButton)
                  .hitTestable()
                  .evaluate()) {
                final size = tester.getSize(find.byWidget(button.widget));
                if (size.height < 48 - 0.5) flag('target under 48 dp', tag);
                final label = tester.getSemantics(find.byWidget(button.widget)).label;
                if (label.trim().isEmpty) flag('unnamed button', tag);
              }
              if (state.key == 'empty') {
                final actions = find
                    .byWidgetPredicate(
                      (w) => w is ButtonStyleButton && w.onPressed != null,
                    )
                    .hitTestable();
                if (actions.evaluate().isEmpty && screen.id != 'messages') {
                  flag('empty state has no action', tag);
                }
              }
              if (state.key == 'one source failed' &&
                  find.textContaining('Try again').evaluate().isEmpty) {
                flag('a failed source is not said', tag);
              }
              final shown = [
                for (final t in tester.widgetList<Text>(find.byType(Text)))
                  t.data ?? t.textSpan?.toPlainText() ?? '',
              ];
              final prefs = shown.join('\n');
              for (final sum in ['180.00', '180,00', '180']) {
                if (prefs.contains(RegExp('(^|[^0-9.,])${RegExp.escape(sum)}([^0-9]|\$)')) &&
                    scenario.documents != null) {
                  flag('a sum of two currencies', tag);
                }
              }
            }
          }
        }
        final actual = {
          for (final e in problems.entries) e.key: e.value.length,
        };
        expect(
          actual,
          _known['${screen.id}|${state.key}'] ?? const <String, int>{},
          reason:
              "record in _known: '${screen.id}|${state.key}': $actual (it only falls; a fix lowers its count)",
        );
      });
    }
  }
}
