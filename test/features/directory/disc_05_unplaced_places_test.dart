// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DISC-05 (#2555): places the map cannot show are counted, and stay cards.
//
// Invariants:
// - The map's "could not be placed" count is every loaded place without a
//   pin whose lookup has settled: no public address, an address the
//   geocoder does not find, a lookup that failed, and a place beyond the
//   bounded lookups (deferred). A lookup still running is not counted yet.
// - Places at the same spot fold into one cluster with their number; none
//   of them is lost.
// - Beside the map, every loaded place keeps its card in the list, placed
//   or not.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _source = 'https://host.example';

PublicWorkspace _place(
  String id, {
  String? address,
  double? lat,
  double? lng,
}) => PublicWorkspace(id, _source, 'sb_publishable_test', {
  'name': 'Office $id',
  'address': ?address,
  'latitude': ?lat?.toString(),
  'longitude': ?lng?.toString(),
});

/// Every "Street …" is at one spot; "Nowhere" is not found; "Broken"
/// fails; an address in [pending] answers when the test says so.
class _Geocoder implements DirectoryGeocoder {
  final pending = <String, Completer<DirectoryLocation?>>{};

  @override
  Future<DirectoryLocation?> locate(String address) async {
    if (pending[address] case final answer?) return answer.future;
    if (address == 'Broken') throw StateError('offline');
    if (address.startsWith('Street')) {
      return const DirectoryLocation(43.46, 3.42, label: 'Pézenas');
    }
    return null;
  }
}

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
        ),
      );
}

Future<void> _showMap(
  WidgetTester tester,
  List<PublicWorkspace> places,
  _Geocoder geocoder,
) async {
  await pumpApp(
    tester,
    Scaffold(
      body: DirectoryMap(
        workspaces: places,
        selected: null,
        onSelect: (_) {},
        tileProvider: _BlankTiles(),
      ),
    ),
    overrides: [directoryGeocoderProvider.overrideWithValue(geocoder)],
  );
  await _frames(tester);
}

/// Frames enough for the lookups and the camera, without waiting for the
/// map to fall idle.
Future<void> _frames(WidgetTester tester) async {
  for (final wait in const [Duration.zero, Duration(seconds: 1)]) {
    await tester.pump(wait);
    await tester.pump(wait);
  }
}

const _missing = ValueKey('directory-pins-missing');

void main() {
  testWidgets('DISC-05: no address, not found, failed and deferred places '
      'are all counted; places at one spot fold into one cluster', (
    tester,
  ) async {
    final places = [
      _place('paris-1', lat: 48.86, lng: 2.35),
      _place('paris-2', lat: 48.86, lng: 2.35),
      _place('blank'),
      _place('nowhere', address: 'Nowhere'),
      _place('broken', address: 'Broken'),
      // 3 lookups are spent above; 17 of these are looked up, 3 deferred.
      for (var i = 0; i < 20; i++) _place('street-$i', address: 'Street $i'),
    ];
    await _showMap(tester, places, _Geocoder());

    expect(find.byKey(_missing), findsOneWidget);
    expect(
      find.text(
        '6 workspaces could not be placed on the map; their cards are below.',
      ),
      findsOneWidget,
      reason: 'no address 1, not found 1, failed 1, deferred 3',
    );
    expect(find.text('2'), findsOneWidget, reason: 'the two Paris places');
    expect(find.text('17'), findsOneWidget, reason: 'every looked-up place');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DISC-05: a lookup still running is not counted; once it '
      'settles without a place, it is', (tester) async {
    final geocoder = _Geocoder();
    final late = Completer<DirectoryLocation?>();
    geocoder.pending['Slow road'] = late;
    await _showMap(tester, [
      _place('paris', lat: 48.86, lng: 2.35),
      _place('slow', address: 'Slow road'),
    ], geocoder);
    expect(find.byKey(_missing), findsNothing);

    late.complete(null);
    await _frames(tester);
    expect(
      find.text(
        '1 workspace could not be placed on the map; its card is below.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('DISC-05: beside the map, every loaded place keeps its card, '
      'placed or not', (tester) async {
    final places = [
      _place('paris', lat: 48.86, lng: 2.35),
      _place('blank'),
      _place('nowhere', address: 'Nowhere'),
      _place('broken', address: 'Broken'),
    ];
    await pumpApp(
      tester,
      const DirectoryScreen(),
      size: const Size(1440, 900),
      overrides: [
        ...standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          directory: FakeDirectoryRepository()..cards.addAll(places),
          discoveryView: InMemoryDiscoveryViewStore()
            ..byNamespace[savedPlacesNamespaceOf(
              issuer: 'https://test.local/auth/v1',
              subject: 'user-1',
              home: 'inst-test',
            )] = DiscoveryViewPreference(
              map: true,
              acceptedProvider: MapServices.configured.identity,
            ),
        ),
        directoryGeocoderProvider.overrideWithValue(_Geocoder()),
      ],
    );
    await _frames(tester);
    expect(find.byType(DirectoryMap), findsOneWidget);
    expect(
      find.text(
        '3 workspaces could not be placed on the map; their cards are below.',
      ),
      findsOneWidget,
    );
    for (final p in places) {
      expect(
        find.byKey(ValueKey('directory-row-$_source/${p.id}')),
        findsOneWidget,
        reason: '${p.id} keeps its card',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
