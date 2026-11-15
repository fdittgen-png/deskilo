// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4030 — the phone bar never cuts the page's title while a control could
// move into the overflow menu: the controls leave in a fixed order (the least
// needed first, the inbox last), the way back to Me and the menu button stay,
// and an inbox with news behind the menu marks the menu's button.
import 'package:deskilo/app/shell/shell_app_bar.dart';
import 'package:deskilo/app/shell/shell_phone_bar.dart';
import 'package:deskilo/core/ui/kit/row_menu.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

ShellBarControl _control(String id, int rank, {bool leaves = true}) =>
    ShellBarControl(
      id: id,
      rank: rank,
      button: SizedBox(key: ValueKey(id)),
      entry: leaves ? RowAction(id: id, label: id, onSelected: () {}) : null,
    );

// The bar as a member's phone holds it on most tabs: the inbox, search,
// settings and the way back to Me (the ranks of shell_app_bar.dart).
final _controls = [
  _control('search', 1),
  _control('inbox', 0),
  _control('settings', 3),
  _control('back-to-me', 2, leaves: false),
];

void main() {
  test('a wide bar holds every control', () {
    final slots = shellBarSlots(width: 600, titleWidth: 90, leading: 56);
    final fit = fitShellControls(_controls, slots: slots);
    expect(fit.overflow, isEmpty);
  });

  test('today\'s case: 320 px, "Kalender" at text 1.3 — the controls move '
      'into the menu, the inbox last, and the title is whole', () {
    // "Kalender" in titleMedium at 1.3 measures about 95 px.
    const title = 95.0;
    final slots = shellBarSlots(width: 320, titleWidth: title, leading: 56);
    final fit = fitShellControls(_controls, slots: slots);
    expect([for (final c in fit.shown) c.id], ['back-to-me']);
    expect(
      [for (final c in fit.overflow) c.id],
      ['inbox', 'search', 'settings'],
      reason: 'the menu lists them most needed first',
    );
    // What stays (the way back and the menu button) fits beside the title.
    expect(fit.shown.length + 1, lessThanOrEqualTo(slots));
  });

  test('one slot fewer: the least needed leaves first', () {
    final fit = fitShellControls(_controls, slots: 3);
    expect([for (final c in fit.shown) c.id], ['inbox', 'back-to-me']);
    expect([for (final c in fit.overflow) c.id], ['search', 'settings']);
  });

  testWidgets('news behind the menu marks its button and says so', (
    tester,
  ) async {
    final en = AppLocalizationsEn();
    for (final attention in [false, true]) {
      await pumpApp(
        tester,
        Scaffold(
          appBar: AppBar(
            actions: [
              ShellOverflow(
                entries: [
                  RowAction(id: 'inbox', label: 'Inbox', onSelected: () {}),
                ],
                attention: attention,
              ),
            ],
          ),
        ),
      );
      final mark = tester.widget<Badge>(
        find.byKey(const ValueKey('shell-overflow-mark')),
      );
      expect(mark.isLabelVisible, attention);
      final more = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold)),
      ).moreButtonTooltip;
      expect(
        find.byTooltip(attention ? en.shellOverflowNews(more) : more),
        findsOneWidget,
      );
    }
  });
}
