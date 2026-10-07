// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a person lays out their own spaces on Me › Home — the arrows move
// a row one place, the heart puts it first, the stars are kept — and the
// layout is what a restart reads back.
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'me_app.dart';

void main() {
  group('SpacePrefs', () {
    test('arrange: the chosen order, then the order they came in', () {
      const prefs = SpacePrefs(order: ['b', 'a']);
      expect(prefs.arrange(['a', 'b', 'c', 'd']), ['b', 'a', 'c', 'd']);
    });

    test('moved: swaps neighbours and refuses an end', () {
      const prefs = SpacePrefs();
      final shown = ['a', 'b', 'c'];
      expect(prefs.moved(shown, 'c', -1), ['a', 'c', 'b']);
      expect(prefs.moved(shown, 'a', -1), isNull);
      expect(prefs.moved(shown, 'c', 1), isNull);
    });

    test('a malformed store reads as empty and bad stars are dropped', () {
      expect(SpacePrefs.fromJson('nope').order, isEmpty);
      final prefs = SpacePrefs.fromJson({
        'ratings': {'a': 4, 'b': 9, 'c': 'x'},
      });
      expect(prefs.ratings, {'a': 4});
    });
  });

  testWidgets(
    'move, favourite and rate a space; the layout survives a restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = await pumpMeApp(tester, workspace: twoSpaces());
      await goTo(tester, router, '/me');
      double top(String key) =>
          tester.getTopLeft(find.byKey(ValueKey('me-space-pair-$key'))).dy;
      expect(top('ws-1'), lessThan(top('ws-2')));

      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2-up')));
      await tester.pumpAndSettle();
      expect(top('ws-2'), lessThan(top('ws-1')));

      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-1-rate-4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('space-rating-space:ws-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-1-favorite')));
      await tester.pumpAndSettle();
      expect(
        top('ws-1'),
        lessThan(top('ws-2')),
        reason: 'the favourite is first',
      );

      final stored = await const PrefsSpacePrefsStore().read();
      expect(stored.favorites, {'space:ws-1'});
      expect(stored.ratings, {'space:ws-1': 4});
      expect(stored.order, isNotEmpty);
    },
  );
}
