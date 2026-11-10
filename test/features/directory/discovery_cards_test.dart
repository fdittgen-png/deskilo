// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step C -- a place card says its name, its town and the kind of host
// when the space published them: never the server it is served from. One View
// per card; a directory that did not answer is one notice beside the results
// that loaded, and Details closes the list.
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/place_summary.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/discovery_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _source = DirectorySource('https://a.example', 'k');

PublicWorkspace _place(String id, String name, Map<String, dynamic> more) =>
    PublicWorkspace(id, _source.origin, 'k', {'name': name, ...more});

DiscoveryResults _results({List<String> refused = const []}) =>
    DiscoveryResults(
      sources: [
        SourceListing(
          _source,
          status: SourceStatus.ready,
          cards: [
            _place('1', 'Atelier Nord', {
              'address': '12 rue Haute, 34120 Pézenas',
              'host_type': 'company',
            }),
            _place('2', 'Studio Sud', {'host_type': 'person'}),
          ],
        ),
      ],
      refused: refused,
    );

Future<void> _pump(WidgetTester tester, DiscoveryResults results) async {
  await pumpApp(
    tester,
    Scaffold(
      body: DiscoveryListView(
        query: '',
        results: results,
        selected: null,
        onView: (_) {},
        onLocate: (_) {},
        onClear: () {},
      ),
    ),
    size: const Size(390, 1200),
    overrides: standardTestOverrides(auth: FakeAuthRepository.signedIn()),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the town of an address: the last part without its postal code', () {
    expect(cityOfAddress('12 rue Haute, 34120 Pézenas'), 'Pézenas');
    expect(cityOfAddress('Rue Haute\n75002 Paris'), 'Paris');
    expect(cityOfAddress('Hauptstraße 5, Berlin'), 'Berlin');
    expect(
      cityOfAddress('12 rue Haute'),
      isEmpty,
      reason: 'a street is not a town',
    );
    expect(cityOfAddress(''), isEmpty);
  });

  testWidgets('a card says name, town and kind — never the server', (
    tester,
  ) async {
    await _pump(tester, _results());
    expect(find.text('Pézenas · Company'), findsOneWidget);
    expect(find.textContaining('a.example'), findsNothing);
    expect(find.text('Private host'), findsNothing);
    expect(find.text('Studio Sud'), findsOneWidget);
  });

  testWidgets('one View per card; bookmark and locate are named icon buttons', (
    tester,
  ) async {
    await _pump(tester, _results());
    expect(find.widgetWithText(FilledButton, 'View'), findsNWidgets(2));
    expect(find.byTooltip('Bookmark'), findsNWidgets(2));
    expect(find.byTooltip('Locate on map'), findsNWidgets(2));
  });

  testWidgets(
    'one directory failed, two places loaded: a notice with Try again, '
    'and Details at the end',
    (tester) async {
      await _pump(tester, _results(refused: const ['https://dead.example']));
      final notice = find.byKey(
        const ValueKey('directory-portal-directory-unavailable'),
      );
      expect(notice, findsOneWidget);
      expect(find.text('Atelier Nord'), findsOneWidget);
      expect(find.text('Studio Sud'), findsOneWidget);
      expect(
        tester.getTopLeft(notice).dy,
        lessThan(tester.getTopLeft(find.text('Atelier Nord')).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('directory-details'))).dy,
        greaterThan(tester.getTopLeft(find.text('Studio Sud')).dy),
        reason: 'Details closes the list',
      );
    },
  );
}
