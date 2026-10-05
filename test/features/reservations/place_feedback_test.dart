// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a member favourites a place and rates it from 0 to 5 stars; the
// bar is absent where the feature is off or the permission is not held.
import 'package:deskilo/core/demo/data/place_feedback_repository.dart';
import 'package:deskilo/features/reservations/domain/place_feedback.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/workspace_feedback.dart';
import 'package:deskilo/features/reservations/presentation/widgets/place_feedback_bar.dart';
import 'package:deskilo/features/reservations/providers/place_feedback_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakePlaceFeedbackRepository> _pump(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  FakeWorkspaceRepository? workspace,
}) async {
  final repo = FakePlaceFeedbackRepository()..others['seat:s1'] = [5, 3];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...standardTestOverrides(
          workspace: workspace ?? FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
          placeFeedback: repo),
    ],
    child: const MaterialApp(
      home: Scaffold(body: PlaceFeedbackBar(kind: PlaceKind.seat, id: 's1')),
    ),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _pumpChips(
  WidgetTester tester,
  FakePlaceFeedbackRepository repo,
  List<Widget> chips, {
  bool Function(String)? local,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...standardTestOverrides(placeFeedback: repo),
      if (local != null) directorySourceIsLocalProvider.overrideWithValue(local),
    ],
    child: MaterialApp(home: Scaffold(body: Column(children: chips))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a heart, five stars and what everybody gave', (tester) async {
    final repo = await _pump(tester);
    expect(find.text('4.0 · 2'), findsOneWidget);

    await tester.tap(find.byKey(PlaceFeedbackBar.heartKey('s1')));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).favorite, isTrue);

    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('s1', 4)));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, 4);
    expect(find.text('4.0 · 3'), findsOneWidget);

    // The same star again takes the rating back; zero is a rating of its own.
    await tester.tap(find.byKey(PlaceFeedbackBar.starKey('s1', 4)));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, isNull);
    await tester.tap(find.byKey(PlaceFeedbackBar.zeroKey('s1')));
    await tester.pumpAndSettle();
    expect((await repo.fetch('ws-1', PlaceKind.seat, 's1')).mine, 0);
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
}
