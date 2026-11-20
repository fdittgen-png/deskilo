// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2832 (checkpoint 4) — Discover narrows by what businesses publish. A card
// matches a fact only when it publishes it: one that publishes nothing about
// it is unknown for it, never a match and never a refusal. A source that
// cannot filter by facts is not asked and is said to have not been asked,
// never counted as having no result, and the sources that can still answer.
// The search (words, kind, facts and the selection) outlives the screen.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/presentation/public_facet_labels.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
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
  List<String>? amenities,
  List<String>? accessibility,
}) => PublicWorkspace(id, source, 'k', {
  'name': name,
  'kinds': const ['coworking'],
  'amenities': ?amenities,
  'accessibility': ?accessibility,
});

/// One source: a quay with wifi and a step-free entrance, a workshop that
/// publishes a kitchen and says nothing of accessibility, and a business
/// that publishes no facts at all.
FakeDirectoryRepository _directory() =>
    FakeDirectoryRepository()
      ..cards.addAll([
        _card(
          'q',
          'Le Quai',
          amenities: ['wifi', 'meeting_room'],
          accessibility: ['step_free_entrance'],
        ),
        _card('f', 'La Fabrique', amenities: ['kitchen']),
        _card('n', 'Sans Faits'),
      ]);

final _en = AppLocalizationsEn();
String _label(String id) => publicFacetLabel(_en, id);

Future<List<String>> _ids(ProviderContainer c, DiscoveryFilter filter) async =>
    [
      for (final w in (await c.read(
        discoveryListingProvider(filter).future,
      )).workspaces)
        w.id,
    ];

Future<void> _pumpDiscover(
  WidgetTester tester,
  FakeDirectoryRepository directory, {
  Widget? home,
}) async {
  await pumpApp(
    tester,
    home ?? const DirectoryScreen(),
    size: const Size(390, 1600),
    overrides: standardTestOverrides(directory: directory),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, List<String> ids) async {
  await tester.tap(find.byKey(const ValueKey('directory-filters-open')));
  await tester.pumpAndSettle();
  for (final id in ids) {
    final key = ValueKey(
      id == 'step_free_entrance' || id == 'lift'
          ? 'directory-facet-access-$id'
          : 'directory-facet-amenity-$id',
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('directory-filters-show')));
  await tester.pumpAndSettle();
}

void main() {
  test('the same facts in another order are the same filter; a fact makes the '
      'listing narrowed', () {
    const a = DiscoveryFilter('', amenities: ['wifi', 'kitchen']);
    const b = DiscoveryFilter('', amenities: ['kitchen', 'wifi']);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.hasFacets && a.isNarrowed, isTrue);
    expect(const DiscoveryFilter(''), isNot(a));
    expect(const DiscoveryFilter('', kind: 'practice').isNarrowed, isTrue);
    expect(const DiscoveryFilter('', kind: 'practice').hasFacets, isFalse);
  });

  test('a fact matches the cards that publish it, all of them together; a card '
      'that publishes nothing about it is unknown, not a match', () async {
    final c = ProviderContainer(
      overrides: standardTestOverrides(directory: _directory()),
    );
    addTearDown(c.dispose);
    expect(await _ids(c, const DiscoveryFilter('')), ['q', 'f', 'n']);
    expect(await _ids(c, const DiscoveryFilter('', amenities: ['wifi'])), [
      'q',
    ]);
    expect(
      await _ids(c, const DiscoveryFilter('', amenities: ['wifi', 'kitchen'])),
      isEmpty,
    );
    expect(
      await _ids(
        c,
        const DiscoveryFilter('', accessibility: ['step_free_entrance']),
      ),
      ['q'],
    );
    expect(
      await _ids(
        c,
        const DiscoveryFilter(
          '',
          amenities: ['kitchen'],
          accessibility: ['lift'],
        ),
      ),
      isEmpty,
      reason:
          'the workshop publishes no accessibility fact: unknown is not "lift"',
    );
  });

  test('a source that cannot filter by facts is held apart as not asked; the '
      'others still answer', () async {
    final d = FakeDirectoryRepository()
      ..withoutFacets.add(_b)
      ..cards.addAll([
        _card('q', 'Le Quai', amenities: ['wifi']),
        _card('old', 'Old Host', source: _b, amenities: ['wifi']),
      ]);
    final c = ProviderContainer(overrides: standardTestOverrides(directory: d));
    addTearDown(c.dispose);
    final narrowed = await c.read(
      discoveryListingProvider(const DiscoveryFilter('', amenities: ['wifi']))
          .future,
    );
    expect(narrowed.workspaces.map((w) => w.id), ['q']);
    expect(narrowed.uncovered, [
      _b,
    ], reason: 'missing from the result, not absent from it');
    final plain = await c.read(
      discoveryListingProvider(const DiscoveryFilter('')).future,
    );
    expect(plain.workspaces.map((w) => w.id), unorderedEquals(['q', 'old']));
    expect(plain.uncovered, isEmpty);
  });

  testWidgets(
    'the sheet offers the catalogue; choosing a fact narrows the list '
    'and shows it as a chip; clearing brings everything back',
    (tester) async {
      await _pumpDiscover(tester, _directory());
      expect(find.text('Le Quai'), findsOneWidget);
      expect(find.text('La Fabrique'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);

      await _choose(tester, ['wifi']);
      expect(find.text('Le Quai'), findsOneWidget);
      expect(find.text('La Fabrique'), findsNothing);
      expect(find.text('Sans Faits'), findsNothing);
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('directory-filter-chip-wifi')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('directory-filter-chip-wifi')),
          matching: find.text(_label('wifi')),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('directory-filters-clear')));
      await tester.pumpAndSettle();
      expect(find.text('La Fabrique'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    },
  );

  testWidgets('a fact nobody who answered publishes says so and offers the way '
      'back: an empty result, not an incomplete one', (tester) async {
    await _pumpDiscover(tester, _directory());
    await _choose(tester, ['lift']);
    expect(
      find.byKey(const ValueKey('directory-facet-no-match')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('directory-facet-uncovered')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('directory-facet-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Le Quai'), findsOneWidget);
  });

  testWidgets('a source that cannot filter is said not to have been asked, '
      'beside the results of the one that can', (tester) async {
    final d = FakeDirectoryRepository()
      ..withoutFacets.add(_b)
      ..cards.addAll([
        _card('q', 'Le Quai', amenities: ['wifi']),
        _card('old', 'Old Host', source: _b, amenities: ['wifi']),
      ]);
    await _pumpDiscover(tester, d);
    await _choose(tester, ['wifi']);
    expect(find.text('Le Quai'), findsOneWidget);
    expect(find.text('Old Host'), findsNothing);
    expect(
      find.byKey(const ValueKey('directory-facet-uncovered')),
      findsOneWidget,
    );
    expect(find.textContaining('not asked'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-facet-no-match')),
      findsNothing,
    );
  });

  testWidgets('the search outlives the screen: the facts, the kind and the '
      'words are there when it comes back', (tester) async {
    await _pumpDiscover(tester, _directory(), home: const _Toggle());
    await _choose(tester, ['wifi']);
    await tester.tap(find.byKey(const ValueKey('directory-kind-coworking')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('directory-portal-search-2')),
      'Quai',
    );
    await tester.tap(find.byKey(const ValueKey('directory-portal-search')));
    await tester.pumpAndSettle();
    expect(find.text('Le Quai'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pumpAndSettle();

    expect(find.byType(DirectoryScreen), findsOneWidget);
    expect(find.text('Filters (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-filter-chip-wifi')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('directory-kind-coworking')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('directory-portal-search-2')),
          )
          .controller!
          .text,
      'Quai',
    );
    expect(find.text('Le Quai'), findsOneWidget);
    expect(find.text('La Fabrique'), findsNothing);
  });
}

/// The screen shown and hidden inside one app, as another tab is.
class _Toggle extends StatefulWidget {
  const _Toggle();

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  var _shown = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const ValueKey('toggle'),
          onPressed: () => setState(() => _shown = !_shown),
          child: const Text('toggle'),
        ),
        if (_shown) const Expanded(child: DirectoryScreen()),
      ],
    ),
  );
}
