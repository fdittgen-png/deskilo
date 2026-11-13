// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 -- hiding and showing the bottom bar has a visible control, reached
// with a mouse or the keyboard: no button for a finger, one for a mouse.
import 'package:deskilo/app/shell/shell_bar_toggle.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mouse.dart';

class _Store implements ShellFlagStore {
  bool value = false;
  @override
  Future<bool> read() async => value;
  @override
  Future<void> write({required bool value}) async => this.value = value;
}

List<Override> _overrides(_Store store, _Store coach) => [
  shellBarHiddenStoreProvider.overrideWithValue(store),
  shellSwipeCoachStoreProvider.overrideWithValue(coach),
];

Widget _host(_Store store, _Store coach) => ProviderScope(
  overrides: _overrides(store, coach),
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: ShellBarToggle())),
  ),
);

void main() {
  testWidgets('not shown to a finger', (tester) async {
    await tester.pumpWidget(_host(_Store(), _Store()));
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a mouse hides and shows the bar; the keyboard does too', (
    tester,
  ) async {
    final store = _Store();
    await tester.pumpWidget(_host(store, _Store()));
    await connectMouse(tester);
    expect(find.byTooltip('Hide the navigation bar'), findsOneWidget);
    await click(tester, find.byType(IconButton));
    expect(store.value, isTrue);
    expect(find.byTooltip('Show the navigation bar'), findsOneWidget);
    // Keyboard: focus the button, press Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(store.value, isFalse);
  });
}
