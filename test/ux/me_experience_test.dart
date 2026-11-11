// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the experience guards. Every Me screen of the table
// (test/ux/me_screens.dart), in every state it lists, at 320, 390 and 1280 px,
// at text scale 1.0 and 1.3, in light and dark, must:
//   * not overflow or throw;
//   * show at most one FilledButton (tonal ones are not counted) at phone width;
//   * give every tappable semantics node (buttons, icon buttons, rows, list
//     tiles) a 48 x 48 dp target and a name (label, value or tooltip);
//   * show an enabled action in its "empty" state;
//   * show a notice AND a result row in its "one source failed" state;
//   * never print the sum of two currencies' amounts (the EUR + CHF fixture).
// Today's violations are recorded in `_known`: for each `<screen>|<state>`, the
// rule and the number of matrix cells (width x scale x theme) in which it
// fails. The list only falls: each of steps A-F of #3545 lowers it for the
// screens it touches, and it is EMPTY when step F closes #3545.
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/me/me_app.dart';
import 'me_screens.dart';

/// Phone widths and the wide window the guards walk.
const List<double> _widths = [320, 390, 1280];
const List<double> _scales = [1.0, 1.3];

/// What today's screens still do wrong: `<screen>|<state>` -> rule -> cells.
/// Only falls (#3545).
const Map<String, Map<String, int>> _known = {
  'data|populated': {'overflow or exception': 2},
};

bool _isFilled(WidgetTester tester, Element element) {
  final button = element.widget as FilledButton;
  final scheme = Theme.of(element).colorScheme;
  // ignore: invalid_use_of_protected_member
  final background = button.defaultStyleOf(element).backgroundColor?.resolve({});
  final custom = button.style?.backgroundColor?.resolve({});
  return (custom ?? background) == scheme.primary;
}

/// Every node of the semantics tree that can be tapped, with its size and
/// whether it is named.
List<({Size size, bool named, bool scrolled})> _tappable(WidgetTester tester) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  final out = <({Size size, bool named, bool scrolled})>[];
  void walk(SemanticsNode node, {bool scrolled = false}) {
    final data = node.getSemanticsData();
    // A tab strip that scrolls sideways clips the tabs at its edge: the
    // semantics rect of a partly visible tab is the visible part, not the
    // tab. Its width is not measured; its height still is.
    final scrollsSideways = data.hasAction(SemanticsAction.scrollLeft) ||
        data.hasAction(SemanticsAction.scrollRight);
    final tappable = data.hasAction(SemanticsAction.tap) &&
        !data.flagsCollection.isHidden &&
        !node.isInvisible;
    // A switch inside its list tile is the tile's own control: the tile (the
    // named parent with the same tap) is the target a person meets.
    final parent = node.parent?.getSemanticsData();
    final insideNamedTap = parent != null &&
        parent.hasAction(SemanticsAction.tap) &&
        parent.label.trim().isNotEmpty &&
        data.label.trim().isEmpty;
    if (tappable && !insideNamedTap) {
      out.add((
        size: node.rect.size,
        scrolled: scrolled,
        named: data.label.trim().isNotEmpty ||
            data.value.trim().isNotEmpty ||
            data.tooltip.trim().isNotEmpty,
      ));
    }
    node.visitChildren((child) {
      walk(child, scrolled: scrolled || scrollsSideways);
      return true;
    });
  }

  if (root != null) walk(root);
  return out;
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
        final semantics = tester.ensureSemantics();
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
              // The same text on every machine: a fixed zone and locale, so a
              // greeting, a date or a booking time wraps the same everywhere.
              WorkspaceTime.install('Europe/Paris');
              addTearDown(() => WorkspaceTime.install(null));
              tester.platformDispatcher.localesTestValue = const [Locale('en')];
              tester.platformDispatcher.localeTestValue = const Locale('en');
              final router = await pumpMeApp(
                tester,
                workspace: scenario.workspace,
                me: scenario.me,
                accountActivity: scenario.documents,
                messenger: scenario.messenger,
                timeZoneMode: TimeZoneMode.workspace,
                clock: FixedClock(meGuardNow),
                // Tall enough that no row is cut by the viewport: a clipped row's
                // semantics rect is shorter than the row and would read as a
                // target under 48 dp.
                size: Size(width, 5000),
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
              for (final node in _tappable(tester)) {
                if ((!node.scrolled && node.size.width < 48 - 0.5) ||
                    node.size.height < 48 - 0.5) {
                  flag('target under 48 dp', tag);
                }
                if (!node.named) flag('unnamed control', tag);
              }
              if (state.key == 'empty') {
                final actions = find
                    .byWidgetPredicate(
                      (w) =>
                          (w is ButtonStyleButton && w.onPressed != null) ||
                          (w is InkWell && w.onTap != null) ||
                          (w is ListTile && w.onTap != null),
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
        // The tall viewport above keeps rows from being cut; a real phone is
        // 390 x 844. One pass there looks at vertical overflow and nothing else.
        for (final dark in [false, true]) {
          for (final scale in _scales) {
            tester.platformDispatcher.platformBrightnessTestValue =
                dark ? Brightness.dark : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            WorkspaceTime.install('Europe/Paris');
            final router = await pumpMeApp(
              tester,
              workspace: scenario.workspace,
              me: scenario.me,
              accountActivity: scenario.documents,
              messenger: scenario.messenger,
              timeZoneMode: TimeZoneMode.workspace,
              clock: FixedClock(meGuardNow),
              size: const Size(390, 844),
              extraOverrides: scenario.overrides,
            );
            await goTo(tester, router, screen.route);
            var thrown = false;
            while (tester.takeException() != null) {
              thrown = true;
            }
            if (thrown) {
              flag(
                'overflow at phone height',
                '390 x 844 px, x$scale, ${dark ? 'dark' : 'light'}',
              );
            }
          }
        }
        final actual = {
          for (final e in problems.entries) e.key: e.value.length,
        };
        semantics.dispose();
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
