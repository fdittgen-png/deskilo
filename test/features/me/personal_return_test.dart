// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 NAV-03, W entry/return — entering a space from the personal shell
// and coming back to Me returns the person to the destination they left,
// and each destination's list where they left it, although the space's
// shell replaced the personal one in between. Only for the same account:
// after an account switch Me opens on Overview with nothing of the
// previous account's place (CACHE-NAV).
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _one = '00000000-0000-4000-8000-00002552e001';
const _two = '00000000-0000-4000-8000-00002552e002';

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, Object?> _ref(String workspace, String label) => {
  'network_id': '$_home:$workspace',
  'hosted_here': true,
  'label': label,
  'status': 'active',
  'freshness': 'local',
  'is_default': false,
  'is_favorite': false,
  'audience_fields': <String>[],
};

Map<String, dynamic> _row(String id, String owner) => {
  'context_kind': MessageContextKind.account.wire,
  'context_id': id,
  'title': 'P $id',
  'peer_id': 'peer-$id',
  'last_body': 'last words of $id',
  'last_at': '2026-07-15T08:00:00Z',
  'unread': 0,
  'owner': owner,
};

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeAuthRepository auth,
  FakeMessengerRepository messenger,
) {
  final workspace = twoSpaces(serverDefault: null);
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    networkId: '$_home:$_one',
    environment: 'prod',
  );
  workspace.workspaces[1] = workspace.workspaces[1].copyWith(
    networkId: '$_home:$_two',
  );
  final me = FakeMeRepository()
    ..workspaceRefs = PersonalWorkspaceRefs.fromJson({
      'home': {'installation_id': _home},
      'refs': [_ref(_one, 'Pézenas'), _ref(_two, 'Second Space')],
    });
  return pumpMeApp(
    tester,
    workspace: workspace,
    me: me,
    auth: auth,
    messenger: messenger,
    size: const Size(390, 844),
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
}

Finder _inboxList() => find
    .descendant(
      of: _key('unified-inbox-list'),
      matching: find.byType(Scrollable),
    )
    .first;

double _inboxOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(_inboxList()).position.pixels;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the inbox, then opens ws-2 from My spaces: the space's shell
/// replaces Me.
Future<double> _leaveForSpace(WidgetTester tester, GoRouter router) async {
  await goTo(tester, router, MeTab.messages.path);
  await tester.drag(_inboxList(), const Offset(0, -900));
  await tester.pumpAndSettle();
  final offset = _inboxOffset(tester);
  expect(offset, greaterThan(0));

  await _tap(tester, _key(MeTab.spaces.destinationKey));
  expect(router.state.uri.path, MeTab.spaces.path);
  await _tap(tester, _key('my-space-open-$_home:$_two'));
  expect(router.state.uri.path, '/reserve');
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ShellScreen)),
  );
  expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
  expect(find.byType(MeShell), findsNothing);
  return offset;
}

void main() {
  testWidgets('NAV-03 W entry/return: back from a space, Me opens on the '
      'destination left and the inbox where it was scrolled', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final messenger = FakeMessengerRepository()
      ..inboxRows.addAll([for (var i = 0; i < 30; i++) _row('c-$i', 'user-1')]);
    final router = await _pump(tester, auth, messenger);
    final offset = await _leaveForSpace(tester, router);

    await _tap(tester, _key('shell-back-to-me'));
    expect(
      router.state.uri.path,
      MeTab.spaces.path,
      reason: 'the destination the space was entered from',
    );
    expect(
      tester.widget<NavigationBar>(_key('me-bar')).selectedIndex,
      MeTab.destinations.indexOf(MeTab.spaces),
    );

    await _tap(tester, _key(MeTab.messages.destinationKey));
    expect(
      _inboxOffset(tester),
      offset,
      reason: 'the inbox comes back where it was left',
    );

    // The return is spent: Me's own home is still one address away, and
    // the workspace context is the one entered.
    await goTo(tester, router, '/me');
    expect(router.state.uri.path, '/me');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('CACHE-NAV: after an account switch in the space, Me opens on '
      'Overview and nothing of the previous account\'s place', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final messenger = FakeMessengerRepository()
      ..inboxRows.addAll([
        for (var i = 0; i < 30; i++) _row('a-$i', 'user-1'),
        for (var i = 0; i < 30; i++) _row('b-$i', 'user-2'),
      ])
      ..inboxVisible = ((r) => r['owner'] == auth.currentUserId);
    final router = await _pump(tester, auth, messenger);
    await _leaveForSpace(tester, router);

    auth.signInAs('user-2');
    await tester.pumpAndSettle();
    await goTo(tester, router, '/me');
    expect(
      router.state.uri.path,
      '/me',
      reason: 'the previous account\'s destination is not resumed',
    );

    await _tap(tester, _key(MeTab.messages.destinationKey));
    expect(_key('inbox-entry-b-0'), findsOneWidget);
    expect(
      _inboxOffset(tester),
      0,
      reason: 'the previous account\'s scroll is not restored',
    );
    expect(tester.takeException(), isNull);
  });
}
