// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a member favourites a place and rates it from 0 to 5 stars; the
// bar is absent where the feature is off or the permission is not held.
import 'package:deskilo/core/demo/data/place_feedback_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/workspace_feedback.dart';
import 'package:deskilo/features/reservations/domain/place_feedback.dart';
import 'package:deskilo/features/reservations/presentation/widgets/place_feedback_bar.dart';
import 'package:deskilo/features/reservations/providers/place_feedback_providers.dart';
import 'package:deskilo/features/workspace/providers/operation_context_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<FakePlaceFeedbackRepository> _pump(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  FakeWorkspaceRepository? workspace,
}) async {
  final repo = FakePlaceFeedbackRepository()..others['seat:s1'] = [5, 3];
  await pumpApp(tester, const Scaffold(body: PlaceFeedbackBar(kind: PlaceKind.seat, id: 's1')), overrides: [
      ...standardTestOverrides(
          workspace: workspace ?? FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
          placeFeedback: repo),
    ]);
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _pumpChips(
  WidgetTester tester,
  FakePlaceFeedbackRepository repo,
  List<Widget> chips, {
  bool Function(String)? local,
}) async {
  await pumpApp(tester, Scaffold(body: Column(children: chips)), overrides: [
      ...standardTestOverrides(placeFeedback: repo),
      if (local != null) directorySourceIsLocalProvider.overrideWithValue(local),
    ]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('#3064 — the own rating is stated apart from the average',
      (tester) async {
    await _pump(tester);
    // Average only: nothing of the member's is filled, and the line says so.
    expect(find.text('4.0 · 2 ratings'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-mine-s1')), findsOneWidget);
    expect(find.text('You have not rated it'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);

    // Own rating: the line names it and exactly that many stars are filled.
    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('s1', 2)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your rating: 2 stars'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.text('3.3 · 3 ratings'), findsOneWidget,
        reason: 'the average counts the new rating, on its own line');
  });

  testWidgets('a heart, five stars and what everybody gave', (tester) async {
    final repo = await _pump(tester);
    expect(find.text('4.0 · 2 ratings'), findsOneWidget);

    await tester.tap(find.byKey(PlaceFeedbackBar.heartKey('s1')));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).favorite, isTrue);

    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('s1', 4)));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, 4);
    expect(find.text('4.0 · 3 ratings'), findsOneWidget);

    // The same star again takes the rating back; zero is a rating of its own.
    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('s1', 4)));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, isNull);
    await tester.tap(find.byKey(PlaceFeedbackBar.zeroKey('s1')));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, 0);
  });

  testWidgets('#2313 — on a phone with large text the heart and the five '
      'stars stay on one line', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester);
    final line = tester.getCenter(find.byKey(PlaceFeedbackBar.heartKey('s1'))).dy;
    for (var n = 1; n <= 5; n++) {
      expect(tester.getCenter(find.byKey(PlaceFeedbackBar.starKey('s1', n))).dy,
          moreOrLessEquals(line, epsilon: 1), reason: 'star $n');
    }
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
  });

  testWidgets('with the feature off there is no heart and no star', (tester) async {
    await _pump(tester, flags: const {'placeFeedback': false});
    expect(find.byKey(PlaceFeedbackBar.heartKey('s1')), findsNothing);
    expect(find.byKey(PlaceFeedbackBar.starKey('s1', 1)), findsNothing);
  });

  testWidgets('a list of places asks for their feedback in one request', (tester) async {
    final repo = FakePlaceFeedbackRepository();
    await _pumpChips(tester, repo, [
      for (var i = 0; i < 6; i++) PlaceFeedbackChip(kind: PlaceKind.seat, id: 's$i'),
    ]);
    expect(repo.manyCalls, 1);
    await tester.tap(find.byKey(PlaceFeedbackChip.heartKey('s2')));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's2')).favorite, isTrue);
  });

  testWidgets('a chip opens the rating sheet; a workspace of this server has '
      'feedback and another server\'s has none', (tester) async {
    final repo = FakePlaceFeedbackRepository();
    const mine = PublicWorkspace('w1', 'https://here.example', '', {'name': 'Mine'});
    const other = PublicWorkspace('w2', 'https://elsewhere.example', '', {'name': 'Other'});
    await _pumpChips(
      tester,
      repo,
      const [
        WorkspaceFeedback(workspace: mine),
        WorkspaceFeedback(workspace: other),
      ],
      local: (source) => source.contains('//here.'),
    );
    expect(find.byKey(PlaceFeedbackChip.heartKey('w1')), findsOneWidget);
    expect(find.byKey(PlaceFeedbackChip.heartKey('w2')), findsNothing);

    await tester.tap(find.byKey(PlaceFeedbackChip.rateKey('w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('w1', 5)));
    await tester.pumpAndSettle();
    expect((await repo.fetch('w1', PlaceKind.workspace, 'w1')).mine, 5);
  });

  testWidgets('#3869 — "this installation" follows the selected business: '
      'after a switch the stars of the new server are shown and written there',
      (tester) async {
    final h1 = SupabaseClient('https://h1.example', 'k');
    final h2 = SupabaseClient('https://h2.example', 'k');
    final repos = {
      'h1.example': FakePlaceFeedbackRepository(),
      'h2.example': FakePlaceFeedbackRepository(),
    };
    final routed = _ByServer(repos['h1.example']!);
    final selected = NotifierProvider<_Selected, SupabaseClient>(
        () => _Selected(h1));
    const a = PublicWorkspace('w1', 'https://h1.example', '', {'name': 'A'});
    const b = PublicWorkspace('w2', 'https://h2.example', '', {'name': 'B'});
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(children: [
          WorkspaceFeedback(workspace: a),
          WorkspaceFeedback(workspace: b),
        ]),
      ),
      overrides: [
        ...standardTestOverrides(placeFeedback: routed),
        selectedWorkspaceClientProvider
            .overrideWith((ref) => ref.watch(selected)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(PlaceFeedbackChip.heartKey('w1')), findsOneWidget);
    expect(find.byKey(PlaceFeedbackChip.heartKey('w2')), findsNothing);

    ProviderScope.containerOf(tester.element(find.byType(Column).first))
        .read(selected.notifier)
        .use(h2);
    routed.current = repos['h2.example']!;
    await tester.pumpAndSettle();
    expect(find.byKey(PlaceFeedbackChip.heartKey('w1')), findsNothing);
    expect(find.byKey(PlaceFeedbackChip.heartKey('w2')), findsOneWidget);

    await tester.tap(find.byKey(PlaceFeedbackChip.rateKey('w2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('w2', 4)));
    await tester.pumpAndSettle();
    expect((await repos['h2.example']!.fetch('w2', PlaceKind.workspace, 'w2')).mine, 4);
    expect((await repos['h1.example']!.fetch('w1', PlaceKind.workspace, 'w1')).mine, isNull);
    // The clients end their own timers before the test ends.
    await tester.pumpWidget(const SizedBox());
    await h1.dispose();
    await h2.dispose();
  });
}

class _Selected extends Notifier<SupabaseClient> {
  _Selected(this._first);
  final SupabaseClient _first;

  @override
  SupabaseClient build() => _first;

  void use(SupabaseClient client) => state = client;
}

/// The feedback of whichever server the selected business lives on.
class _ByServer implements PlaceFeedbackRepository {
  _ByServer(this.current);

  PlaceFeedbackRepository current;

  @override
  Future<PlaceFeedback> fetch(String w, PlaceKind k, String id) =>
      current.fetch(w, k, id);

  @override
  Future<Map<String, PlaceFeedback>> fetchMany(
          String w, PlaceKind k, List<String> ids) =>
      current.fetchMany(w, k, ids);

  @override
  Future<PlaceFeedback> setFavorite(String w, PlaceKind k, String id,
          {required bool on}) =>
      current.setFavorite(w, k, id, on: on);

  @override
  Future<PlaceFeedback> setRating(String w, PlaceKind k, String id, int? stars) =>
      current.setRating(w, k, id, stars);

  @override
  Future<List<FavoritePlace>> favorites(String w) => current.favorites(w);
}
