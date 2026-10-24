// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The wide list/map split and the camera the person moved (#2555,
// DISC-06).
//
// Invariant: once the map was chosen, a window where both panes keep
// 330 px shows the loaded list beside the map at 53:47, and a narrower one
// shows one view at a time; without the map chosen there is no map at any
// width. A place selected on the map is selected and scrolled into view in
// the list, and Locate on a card selects its pin. A manual pan or zoom is
// kept when more places load and when the window crosses the split width;
// only "Show all loaded places" (or Locate) moves the camera again, and it
// fits every loaded place.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/directory_row.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/presentation/discovery_split.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _source = 'https://host.example';

PublicWorkspace _place(String id, {double? lat, double? lng}) =>
    PublicWorkspace(id, _source, 'sb_publishable_test', {
      'name': 'Office $id',
      'latitude': ?lat?.toString(),
      'longitude': ?lng?.toString(),
    });

class _NoGeocoder implements DirectoryGeocoder {
  @override
  Future<DirectoryLocation?> locate(String address) async => null;
}

InMemoryDiscoveryViewStore _mapChosen() => InMemoryDiscoveryViewStore()
  ..byNamespace[savedPlacesNamespaceOf(
    issuer: 'https://test.local/auth/v1',
    subject: 'user-1',
    home: 'inst-test',
  )] = DiscoveryViewPreference(
    map: true,
    acceptedProvider: MapServices.configured.identity,
  );

Future<void> _show(
  WidgetTester tester, {
  required Size size,
  required FakeDirectoryRepository directory,
  InMemoryDiscoveryViewStore? store,
}) async {
  await pumpApp(
    tester,
    const DirectoryScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: directory,
        discoveryView: store ?? _mapChosen(),
      ),
      directoryGeocoderProvider.overrideWithValue(_NoGeocoder()),
    ],
  );
  await _frames(tester);
}

/// Frames enough for a camera glide, without waiting for the map's tiles
/// to fall idle.
Future<void> _frames(WidgetTester tester) async {
  for (final wait in const [Duration.zero, Duration(seconds: 1)]) {
    await tester.pump(wait);
    await tester.pump(wait);
  }
}

MapCamera _camera(WidgetTester tester) =>
    MapController.of(tester.element(find.byType(TileLayer))).camera;

Finder _row(String id) => find.byKey(ValueKey('directory-row-$_source/$id'));

bool _rowSelected(WidgetTester tester, String id) => tester
    .widget<DirectoryRow>(
      find.ancestor(of: _row(id), matching: find.byType(DirectoryRow)),
    )
    .selected;

void main() {
  test('the split needs 330 px for each pane at 53:47', () {
    expect(DiscoverySplit.listFlex, 53);
    expect(DiscoverySplit.mapFlex, 47);
    expect(DiscoverySplit.minPane, 330);
    expect(DiscoverySplit.fits(320), isFalse);
    expect(DiscoverySplit.fits(390), isFalse);
    expect(DiscoverySplit.fits(702), isFalse);
    expect(DiscoverySplit.fits(703), isTrue);
    expect(DiscoverySplit.fits(840), isTrue);
    expect(DiscoverySplit.fits(1440), isTrue);
  });

  testWidgets('wide, the list sits beside the map at 53:47; compact, the map '
      'is one view; without the map chosen there is no map at all', (
    tester,
  ) async {
    final directory = FakeDirectoryRepository()
      ..cards.add(_place('a', lat: 48.86, lng: 2.35));
    await _show(tester, size: const Size(1200, 800), directory: directory);
    expect(find.byKey(const ValueKey('directory-split')), findsOneWidget);
    expect(_row('a'), findsOneWidget);
    expect(find.byType(DirectoryMap), findsOneWidget);
    final list = tester.getSize(find.byType(DirectoryMap)).width;
    final whole = tester.getSize(find.byKey(const ValueKey('directory-split')));
    expect(list / whole.width, closeTo(.47, .01));

    await tester.pumpWidget(const SizedBox.shrink());
    await _show(tester, size: const Size(390, 800), directory: directory);
    expect(find.byKey(const ValueKey('directory-split')), findsNothing);
    expect(find.byType(DirectoryMap), findsOneWidget);
    expect(find.byKey(const ValueKey('directory-carousel')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _show(
      tester,
      size: const Size(1200, 800),
      directory: directory,
      store: InMemoryDiscoveryViewStore(),
    );
    expect(find.byKey(const ValueKey('directory-split')), findsNothing);
    expect(find.byType(DirectoryMap), findsNothing);
    expect(_row('a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pin selects its card and scrolls it into view; Locate on a '
      'card selects its pin', (tester) async {
    final directory = FakeDirectoryRepository()
      ..cards.addAll([
        _place('first', lat: 48.86, lng: 2.35),
        for (var i = 0; i < 18; i++) _place('row-$i'),
        _place('last', lat: 43.61, lng: 3.88),
      ]);
    await _show(tester, size: const Size(1200, 800), directory: directory);
    expect(_row('last'), findsNothing, reason: 'below the fold, not built');

    await tester.tap(
      find.byKey(const ValueKey('directory-pin-$_source/last-tap')),
    );
    await _frames(tester);
    expect(_row('last'), findsOneWidget);
    expect(_rowSelected(tester, 'last'), isTrue);
    final pane = tester.getRect(find.byKey(const ValueKey('directory-split')));
    final row = tester.getRect(_row('last'));
    expect(row.top, greaterThanOrEqualTo(pane.top));
    expect(row.bottom, lessThanOrEqualTo(pane.bottom));

    await tester.tap(
      find.byKey(const ValueKey('directory-portal-search')),
    ); // a new search clears the selection
    await _frames(tester);
    expect(
      tester.widget<DirectoryMap>(find.byType(DirectoryMap)).selected,
      isNull,
    );
    expect(_rowSelected(tester, 'last'), isFalse);
    await tester.tap(
      find.byKey(const ValueKey('directory-locate-$_source/last')),
    );
    await _frames(tester);
    expect(
      tester.widget<DirectoryMap>(find.byType(DirectoryMap)).selected,
      '$_source/last',
    );
    expect(_rowSelected(tester, 'last'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manual pan holds through new pages and a resize; Show all '
      'loaded places fits every place again (DISC-06)', (tester) async {
    final directory = FakeDirectoryRepository()
      ..pageSize = 1
      ..cards.addAll([
        _place('paris', lat: 48.86, lng: 2.35),
        _place('montpellier', lat: 43.61, lng: 3.88),
      ]);
    await _show(tester, size: const Size(1200, 800), directory: directory);
    expect(
      _camera(tester).center.latitude,
      closeTo(48.86, .001),
      reason: 'the first fit is allowed',
    );

    await tester.drag(find.byType(FlutterMap), const Offset(-120, 90));
    await _frames(tester);
    final moved = _camera(tester).center;
    expect(moved.latitude, isNot(closeTo(48.86, .001)));

    await tester.tap(
      find.byKey(const ValueKey('directory-source-more-$_source')),
    );
    await _frames(tester);
    expect(_row('montpellier'), findsOneWidget);
    expect(_camera(tester).center, moved, reason: 'a new page never snaps');

    tester.view.physicalSize = const Size(390, 800);
    await _frames(tester);
    expect(find.byKey(const ValueKey('directory-split')), findsNothing);
    expect(
      _camera(tester).center.latitude,
      closeTo(moved.latitude, .0001),
      reason: 'the same map, the same camera, across the split width',
    );

    await tester.tap(find.byKey(const ValueKey('directory-map-show-all')));
    await _frames(tester);
    final all = _camera(tester).visibleBounds;
    expect(all.contains(const LatLng(48.86, 2.35)), isTrue);
    expect(all.contains(const LatLng(43.61, 3.88)), isTrue);
    expect(tester.takeException(), isNull);
  });
}
