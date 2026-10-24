// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — Me › My spaces under the personal shell, source-aware: every
// workspace my account names (#2563 references), each with its host and
// whether its membership is verified, matched to this server's space by its
// qualified reference. Success (enter an active space, request status),
// refusal (nothing to open on another installation or in history; a failed
// read is not "no space") and recovery (Try again); zero spaces lead to
// Join and Discover; managing this server's spaces stays one tap away.
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/me/application/personal_spaces_view.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _away = '00000000-0000-4000-8000-0000025630ff';
const _one = '00000000-0000-4000-8000-00002554c001';
const _two = '00000000-0000-4000-8000-00002554c002';

Map<String, Object?> _ref(
  String installation,
  String workspace, {
  String freshness = 'unavailable',
  String? status,
  String? label,
  bool favorite = false,
}) => {
  'network_id': '$installation:$workspace',
  'hosted_here': installation == _home,
  'label': label,
  'status': status,
  'freshness': freshness,
  'is_default': false,
  'is_favorite': favorite,
  'audience_fields': <String>[],
};

PersonalWorkspaceRefs _refs(List<Map<String, Object?>> refs) =>
    PersonalWorkspaceRefs.fromJson({
      'home': {'installation_id': _home},
      'refs': refs,
    });

/// ws-1 (production) and ws-2 (development), each stamped with its
/// qualified reference on this home.
FakeWorkspaceRepository _stamped() {
  final repo = twoSpaces(serverDefault: null);
  repo.workspaces[0] = repo.workspaces[0]
      .copyWith(networkId: '$_home:$_one', environment: 'prod');
  repo.workspaces[1] = repo.workspaces[1].copyWith(networkId: '$_home:$_two');
  return repo;
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required FakeMeRepository me,
  FakeWorkspaceRepository? workspace,
  bool shell = true,
}) =>
    pumpMeApp(
      tester,
      workspace: workspace ?? _stamped(),
      me: me,
      extraOverrides: [
        personalShellEnabledProvider.overrideWithValue(shell),
      ],
    );

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('the entries', () {
    final local = _stamped().workspaces;

    test('equal local ids on two installations stay two spaces, and only '
        'this server\'s is matched to its space', () {
      final entries = personalSpaceEntries(
        _refs([
          _ref(_home, _one, freshness: 'local', status: 'active', label: 'A'),
          _ref(_away, _one),
        ]),
        local,
      );
      expect(entries, hasLength(2));
      expect(entries.first.local?.id, 'ws-1');
      expect(entries.first.host, PersonalSpaceHost.here);
      expect(entries.last.local, isNull);
      expect(entries.last.host, PersonalSpaceHost.elsewhere);
    });

    test('the action follows the verified state, never the reference alone',
        () {
      PersonalSpaceAction of(Map<String, Object?> raw) =>
          personalSpaceEntries(_refs([raw]), local).single.action;
      expect(of(_ref(_home, _one, freshness: 'local', status: 'active')),
          PersonalSpaceAction.open);
      expect(of(_ref(_home, _one, freshness: 'local', status: 'pending')),
          PersonalSpaceAction.requestStatus);
      for (final status in ['paused', 'exited']) {
        expect(of(_ref(_home, _one, freshness: 'local', status: status)),
            PersonalSpaceAction.none);
      }
      // Active here, but not a space this server lists for me: no entry.
      expect(
          of(_ref(_home, '00000000-0000-4000-8000-00002554c0ff',
              freshness: 'local', status: 'active')),
          PersonalSpaceAction.none);
      expect(of(_ref(_away, _one)), PersonalSpaceAction.none);
      expect(of(_ref(_home, _one, freshness: 'local')),
          PersonalSpaceAction.none);
    });

    test('favourites first, the home\'s order kept, the search over the '
        'loaded names', () {
      final refs = _refs([
        _ref(_home, _one, freshness: 'local', status: 'active', label: 'Alpha'),
        _ref(_home, _two, freshness: 'local', status: 'active', label: 'Beta'),
        _ref(_away, _one, label: 'Gamma', favorite: true),
      ]);
      expect(personalSpaceEntries(refs, local).map((e) => e.ref.label),
          ['Gamma', 'Alpha', 'Beta']);
      expect(
          personalSpaceEntries(refs, local, query: ' be ')
              .map((e) => e.ref.label),
          ['Beta']);
      expect(personalSpaceEntries(refs, local, query: 'zeta'), isEmpty);
    });
  });

  group('My spaces', () {
    testWidgets('each space names its host and its verification; an active '
        'one opens, another installation\'s offers nothing to open',
        (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_home, _one, freshness: 'local', status: 'active',
              label: 'Pézenas'),
          _ref(_home, _two, freshness: 'local', status: 'active',
              label: 'Second Space'),
          _ref(_away, _one, label: 'Elsewhere'),
        ]);
      final router = await _pump(tester, me: me);
      expect(await goTo(tester, router, '/me/spaces'), '/me/spaces');
      expect(_key('my-spaces-count'), findsOneWidget);
      expect(find.text('3 spaces'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('my-space-host-$_home:$_one')).data,
        'On this server',
      );
      expect(
        tester.widget<Text>(_key('my-space-state-$_home:$_one')).data,
        'Membership verified · Active',
      );
      expect(
        tester.widget<Text>(_key('my-space-host-$_away:$_one')).data,
        'On another installation',
      );
      expect(
        tester.widget<Text>(_key('my-space-state-$_away:$_one')).data,
        'Membership not verified yet',
      );
      expect(_key('my-space-open-$_away:$_one'), findsNothing);
      // The development side says so on its action.
      expect(
        find.descendant(
          of: _key('my-space-open-$_home:$_two'),
          matching: find.text('Open test space'),
        ),
        findsOneWidget,
      );
      expect(_key('my-spaces-manage'), findsOneWidget);

      await tester.tap(_key('my-space-open-$_home:$_one'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/reserve');
      final container = ProviderScope.containerOf(
          tester.element(find.byType(ShellScreen)));
      expect(container.read(currentWorkspaceProvider).value?.id, 'ws-1');
    });

    testWidgets('a pending request shows its status, history shows no Open',
        (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_home, _one, freshness: 'local', status: 'pending',
              label: 'Asked'),
          _ref(_home, _two, freshness: 'local', status: 'exited',
              label: 'Left'),
        ]);
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/spaces');
      expect(_key('my-space-open-$_home:$_one'), findsNothing);
      expect(_key('my-space-open-$_home:$_two'), findsNothing);
      expect(_key('my-space-request-$_home:$_two'), findsNothing);
      await tester.tap(_key('my-space-request-$_home:$_one'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/applications');
    });

    testWidgets('a failed read says so, never "no space", and Try again '
        'recovers', (tester) async {
      final me = FakeMeRepository()
        ..refsFailure = Exception('refused')
        ..workspaceRefs = _refs([
          _ref(_home, _one, freshness: 'local', status: 'active',
              label: 'Pézenas'),
        ]);
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/spaces');
      expect(_key('my-spaces-unavailable'), findsOneWidget);
      expect(find.text('Your spaces could not be read.'), findsOneWidget);
      expect(_key('my-spaces-empty'), findsNothing);
      expect(_key('my-spaces-count'), findsNothing);

      me.refsFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_key('my-spaces-unavailable'), findsNothing);
      expect(_key('my-space-$_home:$_one'), findsOneWidget);
    });

    testWidgets('no space at all: Join and Discover lead, Create follows, '
        'nothing to manage', (tester) async {
      final router = await _pump(
        tester,
        me: FakeMeRepository(),
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      await goTo(tester, router, '/me/spaces');
      expect(_key('my-spaces-empty'), findsOneWidget);
      expect(find.text('No space'), findsOneWidget);
      expect(tester.widget(_key('my-spaces-join')), isA<FilledButton>());
      expect(tester.widget(_key('my-spaces-create')), isA<TextButton>());
      expect(_key('my-spaces-manage'), findsNothing);
      await tester.tap(_key('my-spaces-discover'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/me/discover');
    });

    testWidgets('the search filters the loaded spaces and says when none '
        'matches', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_home, _one, freshness: 'local', status: 'active',
              label: 'Pézenas'),
          _ref(_home, _two, freshness: 'local', status: 'active',
              label: 'Second Space'),
        ]);
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/spaces');
      await tester.enterText(_key('my-spaces-search'), 'second');
      await tester.pumpAndSettle();
      expect(_key('my-space-$_home:$_one'), findsNothing);
      expect(_key('my-space-$_home:$_two'), findsOneWidget);
      expect(find.text('2 spaces'), findsOneWidget,
          reason: 'the count is of the loaded spaces, not the matches');
      await tester.enterText(_key('my-spaces-search'), 'zeta');
      await tester.pumpAndSettle();
      expect(_key('my-spaces-no-match'), findsOneWidget);
    });

    testWidgets('managing this server\'s spaces is a page of its own; off, '
        'its address leads to the legacy screen', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_home, _one, freshness: 'local', status: 'active',
              label: 'Pézenas'),
        ]);
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/spaces');
      await tester.tap(_key('my-spaces-manage'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/me/spaces/manage');
      expect(_key('profiles-add'), findsOneWidget);
    });

    testWidgets('with the shell off, the manage address is the legacy one',
        (tester) async {
      final router = await _pump(tester, me: FakeMeRepository(), shell: false);
      expect(await goTo(tester, router, '/me/spaces/manage'), '/profiles');
      expect(_key('profiles-add'), findsOneWidget);
    });
  });

  group('Overview', () {
    testWidgets('leads to All my spaces', (tester) async {
      final router = await _pump(tester, me: FakeMeRepository());
      await goTo(tester, router, '/me');
      await tapIn(tester, 'me-home-list', _key('me-home-all-spaces'));
      expect(router.state.uri.path, '/me/spaces');
    });

    testWidgets('with no space, Join and Discover lead and Create follows',
        (tester) async {
      final router = await _pump(
        tester,
        me: FakeMeRepository(),
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      await goTo(tester, router, '/me');
      expect(_key('me-home-all-spaces'), findsNothing);
      expect(tester.widget(_key('me-home-join')), isA<FilledButton>());
      expect(tester.widget(_key('me-home-create')), isA<TextButton>());
      await tapIn(tester, 'me-home-list', _key('me-home-discover'));
      expect(router.state.uri.path, '/me/discover');
    });

    testWidgets('with the shell off, the Overview is unchanged',
        (tester) async {
      final router = await _pump(tester, me: FakeMeRepository(), shell: false);
      await goTo(tester, router, '/me');
      expect(_key('me-home-all-spaces'), findsNothing);
      expect(_key('me-home-discover'), findsNothing);
      expect(_key('me-home-join'), findsOneWidget);
    });
  });
}
