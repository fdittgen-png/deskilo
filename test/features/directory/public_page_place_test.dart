// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3689 — the public-page editor stores where the business is on the map.
// The address is looked up only when the owner asks, behind the map notice;
// the match is a proposal until used; a tap on the map corrects the pin; the
// owner can remove it. Every save carries the stored pair, so an edit of
// another field keeps the pin. A lookup answers only its own request.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/application/directory_actions.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/directory_location_memory.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/public_page_editor.dart';
import 'package:deskilo/features/directory/providers/directory_location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _ws = 'ws-1';
const _found = DirectoryLocation(43.4590, 3.4230, label: 'Pézenas');

class _Geocoder implements DirectoryGeocoder {
  final asked = <String>[];
  final pending = <String, Completer<DirectoryLocation?>>{};
  bool failing = false;

  @override
  Future<DirectoryLocation?> locate(String address) async {
    asked.add(address);
    if (pending[address] case final answer?) return answer.future;
    if (failing) throw StateError('offline');
    return address.startsWith('1 Quai') ? _found : null;
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

FakeDirectoryRepository _repo({Map<String, dynamic> stored = const {}}) =>
    FakeDirectoryRepository()
      ..local['address'] = '1 Quai de la Gare'
      ..local['host_type'] = 'association'
      ..pages[_ws] = {
        'published': true,
        'document': <String, dynamic>{...stored},
      };

Map<String, dynamic> _stored(FakeDirectoryRepository repo) =>
    repo.pages[_ws]!['document'] as Map<String, dynamic>;

Future<void> _pumpEditor(
  WidgetTester tester,
  FakeDirectoryRepository repo,
  _Geocoder geocoder,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const PublicPageEditor(),
    overrides: [
      ...standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: repo,
      ),
      directoryGeocoderProvider.overrideWithValue(geocoder),
      mapTileProviderProvider.overrideWithValue(_BlankTiles()),
    ],
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _find(WidgetTester tester, {bool accept = true}) async {
  await _tap(tester, 'public-page-place-find');
  if (find
      .byKey(const ValueKey('directory-map-disclosure'))
      .evaluate()
      .isNotEmpty) {
    await tester.tap(
      _key(accept ? 'directory-map-continue' : 'directory-map-stay'),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _save(WidgetTester tester) async {
  await _tap(tester, 'public-page-editor-portal-save-preview');
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  test('the save refuses half a place and a place off the globe', () {
    const actions = PublicationActions(_NoRepo());
    for (final place in [
      {'latitude': '43.4', 'longitude': ''},
      {'latitude': '', 'longitude': '3.4'},
      {'latitude': '95', 'longitude': '3.4'},
    ]) {
      expect(
        () => actions.savePage(_ws, place, published: false),
        throwsArgumentError,
        reason: '$place',
      );
    }
  });

  testWidgets('an edit of another field keeps the stored pin', (tester) async {
    final repo = _repo(stored: {'latitude': '43.4', 'longitude': '3.4'});
    final geocoder = _Geocoder();
    await _pumpEditor(tester, repo, geocoder);
    expect(find.text('Pin at 43.40000, 3.40000'), findsOneWidget);
    await tester.enterText(
      _key('public-page-editor-text-field-description'),
      'Desks by the sea',
    );
    await _save(tester);
    expect(_stored(repo)['description'], 'Desks by the sea');
    expect(_stored(repo)['latitude'], '43.4');
    expect(_stored(repo)['longitude'], '3.4');
    expect(geocoder.asked, isEmpty);
  });

  testWidgets('staying with the list asks nothing; the found place is a '
      'proposal until used, and then saved', (tester) async {
    final repo = _repo();
    final geocoder = _Geocoder();
    await _pumpEditor(tester, repo, geocoder);
    await _find(tester, accept: false);
    expect(geocoder.asked, isEmpty, reason: 'the notice was declined');

    await _find(tester);
    expect(geocoder.asked, ['1 Quai de la Gare']);
    expect(_key('public-page-place-found'), findsOneWidget);
    expect(find.textContaining('Pézenas'), findsOneWidget);
    expect(
      find.text("No place is stored: a visitor's map looks up the address."),
      findsOneWidget,
      reason: 'a proposal is not stored yet',
    );

    await _tap(tester, 'public-page-place-use');
    await _save(tester);
    expect(_stored(repo)['latitude'], '${_found.latitude}');
    expect(_stored(repo)['longitude'], '${_found.longitude}');
  });

  testWidgets('a tap on the map corrects the pin, and the correction is '
      'what is saved', (tester) async {
    final repo = _repo();
    await _pumpEditor(tester, repo, _Geocoder());
    await _find(tester);
    await _tap(tester, 'public-page-place-use');
    final map = find.byType(FlutterMap);
    await tester.ensureVisible(map);
    await tester.tapAt(tester.getCenter(map) + const Offset(60, 40));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await _save(tester);
    final saved = publicPlaceOf(_stored(repo))!;
    expect(saved.latitude, isNot(_found.latitude));
    expect(saved.longitude, isNot(_found.longitude));
  });

  testWidgets('nothing found and a failed lookup say so; a retry recovers', (
    tester,
  ) async {
    final repo = _repo();
    final geocoder = _Geocoder()..failing = true;
    await _pumpEditor(tester, repo, geocoder);
    await _find(tester);
    expect(_key('public-page-place-failed'), findsOneWidget);
    expect(_key('public-page-place-use'), findsNothing);

    geocoder.failing = false;
    await _find(tester);
    expect(_key('public-page-place-failed'), findsNothing);
    expect(_key('public-page-place-use'), findsOneWidget);

    await tester.enterText(
      _key('public-page-editor-text-field-address'),
      'Nowhere 9',
    );
    await tester.pump();
    await _find(tester);
    expect(_key('public-page-place-not-found'), findsOneWidget);
    expect(_key('public-page-place-use'), findsNothing);
  });

  testWidgets('a late answer for an address since edited is dropped', (
    tester,
  ) async {
    final repo = _repo();
    final geocoder = _Geocoder();
    final late = geocoder.pending['1 Quai de la Gare'] =
        Completer<DirectoryLocation?>();
    await _pumpEditor(tester, repo, geocoder);
    await tester.ensureVisible(_key('public-page-place-find'));
    await tester.tap(_key('public-page-place-find'));
    await tester.pumpAndSettle();
    await tester.tap(_key('directory-map-continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(geocoder.asked, ['1 Quai de la Gare']);
    await tester.enterText(
      _key('public-page-editor-text-field-address'),
      '1 Quai de la Gare B',
    );
    await tester.pump();
    late.complete(_found);
    await tester.pumpAndSettle();
    expect(_key('public-page-place-found'), findsNothing);
    expect(_key('public-page-place-use'), findsNothing);
  });

  testWidgets('removing the place clears both coordinates', (tester) async {
    final repo = _repo(stored: {'latitude': '43.4', 'longitude': '3.4'});
    await _pumpEditor(tester, repo, _Geocoder());
    await _tap(tester, 'public-page-place-remove');
    await _save(tester);
    expect(_stored(repo)['latitude'], '');
    expect(_stored(repo)['longitude'], '');
  });

  testWidgets('from the editor to the visitor\'s map: a stored place is '
      'drawn without any lookup', (tester) async {
    final repo = _repo();
    final geocoder = _Geocoder();
    await _pumpEditor(tester, repo, geocoder);
    await _find(tester);
    await _tap(tester, 'public-page-place-use');
    await _save(tester);
    final asked = geocoder.asked.length;
    await tester.pumpWidget(const SizedBox());

    final page = PublicWorkspace(_ws, 'https://host.example', 'key', {
      'name': 'Office',
      ..._stored(repo),
    });
    await pumpApp(
      tester,
      Scaffold(
        body: DirectoryMap(
          workspaces: [page],
          selected: null,
          onSelect: (_) {},
          tileProvider: _BlankTiles(),
        ),
      ),
      overrides: [
        directoryGeocoderProvider.overrideWithValue(geocoder),
        directoryLocationMemoryProvider.overrideWithValue(
          InMemoryDirectoryLocationMemory(),
        ),
      ],
    );
    await tester.pump(const Duration(seconds: 3));
    expect(geocoder.asked.length, asked, reason: 'the stored place is used');
  });
}

class _NoRepo implements PublicationRepository {
  const _NoRepo();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('not reached');
}
