// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The saved-places store and its namespace.
//
// Invariant: the namespace names one person at one personal home and spells
// neither; the device store keeps one list per namespace under
// `saved_places.<namespace>`, round-trips a place, and clears the entry when
// the last place leaves. Nothing here holds a session or a client.
import 'package:deskilo/features/directory/data/prefs_saved_places_store.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _issuer = 'https://p.example/auth/v1';

void main() {
  test('the namespace is a digest of issuer, subject and home', () {
    final a = savedPlacesNamespaceOf(issuer: _issuer, subject: 'u', home: 'h');
    expect(a, matches(RegExp(r'^[0-9a-f]{24}$')));
    expect(a, isNot(contains('u')));
    for (final other in [
      savedPlacesNamespaceOf(issuer: _issuer, subject: 'u', home: 'h2'),
      savedPlacesNamespaceOf(issuer: _issuer, subject: 'v', home: 'h'),
      savedPlacesNamespaceOf(issuer: 'https://q.example/auth/v1',
          subject: 'u', home: 'h'),
    ]) {
      expect(other, isNot(a));
    }
  });

  test('the device store keeps one list per namespace and clears an empty '
      'one', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PrefsSavedPlacesStore();
    const card = PublicWorkspace('ws', 'https://w.example', 'key', {
      'name': 'Office',
      'address': '1 Street',
    });
    final place = SavedPlace.of(card);
    await store.write('ns-a', [place]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'saved_places.ns-a'});
    final back = await store.read('ns-a');
    expect(back.single.matches(card), isTrue);
    expect(back.single.name, 'Office');
    expect(back.single.key, 'key');
    expect(await store.read('ns-b'), isEmpty);

    await store.write('ns-a', const []);
    expect(prefs.getKeys(), isEmpty);
    expect(await store.read('ns-a'), isEmpty);
  });
}
