// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C3 — My spaces as cards: one per test/production pair of this
// server (its test side inside), visible filters with Requests and visits,
// a grid of cards at least 280 wide or a list, the favourite heart and My
// review as two separate actions, Move up/down instead of a drag, my guest
// visits on the page; and the Overview's preview ordered by when each
// space was last entered, with Discover/Join as a small entry below.
// Success, refusal (nothing matches, an end that cannot move, another
// installation's space never paired with this one's) and recovery (back to
// All, the search kept across a layout switch). Every fake is set here.
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/application/personal_spaces_view.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/presentation/personal_spaces_view.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/visits/domain/guest_participation.dart';
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
  String freshness = 'local',
  String? status = 'active',
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

/// ws-1 (production) and ws-2 (development), stamped with their qualified
/// references; [paired] makes them the two sides of one pair.
FakeWorkspaceRepository _spaces({bool paired = false}) {
  final repo = twoSpaces(serverDefault: null);
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    networkId: '$_home:$_one',
    environment: 'prod',
    pairId: paired ? 'pair-1' : '',
  );
  repo.workspaces[1] = repo.workspaces[1].copyWith(
    networkId: '$_home:$_two',
    pairId: paired ? 'pair-1' : '',
  );
  return repo;
}

GuestParticipation _visit() => GuestParticipation(
  id: 'visit-1',
  workspaceId: 'w-9',
  workspaceName: 'Kraftwerk',
  status: GuestVisitStatus.requested,
  startsAt: DateTime.utc(2026, 11, 10, 8),
  endsAt: DateTime.utc(2026, 11, 10, 12),
);

Future<(GoRouter, InMemorySpacePrefsStore)> _pump(
  WidgetTester tester, {
  required PersonalWorkspaceRefs refs,
  FakeWorkspaceRepository? workspace,
  SpacePrefs prefs = SpacePrefs.empty,
  List<GuestParticipation> visits = const [],
  String to = '/me/spaces',
}) async {
  final store = InMemorySpacePrefsStore()..prefs = prefs;
  final router = await pumpMeApp(
    tester,
    workspace: workspace ?? _spaces(),
    me: FakeMeRepository()..workspaceRefs = refs,
    guestVisits: FakeGuestParticipationRepository(visits: [...visits]),
    extraOverrides: [
      personalShellEnabledProvider.overrideWithValue(true),
      spacePrefsStoreProvider.overrideWithValue(store),
    ],
  );
  await goTo(tester, router, to);
  return (router, store);
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// Taps [finder] and lets the page settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<String?> _labels(List<PersonalSpaceRow> rows) => [
  for (final r in rows) r.main.ref.label,
];

void main() {
  group('the cards', () {
    test('a pair of this server is one card, production first, its test '
        'side inside; another installation\'s equal ids stay apart', () {
      final rows = personalSpaceRows(
        _refs([
          _ref(_home, _two, label: 'Test side'),
          _ref(_home, _one, label: 'Real side'),
          _ref(_away, _one, freshness: 'unavailable', status: null),
        ]),
        _spaces(paired: true).workspaces,
      );
      expect(rows, hasLength(2));
      expect(rows.first.key, 'pair:pair-1');
      expect(rows.first.main.local?.id, 'ws-1');
      expect(rows.first.testSide?.local?.id, 'ws-2');
      expect(rows.last.key, 'ref:$_away:$_one');
      expect(rows.last.testSide, isNull);
    });

    test('the filters narrow by state; Requests and visits carries the '
        'visits; nothing matching is an empty list, not an error', () {
      final refs = _refs([
        _ref(_home, _one, label: 'Active'),
        _ref(_home, _two, status: 'pending', label: 'Asked'),
        _ref(_away, _one, status: 'exited', label: 'Left'),
      ]);
      final local = _spaces().workspaces;
      List<String?> of(PersonalSpaceFilter f, {String q = ''}) =>
          _labels(personalSpaceRows(refs, local, filter: f, query: q));
      expect(of(PersonalSpaceFilter.all), ['Active', 'Asked', 'Left']);
      expect(of(PersonalSpaceFilter.active), ['Active']);
      expect(of(PersonalSpaceFilter.requests), ['Asked']);
      expect(of(PersonalSpaceFilter.history), ['Left']);
      expect(of(PersonalSpaceFilter.active, q: 'ask'), isEmpty);
      expect(PersonalSpaceFilter.requests.showsVisits, isTrue);
      expect(PersonalSpaceFilter.history.showsVisits, isFalse);
    });

    test('favourites of this device lead, then the order moved by hand; '
        'Move up/down stays among the cards of the same rank', () {
      final refs = _refs([
        _ref(_home, _one, label: 'A'),
        _ref(_home, _two, label: 'B'),
        _ref(_away, _one, freshness: 'unavailable', status: null, label: 'C'),
      ]);
      final local = _spaces().workspaces;
      final prefs = SpacePrefs.empty.copyWith(
        favorites: {'ref:$_away:$_one'},
        order: ['space:ws-2', 'space:ws-1'],
      );
      final rows = personalSpaceRows(refs, local, prefs: prefs);
      expect(_labels(rows), ['C', 'B', 'A']);
      expect(personalSpaceMoveScope(rows, rows.first, prefs), [
        'ref:$_away:$_one',
      ]);
      expect(personalSpaceMoveScope(rows, rows.last, prefs), [
        'space:ws-2',
        'space:ws-1',
      ]);
    });

    test('the preview: favourites, then the most recently entered here', () {
      final refs = _refs([
        _ref(_home, _one, label: 'A'),
        _ref(_home, _two, label: 'B'),
        _ref(_away, _one, freshness: 'unavailable', status: null, label: 'C'),
      ]);
      final local = _spaces().workspaces;
      final recent = SpacePrefs.empty.copyWith(
        lastUsed: {'space:ws-1': 10, 'space:ws-2': 20},
      );
      expect(
        _labels(personalSpacePreview(refs, local, prefs: recent, count: 2)),
        ['B', 'A'],
      );
      expect(
        _labels(
          personalSpacePreview(
            refs,
            local,
            prefs: recent.copyWith(favorites: {'ref:$_away:$_one'}),
            count: 2,
          ),
        ),
        ['C', 'B'],
      );
    });

    test('a grid card is never narrower than 280; a phone lists them', () {
      expect(personalSpaceColumns(288), 1);
      expect(personalSpaceColumns(571), 1);
      expect(personalSpaceColumns(572), 2);
      expect(personalSpaceColumns(768), 2);
      expect(personalSpaceColumns(1000), 3);
    });
  });

  group('My spaces', () {
    testWidgets('a pair is one card with its test side inside; Open test '
        'space enters the test side', (tester) async {
      final (router, _) = await _pump(
        tester,
        workspace: _spaces(paired: true),
        refs: _refs([
          _ref(_home, _one, label: 'Pézenas'),
          _ref(_home, _two, label: 'Pézenas (test)'),
        ]),
      );
      expect(_key('my-space-$_home:$_one'), findsOneWidget);
      expect(_key('my-space-$_home:$_two'), findsNothing);
      final testSide = _key('my-space-test-$_home:$_two');
      expect(
        find.descendant(of: _key('my-space-$_home:$_one'), matching: testSide),
        findsOneWidget,
      );
      expect(
        find.descendant(of: testSide, matching: find.text('Open test space')),
        findsOneWidget,
      );
      await _tap(tester, _key('my-space-open-$_home:$_two'));
      expect(router.state.uri.path, '/reserve');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShellScreen)),
      );
      expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
    });

    testWidgets('Requests and visits shows the request and my visits; '
        'Active with none says so; All brings everything back', (tester) async {
      await _pump(
        tester,
        refs: _refs([
          _ref(_home, _one, status: 'pending', label: 'Asked'),
          _ref(_home, _two, status: 'exited', label: 'Left'),
        ]),
        visits: [_visit()],
      );
      expect(_key('me-visits'), findsOneWidget);
      await _tap(tester, _key('my-spaces-filter-requests'));
      expect(_key('my-space-$_home:$_one'), findsOneWidget);
      expect(_key('my-space-$_home:$_two'), findsNothing);
      expect(_key('me-visits'), findsOneWidget);

      await _tap(tester, _key('my-spaces-filter-active'));
      expect(_key('my-spaces-no-match'), findsOneWidget);
      expect(_key('me-visits'), findsNothing);

      await _tap(tester, _key('my-spaces-filter-all'));
      expect(_key('my-spaces-no-match'), findsNothing);
      expect(_key('my-space-$_home:$_one'), findsOneWidget);
      expect(_key('my-space-$_home:$_two'), findsOneWidget);
    });

    testWidgets('the grid puts two cards side by side, the list stacks '
        'them; the search survives the switch', (tester) async {
      await _pump(
        tester,
        refs: _refs([
          _ref(_home, _one, label: 'Pézenas'),
          _ref(_home, _two, label: 'Second Space'),
        ]),
      );
      final a = _key('my-space-$_home:$_one');
      final b = _key('my-space-$_home:$_two');
      expect(tester.getTopLeft(a).dy, tester.getTopLeft(b).dy);
      expect(tester.getSize(a).width, greaterThanOrEqualTo(280));

      await tester.enterText(_key('my-spaces-search'), 'p');
      await _tap(tester, _key('my-spaces-layout-list'));
      expect(find.text('p'), findsOneWidget, reason: 'the search is kept');
      expect(tester.getTopLeft(b).dy, greaterThan(tester.getTopLeft(a).dy));
      expect(
        tester.widget<IconButton>(_key('my-spaces-layout-list')).isSelected,
        isTrue,
      );
    });

    testWidgets('the heart and My review are two actions: the heart leads '
        'the list, the review gives stars, neither sets the other', (
      tester,
    ) async {
      final (_, store) = await _pump(
        tester,
        refs: _refs([
          _ref(_home, _one, label: 'Pézenas'),
          _ref(_home, _two, label: 'Second Space'),
        ]),
      );
      final first = _key('my-space-$_home:$_one');
      final second = _key('my-space-$_home:$_two');
      await _tap(tester, _key('my-spaces-layout-list'));
      await _tap(tester, _key('my-space-favorite-space:ws-2'));
      expect(store.prefs.favorites, {'space:ws-2'});
      expect(store.prefs.ratings, isEmpty);
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
      );

      await _tap(tester, _key('my-space-review-space:ws-1'));
      await _tap(tester, _key('my-space-review-space:ws-1-4'));
      expect(store.prefs.ratings, {'space:ws-1': 4});
      expect(store.prefs.favorites, {'space:ws-2'});
      expect(find.text('My review: 4 of 5'), findsOneWidget);
    });

    testWidgets('Move up/down reorder by hand; the first cannot move up, '
        'the last cannot move down', (tester) async {
      final (_, store) = await _pump(
        tester,
        refs: _refs([
          _ref(_home, _one, label: 'Pézenas'),
          _ref(_home, _two, label: 'Second Space'),
        ]),
      );
      IconButton button(String key) => tester.widget<IconButton>(_key(key));
      expect(button('my-space-up-space:ws-1').onPressed, isNull);
      expect(button('my-space-down-space:ws-2').onPressed, isNull);
      await _tap(tester, _key('my-space-down-space:ws-1'));
      expect(store.prefs.order, ['space:ws-2', 'space:ws-1']);
      expect(button('my-space-up-space:ws-2').onPressed, isNull);
      expect(button('my-space-up-space:ws-1').onPressed, isNotNull);
    });
  });

  group('Overview', () {
    testWidgets('the preview leads with the space entered most recently; '
        'Discover and Join are a small entry below', (tester) async {
      await _pump(
        tester,
        to: '/me',
        refs: _refs([
          _ref(_home, _one, label: 'Pézenas'),
          _ref(_home, _two, label: 'Second Space'),
          _ref(_away, _one, freshness: 'unavailable', status: null),
        ]),
        prefs: SpacePrefs.empty.copyWith(lastUsed: {'space:ws-2': 20}),
      );
      final spaces = _key('me-overview-spaces');
      final second = find.descendant(
        of: spaces,
        matching: _key('my-space-$_home:$_two'),
      );
      final first = find.descendant(
        of: spaces,
        matching: _key('my-space-$_home:$_one'),
      );
      expect(second, findsOneWidget);
      expect(first, findsOneWidget);
      expect(_key('my-space-$_away:$_one'), findsNothing);
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
      );
      expect(_key('my-space-up-space:ws-1'), findsNothing);
      final entry = _key('me-overview-discover-join');
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: find
            .descendant(
              of: _key('me-home-list'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.descendant(of: spaces, matching: _key('me-home-join')),
        findsNothing,
      );
      expect(
        find.descendant(of: entry, matching: _key('me-home-discover')),
        findsOneWidget,
      );
      expect(tester.widget(_key('me-home-join')), isA<TextButton>());
    });

    testWidgets('with no space, the ways to one lead inside My spaces and '
        'no separate entry repeats them', (tester) async {
      await _pump(
        tester,
        to: '/me',
        refs: _refs([]),
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      expect(_key('me-overview-discover-join'), findsNothing);
      expect(
        find.descendant(
          of: _key('me-overview-spaces'),
          matching: _key('me-home-join'),
        ),
        findsOneWidget,
      );
      expect(tester.widget(_key('me-home-join')), isA<FilledButton>());
    });
  });
}
