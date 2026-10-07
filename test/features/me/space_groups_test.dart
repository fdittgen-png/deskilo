// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: my spaces on Me › Home sit in groups I can fold — Favorites and
// Other always there, the rest mine — can be searched and sorted, and in my
// own order a space moves only after a full second's hold.
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'me_app.dart';

double _top(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('me-space-pair-$id'))).dy;

void main() {
  group('SpacePrefs', () {
    test('a space is in Favorites, in one of my groups, or in Other', () {
      const prefs = SpacePrefs(
        favorites: {'a'},
        groups: [SpaceGroup('g1', 'Travel')],
        groupOf: {'b': 'g1', 'c': 'gone'},
      );
      expect(prefs.groupIdOf('a'), SpaceGroup.favoritesGroup);
      expect(prefs.groupIdOf('b'), 'g1');
      expect(prefs.groupIdOf('c'), SpaceGroup.otherGroup, reason: 'group gone');
      expect(prefs.groupIdOf('d'), SpaceGroup.otherGroup);
      expect(prefs.groupIds, [SpaceGroup.favoritesGroup, 'g1', SpaceGroup.otherGroup]);
    });

    test('sorting: by hand, recently used, best rated, A–Z', () {
      String name(String k) => {'a': 'Zed', 'b': 'Bob', 'c': 'Amy'}[k]!;
      const keys = ['a', 'b', 'c'];
      const base = SpacePrefs(
        order: ['c', 'a', 'b'],
        ratings: {'b': 5, 'a': 2},
        lastUsed: {'a': 30, 'c': 10},
      );
      expect(base.sorted(keys, name), ['c', 'a', 'b']);
      expect(base.copyWith(sort: SpaceSort.alphabet).sorted(keys, name), ['c', 'b', 'a']);
      expect(base.copyWith(sort: SpaceSort.rating).sorted(keys, name), ['b', 'a', 'c']);
      expect(base.copyWith(sort: SpaceSort.recent).sorted(keys, name), ['a', 'c', 'b']);
    });

    test('everything survives the store, and a bad store reads as empty', () {
      const prefs = SpacePrefs(
        order: ['x'],
        favorites: {'a'},
        ratings: {'a': 4},
        groups: [SpaceGroup('g1', 'Travel')],
        groupOf: {'b': 'g1'},
        folded: {'g1'},
        lastUsed: {'a': 5},
        sort: SpaceSort.recent,
      );
      final back = SpacePrefs.fromJson(prefs.toJson());
      expect(back.groups.single.name, 'Travel');
      expect(back.groupOf, {'b': 'g1'});
      expect(back.folded, {'g1'});
      expect(back.sort, SpaceSort.recent);
      expect(SpacePrefs.fromJson({'groups': 'x', 'sort': 'nonsense'}).sort, SpaceSort.byHand);
    });

    test('the two fixed groups cannot be shadowed by a stored one', () {
      final p = SpacePrefs.fromJson({
        'groups': [
          {'gid': 'favorites', 'name': 'Mine'},
          {'gid': 'other', 'name': 'Mine'},
          {'gid': 'g1', 'name': 'Ok'},
        ],
      });
      expect(p.groups.map((g) => g.id), ['g1']);
    });
  });

  testWidgets('groups: always two, mine can be made, filled, folded and '
      'removed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-group-favorites')), findsOneWidget);
    expect(find.byKey(const ValueKey('me-group-other')), findsOneWidget);
    expect(find.byKey(const ValueKey('me-group-menu-favorites')), findsNothing,
        reason: 'the fixed groups have no menu to delete them');

    await tester.tap(find.byKey(const ValueKey('me-spaces-add-group')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('me-group-name-field')), 'Travel');
    await tester.tap(find.byKey(const ValueKey('me-group-save')));
    await tester.pumpAndSettle();
    final stored = await const PrefsSpacePrefsStore().read();
    final id = stored.groups.single.id;
    expect(find.byKey(ValueKey('me-group-$id')), findsOneWidget);

    // Move Second Space there from its menu.
    await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('me-group-pick-$id')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
    expect(_top(tester, 'ws-2'), lessThan(_top(tester, 'ws-1')),
        reason: 'my group sits above Other');

    // Fold it: the space is hidden, the header stays with its count.
    await tester.tap(find.byKey(ValueKey('me-group-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-space-pair-ws-2')), findsNothing);
    expect(find.byKey(ValueKey('me-group-count-$id')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('me-group-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-space-pair-ws-2')), findsOneWidget);

    // Delete the group: its space falls back to Other.
    await tester.tap(find.byKey(ValueKey('me-group-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('me-group-delete-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('me-group-$id')), findsNothing);
    expect(find.byKey(const ValueKey('me-space-pair-ws-2')), findsOneWidget);
  });

  testWidgets('a heart puts a space in Favorites', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-group-empty-favorites')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-menu-space:ws-2-favorite')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-group-empty-favorites')), findsNothing);
    expect(_top(tester, 'ws-2'), lessThan(_top(tester, 'ws-1')));
  });

  testWidgets('search narrows the list, sort reorders it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    await tester.enterText(find.byKey(const ValueKey('me-spaces-search')), 'second');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-space-pair-ws-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('me-space-pair-ws-1')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('me-spaces-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-spaces-no-match')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('me-spaces-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('me-spaces-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-spaces-sort-alphabet')));
    await tester.pumpAndSettle();
    // "Second Space" sorts after the first space's name.
    final stored = await const PrefsSpacePrefsStore().read();
    expect(stored.sort, SpaceSort.alphabet);
  });

  testWidgets('a space moves after a full second of holding, not before', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    final first = find.byKey(const ValueKey('me-hold-move-0'));
    expect(first, findsOneWidget);
    final before = _top(tester, 'ws-1');

    // A short hold and a drag does nothing to the order.
    var g = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(0, 300));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(_top(tester, 'ws-1'), before);

    // Held past a second, it lifts and drops below the other.
    g = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 1100));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(_top(tester, 'ws-1'), greaterThan(_top(tester, 'ws-2')));
  });
}
