// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3683 -- a screen states nothing a failed or running read does not support:
// the public-profile switch, the blocked list, the legacy Home and "Ask to
// join"; and a stored layout is never overwritten from an empty one.
import 'dart:async';

import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/directory/providers/blocks_providers.dart';
import 'package:deskilo/features/me/presentation/blocked_people_card.dart';
import 'package:deskilo/features/me/presentation/me_home_tab.dart';
import 'package:deskilo/features/me/presentation/public_profile_tile.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/me/providers/public_profile_providers.dart';
import 'package:deskilo/features/me/providers/space_prefs_provider.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  group('the blocked list', () {
    testWidgets('a failed read says so, never "you have not blocked anyone"', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: BlockedPeopleCard())),
        overrides: [
          ...standardTestOverrides(),
          myBlocksProvider(thisServerSource).overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('me-blocked-people'));
      await tester.pumpAndSettle();
      expect(find.text('You have not blocked anyone.'), findsNothing);
      expect(_key('read-failure'), findsOneWidget);
    });

    testWidgets('Unblock is off while it runs: two taps are one request', (
      tester,
    ) async {
      final gate = Completer<void>();
      final messenger = _SlowMessenger(gate)..blocked['u-ana'] = 'Ana';
      await pumpApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: BlockedPeopleCard())),
        overrides: standardTestOverrides(messenger: messenger),
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('me-blocked-people'));
      await tester.pumpAndSettle();
      await tester.tap(_key('unblock-u-ana'));
      await tester.pump();
      await tester.tap(_key('unblock-u-ana'), warnIfMissed: false);
      await tester.pump();
      expect(messenger.unblockCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(messenger.blocked, isEmpty);
    });
  });

  group('the public-profile switch', () {
    testWidgets('a failed read leaves it off and says nothing about "off"', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: PublicProfileTile())),
        overrides: [
          ...standardTestOverrides(),
          myPublicProfileProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final tile = tester.widget<SwitchListTile>(
        _key('visibility-public-profile'),
      );
      expect(tile.onChanged, isNull, reason: 'nothing to switch yet');
      expect(find.textContaining('see nothing of you'), findsNothing);
      expect(_key('read-failure'), findsOneWidget);
    });

    testWidgets('while the read runs the switch is disabled and silent', (
      tester,
    ) async {
      final never = Completer<bool>();
      await pumpApp(
        tester,
        const Scaffold(body: SingleChildScrollView(child: PublicProfileTile())),
        overrides: [
          ...standardTestOverrides(),
          myPublicProfileProvider.overrideWith((ref) => never.future),
        ],
      );
      await tester.pump();
      final tile = tester.widget<SwitchListTile>(
        _key('visibility-public-profile'),
      );
      expect(tile.onChanged, isNull);
      expect(find.textContaining('see nothing of you'), findsNothing);
    });
  });

  group('the legacy Home', () {
    testWidgets('says nothing of "no space yet" while the spaces load', (
      tester,
    ) async {
      final never = Completer<List<Workspace>>();
      await pumpApp(
        tester,
        const MeHomeTab(),
        overrides: [
          ...standardTestOverrides(),
          personalShellEnabledProvider.overrideWithValue(false),
          myWorkspacesProvider.overrideWith((ref) => never.future),
        ],
      );
      await tester.pump();
      expect(_key('me-home-empty'), findsNothing);
    });

    testWidgets('a failed read is a failure with Try again, not an empty Home', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const MeHomeTab(),
        overrides: [
          ...standardTestOverrides(),
          personalShellEnabledProvider.overrideWithValue(false),
          myWorkspacesProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(_key('me-home-empty'), findsNothing);
      expect(_key('read-failure'), findsOneWidget);
    });
  });

  group('the stored layout', () {
    test('a touch before the store was read changes what is stored', () async {
      final store = _SlowPrefsStore(
        SpacePrefs.empty.copyWith(favorites: {'ws-a'}),
      );
      final container = ProviderContainer(
        overrides: [spacePrefsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(spacePrefsProvider.notifier);
      // The first read is still running when the person taps a heart.
      final change = notifier.setFavorite('ws-b', on: true);
      store.release();
      await change;
      expect(store.written.last.favorites, {'ws-a', 'ws-b'},
          reason: 'the stored favourite is kept, not erased');
    });

    test('a failed read changes nothing and writes nothing', () async {
      final store = _SlowPrefsStore(SpacePrefs.empty, fail: true);
      final container = ProviderContainer(
        overrides: [spacePrefsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(spacePrefsProvider.notifier);
      final change = notifier.setFavorite('ws-b', on: true);
      store.release();
      await change;
      expect(store.written, isEmpty);
    });
  });
}

class _SlowMessenger extends FakeMessengerRepository {
  _SlowMessenger(this.gate);
  final Completer<void> gate;
  int unblockCalls = 0;

  @override
  Future<void> unblockAccount(String userId) async {
    unblockCalls++;
    await gate.future;
    await super.unblockAccount(userId);
  }
}

class _SlowPrefsStore implements SpacePrefsStore {
  _SlowPrefsStore(this._stored, {this.fail = false});
  final SpacePrefs _stored;
  final bool fail;
  final _gate = Completer<void>();
  final written = <SpacePrefs>[];

  void release() => _gate.complete();

  @override
  Future<SpacePrefs> read() async {
    await _gate.future;
    if (fail) throw StateError('unreadable');
    return _stored;
  }

  @override
  Future<void> write(SpacePrefs prefs) async => written.add(prefs);
}
