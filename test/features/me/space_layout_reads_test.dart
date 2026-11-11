// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3749 — the person's own layout of their spaces (order, groups, stars) is
// read, never assumed: "never saved" is the empty layout, "could not be read"
// is a failure with Try again, and no list stands in for it.
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

class _Store implements SpacePrefsStore {
  bool fail = false;
  SpacePrefs stored = SpacePrefs.empty;
  final written = <SpacePrefs>[];

  @override
  Future<SpacePrefs> read() async {
    if (fail) throw StateError('unreadable');
    return stored;
  }

  @override
  Future<void> write(SpacePrefs prefs) async => written.add(prefs);
}

Future<void> _open(
  WidgetTester tester,
  _Store store,
  String path, {
  bool shell = true,
}) async {
  final router = await pumpMeApp(
    tester,
    workspace: twoSpaces(),
    extraOverrides: [
      personalShellEnabledProvider.overrideWithValue(shell),
      spacePrefsStoreProvider.overrideWithValue(store),
    ],
  );
  await goTo(tester, router, path);
}

void main() {
  testWidgets('never saved is an answer: my spaces show in the default order',
      (tester) async {
    await _open(tester, _Store(), '/me/spaces');
    expect(_key('my-spaces-list'), findsOneWidget);
    expect(_key('read-failure'), findsNothing);
  });

  testWidgets('a layout that cannot be read is a failure with Try again, '
      'never an unordered list as mine', (tester) async {
    final store = _Store()..fail = true;
    await _open(tester, store, '/me/spaces');
    expect(_key('read-failure'), findsOneWidget);
    expect(_key('my-spaces-list'), findsNothing);

    store.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(_key('my-spaces-list'), findsOneWidget);
    expect(store.written, isEmpty, reason: 'nothing is written from a failure');
  });

  testWidgets('the overview says my spaces are unavailable while the layout '
      'cannot be read', (tester) async {
    await _open(tester, _Store()..fail = true, '/me');
    expect(_key('me-overview-spaces-unavailable'), findsOneWidget);
  });

  testWidgets('the Me home list waits for the layout instead of grouping '
      'nothing', (tester) async {
    final store = _Store()..fail = true;
    await _open(tester, store, '/me', shell: false);
    expect(_key('read-failure'), findsOneWidget);
    expect(_key('me-space-pair-ws-1'), findsNothing);
    expect(store.written, isEmpty);
  });
}
