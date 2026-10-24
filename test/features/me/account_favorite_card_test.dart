// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — the heart of a My spaces card writes the account by the space's
// qualified reference, and shows what the account holds. Success: a
// remote space's heart is kept on the account and leads the list; clearing
// takes it off. Refusal: a reference the home will not hold is kept on this
// device only, and the person is told. Recovery: an unreachable home keeps
// it on this device; tapped again once the home answers, the account holds
// it and the device copy goes.
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/domain/account_favorite.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _away = '00000000-0000-4000-8000-0000025630ff';
const _one = '00000000-0000-4000-8000-00002554c001';
const _remote = '$_away:$_one';

PersonalWorkspaceRefs _refs({bool favorite = false}) =>
    PersonalWorkspaceRefs.fromJson({
      'home': {'installation_id': _home},
      'refs': [
        {
          'network_id': _remote,
          'hosted_here': false,
          'label': 'Atelier Nord',
          'status': 'active',
          'freshness': 'verified',
          'is_default': false,
          'is_favorite': favorite,
          'audience_fields': <String>[],
        },
      ],
    });

Future<InMemorySpacePrefsStore> _pump(
  WidgetTester tester,
  FakeMeRepository me,
) async {
  final store = InMemorySpacePrefsStore();
  final router = await pumpMeApp(
    tester,
    workspace: twoSpaces(serverDefault: null),
    me: me,
    extraOverrides: [
      personalShellEnabledProvider.overrideWithValue(true),
      spacePrefsStoreProvider.overrideWithValue(store),
    ],
  );
  await goTo(tester, router, '/me/spaces');
  return store;
}

final _heart = find.byKey(const ValueKey('my-space-favorite-ref:$_remote'));

Future<void> _tapHeart(WidgetTester tester) async {
  await tester.ensureVisible(_heart);
  await tester.pump();
  await tester.tap(_heart);
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester) =>
    tester.widget<IconButton>(_heart).isSelected ?? false;

void main() {
  testWidgets('the heart keeps a remote space on the account, and clears it',
      (tester) async {
    final me = FakeMeRepository()..workspaceRefs = _refs();
    final store = await _pump(tester, me);
    expect(_selected(tester), isFalse);

    await _tapHeart(tester);
    expect(me.accountFavorites, {_remote: true});
    expect(store.prefs.favorites, isEmpty);
    expect(_selected(tester), isTrue);
    expect(find.byType(SnackBar), findsNothing);

    await _tapHeart(tester);
    expect(me.accountFavorites, {_remote: false});
    expect(_selected(tester), isFalse);
  });

  testWidgets('a refused reference is kept on this device, and says so',
      (tester) async {
    final me = FakeMeRepository()
      ..workspaceRefs = _refs()
      ..favoriteFailure =
          const AccountFavoriteRefused(AccountFavoriteRefusal.noRelationship);
    final store = await _pump(tester, me);

    await _tapHeart(tester);
    expect(store.prefs.favorites, {'ref:$_remote'});
    expect(me.accountFavorites, isEmpty);
    expect(_selected(tester), isTrue);
    expect(
      find.text('Kept on this device only: your account cannot save this '
          'space.'),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable home keeps it here; tapped again once it '
      'answers, the account holds it', (tester) async {
    final me = FakeMeRepository()
      ..workspaceRefs = _refs()
      ..favoriteFailure = Exception('offline');
    final store = await _pump(tester, me);

    await _tapHeart(tester);
    expect(store.prefs.favorites, {'ref:$_remote'});
    expect(find.textContaining('could not be reached'), findsOneWidget);

    // Recovery: take it off here, then mark it once the home answers.
    me.favoriteFailure = null;
    await _tapHeart(tester);
    expect(store.prefs.favorites, isEmpty);
    await _tapHeart(tester);
    expect(me.accountFavorites, {_remote: true});
    expect(store.prefs.favorites, isEmpty);
    expect(_selected(tester), isTrue);
  });
}
