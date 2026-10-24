// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The map provider is named before the map loads, and the list-or-map
// choice is kept per person on this device (#2555 C2, DISC-02).
//
// Invariant: until the person chooses the map in the disclosure, no map
// widget exists and the geocoder is never asked; the disclosure names the
// tile and geocoder hosts and what they receive; staying with the list
// stores nothing and the next attempt asks again; continuing opens the map
// and, for someone signed in, keeps the view and the accepted provider
// under the person's namespace at their personal home, so a restart opens
// on the map, another account on the same device starts from the list,
// and another provider is asked about afresh. Signed out, nothing is
// written.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:deskilo/features/directory/providers/discovery_view_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _source = 'https://host.example';
const _place = PublicWorkspace('one', _source, 'sb_publishable_test', {
  'name': 'Office one',
  'address': '10 Main Street',
});

class _CountingGeocoder implements DirectoryGeocoder {
  final asked = <String>[];

  @override
  Future<DirectoryLocation?> locate(String address) async {
    asked.add(address);
    return null;
  }
}

String _namespace(String user) => savedPlacesNamespaceOf(
  issuer: 'https://test.local/auth/v1',
  subject: user,
  home: 'inst-test',
);

const _toggle = ValueKey('directory-portal-list');
const _disclosure = ValueKey('directory-map-disclosure');

Future<void> _show(
  WidgetTester tester, {
  required InMemoryDiscoveryViewStore store,
  required _CountingGeocoder geocoder,
  FakeAuthRepository? auth,
  MapServices? services,
}) async {
  await pumpApp(
    tester,
    const DirectoryScreen(),
    overrides: [
      ...standardTestOverrides(
        auth: auth ?? FakeAuthRepository.signedIn(),
        directory: FakeDirectoryRepository()..cards.add(_place),
        discoveryView: store,
      ),
      directoryGeocoderProvider.overrideWithValue(geocoder),
      if (services != null) mapServicesProvider.overrideWithValue(services),
    ],
  );
  await _frames(tester);
}

/// A tap's frames and the dialog's transition, without waiting for the
/// map to fall idle.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'the provider is named before the map loads; staying with the list '
    'loads and stores nothing, and the next attempt asks again',
    (tester) async {
      final store = InMemoryDiscoveryViewStore();
      final geocoder = _CountingGeocoder();
      await _show(tester, store: store, geocoder: geocoder);
      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(find.byKey(_disclosure), findsOneWidget);
      expect(
        find.textContaining('drawn by tile.openstreetmap.org'),
        findsOneWidget,
      );
      expect(find.textContaining('placed by photon.komoot.io'), findsOneWidget);
      expect(
        find.textContaining('receives connection and viewed-area information'),
        findsOneWidget,
      );
      expect(find.byType(DirectoryMap), findsNothing);
      expect(geocoder.asked, isEmpty);

      await tester.tap(find.byKey(const ValueKey('directory-map-stay')));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsNothing);
      expect(
        find.byKey(const ValueKey('directory-row-$_source/one')),
        findsOneWidget,
      );
      expect(store.byNamespace, isEmpty);
      expect(geocoder.asked, isEmpty);

      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(find.byKey(_disclosure), findsOneWidget);
    },
  );

  testWidgets(
    'continuing opens the map and keeps the choice for this person on this '
    'device; another account starts from the list',
    (tester) async {
      final store = InMemoryDiscoveryViewStore();
      final geocoder = _CountingGeocoder();
      await _show(tester, store: store, geocoder: geocoder);
      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(
        find.text('Your choice is kept on this device for this map provider.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsOneWidget);
      final kept = store.byNamespace[_namespace('user-1')]!;
      expect(kept.map, isTrue);
      expect(kept.acceptedProvider, MapServices.configured.identity);
      expect(store.byNamespace.keys, [_namespace('user-1')]);

      // Back to the list and to the map again: the provider is known.
      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsNothing);
      expect(store.byNamespace[_namespace('user-1')]!.map, isFalse);
      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(find.byKey(_disclosure), findsNothing);
      expect(find.byType(DirectoryMap), findsOneWidget);

      // A restart over the same device store opens on the map.
      await tester.pumpWidget(const SizedBox.shrink());
      await _show(tester, store: store, geocoder: geocoder);
      expect(find.byType(DirectoryMap), findsOneWidget);

      // Another account on this device: the list, and the map asks first.
      await tester.pumpWidget(const SizedBox.shrink());
      await _show(
        tester,
        store: store,
        geocoder: geocoder,
        auth: FakeAuthRepository(userId: 'user-2'),
      );
      expect(find.byType(DirectoryMap), findsNothing);
      await tester.tap(find.byKey(_toggle));
      await _frames(tester);
      expect(find.byKey(_disclosure), findsOneWidget);
    },
  );

  testWidgets('another map provider is asked about afresh', (tester) async {
    final store = InMemoryDiscoveryViewStore()
      ..byNamespace[_namespace('user-1')] = DiscoveryViewPreference(
        map: true,
        acceptedProvider: MapServices.configured.identity,
      );
    final geocoder = _CountingGeocoder();
    await _show(
      tester,
      store: store,
      geocoder: geocoder,
      services: const MapServices(
        tiles: 'https://{s}.tiles.other.example/{z}/{x}/{y}.png',
        geocoder: 'https://geo.other.example/api/',
      ),
    );
    expect(find.byType(DirectoryMap), findsNothing);
    expect(geocoder.asked, isEmpty);
    await tester.tap(find.byKey(_toggle));
    await _frames(tester);
    expect(find.textContaining('drawn by tiles.other.example'), findsOneWidget);
    expect(find.textContaining('placed by geo.other.example'), findsOneWidget);
  });

  testWidgets('Locate on a card asks first too', (tester) async {
    final geocoder = _CountingGeocoder();
    await _show(
      tester,
      store: InMemoryDiscoveryViewStore(),
      geocoder: geocoder,
    );
    await tester.tap(
      find.byKey(const ValueKey('directory-locate-$_source/one')),
    );
    await _frames(tester);
    expect(find.byKey(_disclosure), findsOneWidget);
    expect(find.byType(DirectoryMap), findsNothing);
    expect(geocoder.asked, isEmpty);
    await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
    await _frames(tester);
    expect(find.byType(DirectoryMap), findsOneWidget);
    expect(geocoder.asked, [
      '10 Main Street',
    ], reason: 'the geocoder is asked only once the map was chosen');
  });

  testWidgets('signed out, the map can be chosen and nothing is stored', (
    tester,
  ) async {
    final store = InMemoryDiscoveryViewStore();
    await _show(
      tester,
      store: store,
      geocoder: _CountingGeocoder(),
      auth: FakeAuthRepository(),
    );
    await tester.tap(find.byKey(_toggle));
    await _frames(tester);
    expect(
      find.text('Your choice is kept on this device for this map provider.'),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
    await _frames(tester);
    expect(find.byType(DirectoryMap), findsOneWidget);
    expect(store.byNamespace, isEmpty);
  });
}
