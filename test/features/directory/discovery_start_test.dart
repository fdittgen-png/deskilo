// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step C -- Discover is never a blank page. Before a search with no
// place loaded it says what to type; a search with no result names what was
// typed and offers Clear search; a directory that cannot be read is one line
// with its Retry above the start state, never a centred message; the counts
// live behind Details. At 320 px nothing overflows.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

PublicWorkspace _card(String id, String name) =>
    PublicWorkspace(id, 'https://a.example', 'k', {'name': name});

Future<void> _pump(
  WidgetTester tester,
  FakeDirectoryRepository directory, {
  Size size = const Size(390, 1600),
}) async {
  await pumpApp(
    tester,
    const DirectoryScreen(),
    size: size,
    overrides: standardTestOverrides(
      auth: FakeAuthRepository.signedIn(),
      directory: directory,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('no place and no query: the start state says what to type', (tester) async {
    await _pump(tester, FakeDirectoryRepository());
    expect(_key('directory-start'), findsOneWidget);
    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.text('Type a city, a service or a name.'), findsOneWidget);
    expect(find.text('Yoga, a desk, a massage…'), findsOneWidget, reason: 'the hint');
    expect(find.textContaining('No published workspaces'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('places already loaded are shown before any query', (tester) async {
    final directory = FakeDirectoryRepository()
      ..cards.addAll([_card('1', 'Atelier Nord'), _card('2', 'Studio Sud')]);
    await _pump(tester, directory);
    expect(_key('directory-start'), findsNothing);
    expect(find.text('Atelier Nord'), findsOneWidget);
  });

  testWidgets('a search with no result names it and Clear search starts over', (tester) async {
    final directory = FakeDirectoryRepository()..cards.add(_card('1', 'Atelier Nord'));
    await _pump(tester, directory);
    await tester.enterText(_key('directory-portal-search-2'), 'zzzz');
    await tester.tap(_key('directory-portal-search'));
    await tester.pumpAndSettle();
    expect(_key('directory-no-match'), findsOneWidget);
    expect(find.text('Nothing found for “zzzz”'), findsOneWidget);
    await tester.tap(_key('directory-clear-search'));
    await tester.pumpAndSettle();
    expect(_key('directory-no-match'), findsNothing);
    expect(find.text('Atelier Nord'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('directory-portal-search-2')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a directory that cannot be read is one line with Retry above the start state', (tester) async {
    final directory = FakeDirectoryRepository()..fail = true;
    await _pump(tester, directory);
    final banner = _key('directory-portal-directory-unavailable-2');
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('directory did not answer')),
      findsOneWidget,
    );
    expect(find.text('What are you looking for?'), findsOneWidget);
    directory.fail = false;
    await tester.tap(
      find.descendant(of: banner, matching: _key('me-notice-retry')),
    );
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
  });

  testWidgets('the counts are behind Details', (tester) async {
    final directory = FakeDirectoryRepository()..cards.add(_card('1', 'Atelier Nord'));
    await _pump(tester, directory);
    expect(_key('directory-loaded-count'), findsNothing);
    await tester.tap(_key('directory-details'));
    await tester.pumpAndSettle();
    expect(_key('directory-loaded-count'), findsOneWidget);
  });

  testWidgets('at 320 px the start and no-match states do not overflow', (tester) async {
    await _pump(tester, FakeDirectoryRepository(), size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    await tester.enterText(_key('directory-portal-search-2'), 'zzzz');
    await tester.tap(_key('directory-portal-search'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
