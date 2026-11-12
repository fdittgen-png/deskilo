// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3684 -- the Discover map says what it could not do, and asks the public
// geocoder patiently.
//
// Invariants:
// - A background that does not load is one line over the map with Try
//   again, which asks for every tile again; a single missing tile says
//   nothing.
// - A lookup that fails or is refused is counted as "could not be looked
//   up", apart from "has no address", with Try again for all of them; a
//   retry that succeeds places the pin.
// - Lookups go out one at a time, the courtesy pause between them; a
//   found place is remembered on the device, so the next visit asks
//   nothing. A place with stored coordinates is never looked up, and a
//   place without an address does not use up the bounded lookups.
// - Nothing to pin is a sentence in place of the map, not a continent.
// - The labelled List | Map switch opens the notice, then the map, at
//   phone width; a map that cannot be opened says so.
import 'dart:convert';

import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/data/directory_lookups.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/directory_location_memory.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:deskilo/features/directory/providers/discovery_view_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// How long an answer takes, on the test's fake clock: long enough for two
/// requests to overlap if the queue let them.
const _answerTime = Duration(milliseconds: 200);

/// Answers after [_answerTime]; "Broken" fails until [healed]; "Nowhere"
/// is not found. Records every request and how many overlapped.
class _Geocoder implements DirectoryGeocoder {
  final asked = <String>[];
  int inFlight = 0;
  int mostInFlight = 0;
  bool healed = false;

  @override
  Future<DirectoryLocation?> locate(String address) async {
    asked.add(address);
    inFlight++;
    if (inFlight > mostInFlight) mostInFlight = inFlight;
    try {
      await Future<void>.delayed(_answerTime);
      if (address.startsWith('Broken') && !healed) {
        throw StateError('Address lookup unavailable');
      }
      if (address == 'Nowhere') return null;
      // Evenly apart on a line from Paris, so no two pins fold together.
      final n = asked.length;
      return DirectoryLocation(48.86 - 4.0 * n, 2.35 + 4.0 * n, label: address);
    } finally {
      inFlight--;
    }
  }
}

final _blank = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
);

/// A tile that never loads.
class _FailingImage extends ImageProvider<_FailingImage> {
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('tile server unavailable')),
  );
}

class _Tiles extends TileProvider {
  _Tiles({this.failing = true});
  bool failing;
  int asked = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    asked++;
    return failing ? _FailingImage() : MemoryImage(_blank);
  }
}

Future<void> _showMap(
  WidgetTester tester,
  List<PublicWorkspace> places, {
  required _Geocoder geocoder,
  DirectoryLocationMemory? memory,
  TileProvider? tiles,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: DirectoryMap(
        workspaces: places,
        selected: null,
        onSelect: (_) {},
        tileProvider: tiles ?? _Tiles(failing: false),
      ),
    ),
    overrides: [
      directoryGeocoderProvider.overrideWithValue(geocoder),
      directoryLocationMemoryProvider.overrideWithValue(
        memory ?? InMemoryDirectoryLocationMemory(),
      ),
    ],
  );
  await _frames(tester);
}

Future<void> _frames(WidgetTester tester) async {
  for (final wait in const [Duration.zero, Duration(milliseconds: 500)]) {
    await tester.pump(wait);
    await tester.pump(wait);
  }
}

/// Every queued lookup with its courtesy pause.
Future<void> _settleLookups(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(DirectoryLookups.courtesyPause);
  }
  await _frames(tester);
}

Finder _pin(String id) => find.byKey(ValueKey('directory-pin-$_source/$id'));

void main() {
  testWidgets('a background that does not load says so once, and Try again '
      'asks for every tile again', (tester) async {
    final tiles = _Tiles();
    await _showMap(
      tester,
      [_place('paris', lat: 48.86, lng: 2.35)],
      geocoder: _Geocoder(),
      tiles: tiles,
    );
    expect(
      find.text('The map background could not be loaded.'),
      findsOneWidget,
    );
    final before = tiles.asked;

    tiles.failing = false;
    await tester.tap(find.byKey(const ValueKey('directory-map-tiles-retry')));
    await _frames(tester);
    expect(tiles.asked, greaterThan(before));
    expect(find.text('The map background could not be loaded.'), findsNothing);
    expect(_pin('paris'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused lookup is counted apart from a missing address, '
      'and Try again places the pin', (tester) async {
    final geocoder = _Geocoder();
    await _showMap(tester, [
      _place('paris', lat: 48.86, lng: 2.35),
      _place('blank'),
      _place('broken', address: 'Broken road'),
    ], geocoder: geocoder);
    await _settleLookups(tester, 1);
    expect(
      find.text(
        '2 places could not be put on the map; their cards are below.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 has no published address.'), findsOneWidget);
    expect(find.text('1 could not be looked up.'), findsOneWidget);
    expect(_pin('broken'), findsNothing);

    geocoder.healed = true;
    await tester.tap(find.byKey(const ValueKey('directory-pins-retry')));
    await _settleLookups(tester, 2);
    expect(geocoder.asked, ['Broken road', 'Broken road']);
    expect(find.text('1 could not be looked up.'), findsNothing);
    expect(
      find.text(
        '1 place could not be put on the map; its card is below.',
      ),
      findsOneWidget,
      reason: 'only the place without an address is left',
    );
    expect(find.byKey(const ValueKey('directory-pins-retry')), findsNothing);
    expect(_pin('broken'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lookups go out one at a time, paused; the next visit asks '
      'nothing again; stored coordinates are never looked up', (tester) async {
    final memory = InMemoryDirectoryLocationMemory();
    final places = [
      _place('stored', address: 'Stored street', lat: 48.86, lng: 2.35),
      _place('a', address: 'Street A'),
      _place('b', address: '  street   B '),
      _place('c', address: 'Street C'),
    ];
    final first = _Geocoder();
    await _showMap(tester, places, geocoder: first, memory: memory);
    expect(first.asked, ['Street A'], reason: 'the next waits its turn');
    await tester.pump(DirectoryLookups.courtesyPause);
    expect(first.asked, ['Street A', 'street   B']);
    await _settleLookups(tester, 3);
    expect(first.asked, ['Street A', 'street   B', 'Street C']);
    expect(first.mostInFlight, 1, reason: 'never two at once');
    for (final id in ['stored', 'a', 'b', 'c']) {
      expect(_pin(id), findsOneWidget, reason: id);
    }
    expect(memory.saved.keys, ['street a', 'street b', 'street c']);

    // Another visit on this device: the remembered places, no request.
    await tester.pumpWidget(const SizedBox.shrink());
    final second = _Geocoder();
    await _showMap(tester, places, geocoder: second, memory: memory);
    expect(second.asked, isEmpty);
    for (final id in ['stored', 'a', 'b', 'c']) {
      expect(_pin(id), findsOneWidget, reason: id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('places without an address do not use up the bounded '
      'lookups', (tester) async {
    final distinct = _Geocoder();
    await _showMap(tester, [
      for (var i = 0; i < 5; i++) _place('blank-$i'),
      for (var i = 0; i < 20; i++) _place('street-$i', address: 'Street $i'),
    ], geocoder: distinct);
    // Each answer takes 200 ms, then the pause: 24 s for twenty.
    await _settleLookups(tester, 25);
    expect(distinct.asked, hasLength(20), reason: 'all twenty addresses');
    expect(distinct.mostInFlight, 1);
    expect(
      find.text(
        '5 places could not be put on the map; their cards are below.',
      ),
      findsOneWidget,
      reason: 'the five without an address, none deferred',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing to pin is a sentence in place of the map', (
    tester,
  ) async {
    await _showMap(tester, [
      _place('blank'),
      _place('broken', address: 'Broken road'),
    ], geocoder: _Geocoder());
    await _settleLookups(tester, 1);
    expect(
      find.text('None of these places could be placed on the map.'),
      findsOneWidget,
    );
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('directory-pins-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the List | Map switch', () {
    Future<void> showScreen(
      WidgetTester tester, {
      required Size size,
      InMemoryDiscoveryViewStore? store,
      List<Override> extra = const [],
    }) async {
      await pumpApp(
        tester,
        const DirectoryScreen(),
        size: size,
        overrides: [
          ...standardTestOverrides(
            auth: FakeAuthRepository.signedIn(),
            directory: FakeDirectoryRepository()
              ..cards.add(_place('paris', lat: 48.86, lng: 2.35)),
            discoveryView: store ?? InMemoryDiscoveryViewStore(),
          ),
          directoryGeocoderProvider.overrideWithValue(_Geocoder()),
          ...extra,
        ],
      );
      await _frames(tester);
    }

    final toggle = find.byKey(const ValueKey('directory-view-switch'));
    Finder side(String label) =>
        find.descendant(of: toggle, matching: find.text(label));

    testWidgets('at 390 px, Map opens the notice, then the map; List goes '
        'back', (tester) async {
      await showScreen(tester, size: const Size(390, 800));
      expect(side('List'), findsOneWidget);
      expect(side('Map'), findsOneWidget);
      await tester.tap(side('Map'));
      await _frames(tester);
      expect(
        find.byKey(const ValueKey('directory-map-disclosure')),
        findsOneWidget,
      );
      expect(find.byType(DirectoryMap), findsNothing);
      await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsOneWidget);
      await tester.tap(side('List'));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 320 px it fits beside the other actions', (tester) async {
      await showScreen(tester, size: const Size(320, 640));
      expect(side('Map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // #3689 — a desktop window: the notice, then the map beside the list.
    testWidgets('at 1280 px Map opens the notice, then the map', (
      tester,
    ) async {
      await showScreen(tester, size: const Size(1280, 800));
      await tester.tap(side('Map'));
      await _frames(tester);
      expect(
        find.byKey(const ValueKey('directory-map-disclosure')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
      await _frames(tester);
      expect(find.byType(DirectoryMap), findsOneWidget);
      expect(tester.getRect(find.byType(DirectoryMap)).right,
          lessThanOrEqualTo(1280));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a map that cannot be opened says so', (tester) async {
      await showScreen(
        tester,
        size: const Size(390, 800),
        extra: [discoveryViewProvider.overrideWith(_FailingView.new)],
      );
      await tester.tap(side('Map'));
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
      await _frames(tester);
      expect(find.text('The map could not be opened.'), findsOneWidget);
      expect(find.byType(DirectoryMap), findsNothing);
    });

    testWidgets('a map the view refuses to show says so', (tester) async {
      final store = InMemoryDiscoveryViewStore()
        ..byNamespace[savedPlacesNamespaceOf(
          issuer: 'https://test.local/auth/v1',
          subject: 'user-1',
          home: 'inst-test',
        )] = DiscoveryViewPreference(
          acceptedProvider: MapServices.configured.identity,
        );
      await showScreen(
        tester,
        size: const Size(390, 800),
        store: store,
        extra: [discoveryViewProvider.overrideWith(_RefusingView.new)],
      );
      await tester.tap(side('Map'));
      await _frames(tester);
      expect(find.text('The map could not be opened.'), findsOneWidget);
    });
  });
}

/// The view's store fails while the map is accepted.
class _FailingView extends DiscoveryView {
  @override
  Future<void> acceptMap({bool show = true}) async =>
      throw StateError('store unavailable');
}

/// The view will not show the map.
class _RefusingView extends DiscoveryView {
  @override
  Future<bool> show({required bool map}) async => !map;
}
