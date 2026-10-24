// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 — what the personal shell keeps and what it never shows.
//
// NAV-03: a half-written message, a list's scroll position and the
// selected destination survive a destination switch and every compact ↔
// rail ↔ sidebar resize: the chrome around the branches changes, the
// branches themselves are never built again.
//
// CACHE-NAV: another account signing in never sees what the previous one
// was shown — not its inbox rows while the new account's inbox is still
// being read, not its unread count, not its open conversation or draft.
import 'dart:async';

import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _phone = Size(390, 844);
const _medium = Size(1000, 900);
const _wide = Size(1300, 900);

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, dynamic> _row(String id, String title, {String? owner}) => {
  'context_kind': MessageContextKind.account.wire,
  'context_id': id,
  'title': title,
  'peer_id': 'peer-$id',
  'last_body': 'last words of $title',
  'last_at': '2026-07-15T08:00:00Z',
  'unread': 3,
  'owner': ?owner,
};

/// The home server's messenger: an inbox read can be held back, so what
/// the shell shows WHILE a read is under way can be looked at.
class _Messenger extends FakeMessengerRepository {
  Completer<void>? hold;

  /// Every read fails while set: the server cannot be reached.
  bool down = false;

  @override
  Future<List<Map<String, dynamic>>> inbox() async {
    await hold?.future;
    if (down) throw StateError('the home server is down');
    return super.inbox();
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Messenger messenger, {
  FakeAuthRepository? auth,
  Size size = _phone,
}) => pumpMeApp(
  tester,
  workspace: FakeWorkspaceRepository(workspaces: []),
  messenger: messenger,
  auth: auth,
  size: size,
  extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Finder _inboxList() => find
    .descendant(
      of: _key('unified-inbox-list'),
      matching: find.byType(Scrollable),
    )
    .first;

String _composerText(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: _key('context-thread'),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets('NAV-03: a draft, the inbox scroll and the selected '
      'destination survive a switch and a compact/rail/sidebar resize', (
    tester,
  ) async {
    final messenger = _Messenger()
      ..inboxRows.addAll([for (var i = 0; i < 30; i++) _row('c-$i', 'P $i')]);
    final router = await _pump(tester, messenger);
    await goTo(tester, router, MeTab.messages.path);

    await tester.drag(_inboxList(), const Offset(0, -900));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(_inboxList()).position.pixels;
    expect(offset, greaterThan(0));

    // A switch and every layout class: the branch keeps its scroll.
    await _tap(tester, _key(MeTab.discover.destinationKey));
    for (final size in [_wide, _medium, _phone]) {
      await _resize(tester, size);
      expect(
        router.state.uri.path,
        MeTab.discover.path,
        reason: 'a resize never changes the destination ($size)',
      );
    }
    expect(
      tester.widget<NavigationBar>(_key('me-bar')).selectedIndex,
      MeTab.destinations.indexOf(MeTab.discover),
    );
    await _tap(tester, _key(MeTab.messages.destinationKey));
    expect(
      tester.state<ScrollableState>(_inboxList()).position.pixels,
      offset,
      reason: 'the inbox comes back where it was left',
    );

    // A half-written message in a focused conversation.
    final row = find
        .byWidgetPredicate(
          (w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('inbox-entry-c-'),
        )
        .hitTestable()
        .first;
    await _tap(tester, row);
    await tester.enterText(_key('member-note-body'), 'half written');
    await tester.pump();
    expect(_key('me-bar'), findsNothing, reason: 'a focused page');

    // Wide: the same thread beside the list; switch away and back.
    await _resize(tester, _wide);
    expect(_key('me-sidebar'), findsOneWidget);
    expect(_key('messenger-split'), findsOneWidget);
    expect(_composerText(tester), 'half written');
    await _tap(tester, _key(MeTab.home.destinationKey));
    expect(router.state.uri.path, MeTab.home.path);
    expect(
      tester.widget<ListTile>(_key(MeTab.home.destinationKey)).selected,
      isTrue,
    );
    await _resize(tester, _medium);
    expect(_key('me-rail'), findsOneWidget);
    expect(router.state.uri.path, MeTab.home.path);
    await _resize(tester, _phone);
    expect(
      tester.widget<NavigationBar>(_key('me-bar')).selectedIndex,
      MeTab.destinations.indexOf(MeTab.home),
    );

    await _tap(tester, _key(MeTab.messages.destinationKey));
    expect(router.state.uri.path, MeTab.messages.path);
    expect(_key('context-thread-back'), findsOneWidget);
    expect(_composerText(tester), 'half written');
    expect(
      _key('context-draft-session-only'),
      findsNothing,
      reason: 'the same thread, never built again from a stored draft',
    );
    await _tap(tester, _key('context-thread-back'));
    expect(
      tester.state<ScrollableState>(_inboxList()).position.pixels,
      offset,
      reason: 'under the thread the list kept its place',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('CACHE-NAV: the next account never sees the previous one\'s '
      'inbox, unread count, open conversation or draft — not even while '
      'its own inbox is being read', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final messenger = _Messenger()
      ..inboxRows.addAll([
        _row('c-ana', 'Ana', owner: 'user-1'),
        _row('c-zoe', 'Zoe', owner: 'user-2'),
      ])
      ..inboxVisible = ((r) => r['owner'] == auth.currentUserId);
    final router = await _pump(tester, messenger, auth: auth);
    await goTo(tester, router, MeTab.messages.path);
    expect(_key('inbox-entry-c-ana'), findsOneWidget);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'for Ana');
    await tester.pump();

    final hold = messenger.hold = Completer<void>();
    auth.signInAs('user-2');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      _key('inbox-entry-c-ana'),
      findsNothing,
      reason: 'the previous account\'s row is not a placeholder',
    );
    expect(find.text('Ana'), findsNothing);
    expect(find.text('for Ana'), findsNothing);
    expect(_key('context-thread'), findsNothing);
    expect(
      find.descendant(
        of: _key(MeTab.messages.destinationKey),
        matching: find.byType(Badge),
      ),
      findsNothing,
      reason: 'no unread count of the previous account',
    );

    hold.complete();
    messenger.hold = null;
    await tester.pumpAndSettle();
    expect(_key('inbox-entry-c-zoe'), findsOneWidget);
    expect(_key('inbox-entry-c-ana'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CACHE-NAV: when the next account\'s inbox cannot be read, '
      'the previous account\'s rows are not shown in its place', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedIn();
    final messenger = _Messenger()
      ..inboxRows.add(_row('c-ana', 'Ana', owner: 'user-1'))
      ..inboxVisible = ((r) => r['owner'] == auth.currentUserId);
    final router = await _pump(tester, messenger, auth: auth);
    await goTo(tester, router, MeTab.messages.path);
    expect(_key('inbox-entry-c-ana'), findsOneWidget);

    messenger.down = true;
    auth.signInAs('user-2');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'inbox-source-failed-',
            ),
      ),
      findsWidgets,
      reason: 'positive control: the failed read is what is shown',
    );
    expect(_key('inbox-entry-c-ana'), findsNothing);
    expect(find.text('Ana'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
