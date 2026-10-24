// SPDX-License-Identifier: AGPL-3.0-or-later
//
// SAVE-01 (#2555): a saved place is private to one person on this device,
// is the place on its own host, and does nothing else.
//
// Invariants:
// - Two hosts may publish a workspace with the same UUID: saving one never
//   marks the other; a saved place is its host plus its id.
// - Selecting a workspace on another host changes nothing saved: the list
//   lives under the person at their personal home, not under the selected
//   workspace.
// - Account A, then account B, then A again on one device: each sees only
//   what they saved, and B's saving writes nothing under A.
// - Saving is not joining, publishing, linking, a favourite or a rating:
//   none of those is asked.
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/demo/data/place_feedback_repository.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/reservations/domain/place_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _wa = 'https://wa.example';
const _wb = 'https://wb.example';
const _same = '00000000-0000-4000-8000-000000005a01';
const _onA = PublicWorkspace(_same, _wa, 'sb_publishable_wa_key_001', {
  'name': 'Atelier',
  'host_type': 'company',
});
const _onB = PublicWorkspace(_same, _wb, 'sb_publishable_wb_key_001', {
  'name': 'Bureau',
  'host_type': 'company',
});

String _namespace(String user) => savedPlacesNamespaceOf(
  issuer: 'https://test.local/auth/v1',
  subject: user,
  home: 'inst-test',
);

Key _bookmark(PublicWorkspace w) =>
    ValueKey('directory-bookmark-${w.source}/${w.id}');

/// Counts every favourite or rating written.
class _Feedback extends FakePlaceFeedbackRepository {
  int writes = 0;

  @override
  Future<PlaceFeedback> setFavorite(
    String workspaceId,
    PlaceKind kind,
    String id, {
    required bool on,
  }) {
    writes++;
    return super.setFavorite(workspaceId, kind, id, on: on);
  }

  @override
  Future<PlaceFeedback> setRating(
    String workspaceId,
    PlaceKind kind,
    String id,
    int? stars,
  ) {
    writes++;
    return super.setRating(workspaceId, kind, id, stars);
  }
}

Future<void> _show(
  WidgetTester tester, {
  required InMemorySavedPlacesStore store,
  required FakeDirectoryRepository directory,
  required _Feedback feedback,
  required String user,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    const DirectoryScreen(),
    overrides: standardTestOverrides(
      auth: FakeAuthRepository(userId: user),
      directory: directory,
      savedPlaces: store,
      placeFeedback: feedback,
    ),
  );
  await tester.pumpAndSettle();
}

bool _saved(WidgetTester tester, PublicWorkspace w) => find
    .descendant(
      of: find.byKey(ValueKey('directory-row-${w.source}/${w.id}')),
      matching: find.text('Saved on this device'),
    )
    .evaluate()
    .isNotEmpty;

List<(String, String)> _places(InMemorySavedPlacesStore store, String user) => [
  for (final p in store.byNamespace[_namespace(user)] ?? const <SavedPlace>[])
    (p.source, p.id),
];

void main() {
  testWidgets('SAVE-01: equal UUIDs on two hosts, another selected '
      'workspace, and account A then B then A: each saved list stays its '
      'own, and saving asks nothing else', (tester) async {
    final store = InMemorySavedPlacesStore();
    final directory = FakeDirectoryRepository()..cards.addAll([_onA, _onB]);
    final feedback = _Feedback();

    await _show(
      tester,
      store: store,
      directory: directory,
      feedback: feedback,
      user: 'user-a',
    );
    await tester.tap(find.byKey(_bookmark(_onA)));
    await tester.pumpAndSettle();
    expect(_saved(tester, _onA), isTrue);
    expect(_saved(tester, _onB), isFalse, reason: 'same UUID, other host');
    expect(_places(store, 'user-a'), [(_wa, _same)]);

    // A workspace on W-B is selected: what A saved does not move.
    ProviderScope.containerOf(tester.element(find.byType(DirectoryScreen)))
        .read(selectedWorkspaceHostProvider.notifier)
        .select(_same, _wb);
    await tester.pumpAndSettle();
    expect(_saved(tester, _onA), isTrue);
    expect(_saved(tester, _onB), isFalse);
    expect(store.byNamespace.keys, [_namespace('user-a')]);

    // Account B on the same device sees nothing of A's, and saves its own.
    await _show(
      tester,
      store: store,
      directory: directory,
      feedback: feedback,
      user: 'user-b',
    );
    expect(_saved(tester, _onA), isFalse);
    expect(_saved(tester, _onB), isFalse);
    await tester.tap(find.byKey(_bookmark(_onB)));
    await tester.pumpAndSettle();
    expect(_places(store, 'user-b'), [(_wb, _same)]);
    expect(_places(store, 'user-a'), [(_wa, _same)], reason: 'A untouched');

    // Back to A: A's place, not B's.
    await _show(
      tester,
      store: store,
      directory: directory,
      feedback: feedback,
      user: 'user-a',
    );
    expect(_saved(tester, _onA), isTrue);
    expect(_saved(tester, _onB), isFalse);

    expect(directory.requests, isEmpty, reason: 'no request to join');
    expect(directory.pages, isEmpty, reason: 'nothing published');
    expect(directory.linked, isEmpty, reason: 'no directory link');
    expect(feedback.writes, 0, reason: 'no favourite, no rating');
    expect(tester.takeException(), isNull);
  });
}
