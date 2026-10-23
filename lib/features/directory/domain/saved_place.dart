// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A public page a person keeps for themselves, on this device only.
//
// Saving is none of the other things a person can do with a space: not
// joining it, not contacting it, not the membership heart or the rating,
// and not a publication. The store therefore lives on the device, never
// on a server, and is keyed by the person at their personal home, so two
// accounts on one device never see each other's saved places and the
// same person keeps theirs whichever workspace they open.
import '../../../core/cache/cache_scope.dart';
import '../../../core/data/json_reader.dart';
import 'public_workspace.dart';

/// A saved reference to a public page: its source installation and the
/// workspace's id there, with the name and address the card showed when
/// it was saved. The reference outlives an unpublication; the snapshot is
/// only a label, never presented as the page's current content.
class SavedPlace {
  const SavedPlace({
    required this.source,
    required this.key,
    required this.id,
    required this.name,
    required this.address,
  });

  factory SavedPlace.of(PublicWorkspace workspace) => SavedPlace(
        source: workspace.source,
        key: workspace.key,
        id: workspace.id,
        name: workspace.name,
        address: workspace.text('address'),
      );

  factory SavedPlace.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'saved_place');
    return SavedPlace(
      source: r.string('source'),
      key: r.stringOr('key'),
      id: r.string('id'),
      name: r.stringOr('name'),
      address: r.stringOr('address'),
    );
  }

  final String source, key, id, name, address;

  Map<String, String> toJson() => {
        'source': source,
        'key': key,
        'id': id,
        'name': name,
        'address': address,
      };

  /// Whether this is [workspace]'s page: same installation, same id there.
  bool matches(PublicWorkspace workspace) =>
      workspace.source == source && workspace.id == id;
}

/// The device-local store of saved places, one list per [namespace].
abstract interface class SavedPlacesStore {
  Future<List<SavedPlace>> read(String namespace);

  /// Replaces the list; an empty list clears the entry.
  Future<void> write(String namespace, List<SavedPlace> places);
}

/// The namespace of one person at one personal home: a digest of the
/// canonical identity (issuer and subject) and the home installation, so
/// the key names neither, and a selected workspace plays no part in it.
String savedPlacesNamespaceOf({
  required String issuer,
  required String subject,
  required String home,
}) => cacheDigest('saved_places_v1', [issuer, subject, home], 24);

/// In-memory [SavedPlacesStore]: what tests and a Demo session hold instead
/// of the device's preferences. [byNamespace] is readable so a test can
/// prove under which key a place was written.
class InMemorySavedPlacesStore implements SavedPlacesStore {
  final Map<String, List<SavedPlace>> byNamespace = {};

  @override
  Future<List<SavedPlace>> read(String namespace) async =>
      List.unmodifiable(byNamespace[namespace] ?? const <SavedPlace>[]);

  @override
  Future<void> write(String namespace, List<SavedPlace> places) async {
    if (places.isEmpty) {
      byNamespace.remove(namespace);
    } else {
      byNamespace[namespace] = List.of(places);
    }
  }
}
