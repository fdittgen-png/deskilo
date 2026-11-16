// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 PR 1 — Discover finds businesses by kind. The chips are the app's
// catalogue, never the kinds the loaded page contains: a practice on a
// source's second page is still found by choosing Practices, which starts a
// new listing carrying the kind. A chosen kind stays chosen with nothing
// found and with a source failed, and "All kinds" is the way back. A card
// names the business's kind, its town and up to three public services, each
// in its own currency with its tax word: never a figure across currencies.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _a = 'https://a.example';
const _b = 'https://b.example';

PublicWorkspace _card(
  String id,
  String name, {
  String source = _a,
  List<String> kinds = const ['coworking'],
  List<Map<String, Object?>> services = const [],
  String address = '',
}) => PublicWorkspace(id, source, 'k', {
  'name': name,
  'address': address,
  'kinds': kinds,
  'services': services,
});

Map<String, Object?> _service(
  String name,
  int minor,
  String currency, {
  int? minutes,
  String tax = 'included',
}) => {
  'name': name,
  'duration_minutes': ?minutes,
  'price_minor': minor,
  'currency': currency,
  'tax_treatment': tax,
};

/// One source whose first page holds coworking spaces only; the practice is
/// on its second page.
FakeDirectoryRepository _paged() => FakeDirectoryRepository()
  ..pageSize = 2
  ..cards.addAll([
    _card('c1', 'Atelier Nord'),
    _card('c2', 'Atelier Sud'),
    _card('p1', 'Cabinet Garrigue', kinds: const ['practice']),
  ]);

Future<void> _pumpDiscover(
  WidgetTester tester,
  FakeDirectoryRepository directory, {
  String? kind,
}) async {
  await pumpApp(
    tester,
    DirectoryScreen(initialKind: kind),
    size: const Size(390, 1600),
    overrides: standardTestOverrides(directory: directory),
  );
  await tester.pumpAndSettle();
}

bool _chosen(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;

void main() {
  test('page 1 holds coworking only; choosing Practices starts a new listing '
      'that carries the kind', () async {
    final directory = _paged();
    final container = ProviderContainer(
      overrides: standardTestOverrides(directory: directory),
    );
    addTearDown(container.dispose);

    final all = await container.read(
      discoveryListingProvider(const DiscoveryFilter('')).future,
    );
    expect(all.workspaces.map((w) => w.id), ['c1', 'c2']);

    final practices = await container.read(
      discoveryListingProvider(const DiscoveryFilter('', kind: 'practice'))
          .future,
    );
    expect(practices.workspaces.map((w) => w.id), ['p1']);
    expect(directory.reads, [
      '$_a#0',
      '$_a#0',
    ], reason: 'a new listing asks the first page again, with the kind');
  });

  testWidgets('the chips are the catalogue, whatever the page holds; '
      'Practices finds the practice beyond page 1', (tester) async {
    await _pumpDiscover(tester, _paged());

    for (final key in [
      'directory-kind-all',
      'directory-kind-coworking',
      'directory-kind-studio',
      'directory-kind-practice',
      'directory-kind-salon',
      'directory-kind-service',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Practices'), findsOneWidget);
    expect(_chosen(tester, 'directory-kind-all'), isTrue);
    expect(find.text('Cabinet Garrigue'), findsNothing);
    expect(find.textContaining('found'), findsNothing, reason: 'no counts');

    await tester.tap(find.byKey(const ValueKey('directory-kind-practice')));
    await tester.pumpAndSettle();
    expect(find.text('Cabinet Garrigue'), findsOneWidget);
    expect(find.text('Atelier Nord'), findsNothing);
    expect(_chosen(tester, 'directory-kind-practice'), isTrue);
  });

  testWidgets('a chosen kind stays chosen with nothing found; All kinds is the '
      'way back', (tester) async {
    await _pumpDiscover(tester, _paged(), kind: 'salon');

    expect(_chosen(tester, 'directory-kind-salon'), isTrue);
    expect(find.text('Nothing found in “Salons”'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('directory-kind-show-all')));
    await tester.pumpAndSettle();
    expect(_chosen(tester, 'directory-kind-all'), isTrue);
    expect(find.text('Atelier Nord'), findsOneWidget);
  });

  testWidgets('a chosen kind stays chosen when a source fails: the other '
      'source\'s practice shows, the failed one offers its retry', (
    tester,
  ) async {
    final directory = FakeDirectoryRepository()
      ..cards.addAll([
        _card('p1', 'Cabinet Garrigue', kinds: const ['practice']),
        _card('p2', 'Praxis am Markt', source: _b, kinds: const ['practice']),
      ])
      ..failPages.add('$_b#0');
    await _pumpDiscover(tester, directory, kind: 'practice');

    expect(_chosen(tester, 'directory-kind-practice'), isTrue);
    expect(find.text('Cabinet Garrigue'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-source-retry-$_b')),
      findsOneWidget,
    );

    directory.failPages.clear();
    await tester.tap(find.byKey(const ValueKey('directory-source-retry-$_b')));
    await tester.pumpAndSettle();
    expect(find.text('Praxis am Markt'), findsOneWidget);
    expect(_chosen(tester, 'directory-kind-practice'), isTrue);
  });

  testWidgets('a kind from the route that the app does not know is ignored', (
    tester,
  ) async {
    await _pumpDiscover(tester, _paged(), kind: 'spaceship');
    expect(_chosen(tester, 'directory-kind-all'), isTrue);
    expect(find.text('Atelier Nord'), findsOneWidget);
  });

  testWidgets('a card names its kind, town and three services, each in its own '
      'currency with its tax word; nothing across currencies', (tester) async {
    final directory = FakeDirectoryRepository()
      ..cards.addAll([
        _card(
          'p1',
          'Cabinet Garrigue',
          kinds: const ['practice'],
          address: '8 rue Conti\n34120 Pézenas',
          services: [
            _service('Relaxing massage', 6500, 'EUR', minutes: 60, tax: 'none'),
            _service('Back massage', 3800, 'EUR', minutes: 30, tax: 'none'),
            _service('Foot reflexology', 5000, 'EUR', minutes: 45, tax: 'none'),
            _service('Five massages', 29000, 'EUR', tax: 'none'),
          ],
        ),
        _card(
          'z1',
          'Limmat Cowork',
          address: 'Beispielstrasse 12\n8005 Zurich',
          services: [_service('Hot desk day', 4500, 'CHF')],
        ),
        _card('x1', 'Unknown kind', kinds: const ['spaceship']),
      ]);
    await _pumpDiscover(tester, directory);

    expect(find.textContaining('Practice'), findsWidgets);
    expect(find.text('Pézenas · Practice'), findsOneWidget);
    expect(find.text('Zurich · Coworking space'), findsOneWidget);
    expect(
      find.textContaining('spaceship'),
      findsNothing,
      reason: 'a kind this app does not know is not shown as a code',
    );

    final massage = tester
        .widget<Text>(find.textContaining('Relaxing massage'))
        .data!;
    expect(massage, startsWith('Relaxing massage · 60 min · '));
    expect(massage, contains('65'));
    expect(massage, isNot(contains('CHF')), reason: 'its own currency');
    expect(massage, endsWith(' · no tax'));
    expect(find.textContaining('Foot reflexology'), findsOneWidget);
    expect(
      find.textContaining('Five massages'),
      findsNothing,
      reason: 'a card names three services; the page lists them all',
    );

    final desk = tester.widget<Text>(find.textContaining('Hot desk day')).data!;
    expect(desk, contains('CHF'));
    expect(desk, isNot(contains('EUR')));
    expect(desk, endsWith(' · tax included'));
    expect(
      find.textContaining('from'),
      findsNothing,
      reason: 'no price computed across services',
    );
  });
}
