// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/space_prefs_store.dart';
import '../../../core/time/clock.dart';
import '../../workspace/domain/workspace.dart';

/// The person's own layout of Me › Home (order, favourites, stars).
final spacePrefsProvider =
    AsyncNotifierProvider<SpacePrefsNotifier, SpacePrefs>(
      SpacePrefsNotifier.new,
    );

class SpacePrefsNotifier extends AsyncNotifier<SpacePrefs> {
  @override
  Future<SpacePrefs> build() => ref.watch(spacePrefsStoreProvider).read();

  SpacePrefs get _now => state.value ?? SpacePrefs.empty;

  Future<void> _set(SpacePrefs next) async {
    state = AsyncData(next);
    await ref.read(spacePrefsStoreProvider).write(next);
  }

  /// Puts [key] in or out of Favorites (the heart).
  Future<void> toggleFavorite(String key) {
    final favorites = {..._now.favorites};
    final groupOf = {..._now.groupOf};
    if (!favorites.remove(key)) {
      favorites.add(key);
      groupOf.remove(key);
    }
    return _set(_now.copyWith(favorites: favorites, groupOf: groupOf));
  }

  /// [stars] 1–5, or null to clear.
  Future<void> rate(String key, int? stars) {
    final ratings = {..._now.ratings};
    if (stars == null) {
      ratings.remove(key);
    } else {
      ratings[key] = stars.clamp(1, 5);
    }
    return _set(_now.copyWith(ratings: ratings));
  }

  /// Moves [key] one place within [shown] (the keys of its group as laid out
  /// now) and keeps that as the person's order.
  Future<void> move(List<String> shown, String key, int delta) {
    final next = _now.moved(shown, key, delta);
    return next == null
        ? Future.value()
        : _set(_now.copyWith(order: _now.withGroupOrder(next)));
  }

  /// A drag: [from] to [to] (the `onReorderItem` indexes, [to] already
  /// counted without the lifted item) within the group whose keys are [shown].
  Future<void> reorder(List<String> shown, int from, int to) {
    if (from < 0 || from >= shown.length) return Future.value();
    final next = [...shown];
    final key = next.removeAt(from);
    next.insert(to.clamp(0, next.length), key);
    return _set(_now.copyWith(order: _now.withGroupOrder(next)));
  }

  /// Puts [key] in [groupId]: Favorites, Other or one of the own groups.
  Future<void> moveToGroup(String key, String groupId) {
    final favorites = {..._now.favorites}..remove(key);
    final groupOf = {..._now.groupOf}..remove(key);
    if (groupId == SpaceGroup.favoritesGroup) {
      favorites.add(key);
    } else if (groupId != SpaceGroup.otherGroup &&
        _now.groups.any((g) => g.id == groupId)) {
      groupOf[key] = groupId;
    }
    return _set(_now.copyWith(favorites: favorites, groupOf: groupOf));
  }

  /// A new group of my own; returns its id, or null for a blank or taken name.
  Future<String?> addGroup(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _nameTaken(clean)) return null;
    final id = 'g${ref.read(clockProvider).now().microsecondsSinceEpoch}';
    await _set(_now.copyWith(groups: [..._now.groups, SpaceGroup(id, clean)]));
    return id;
  }

  /// True when a group (own, or one of the two fixed ones) already has [name].
  bool _nameTaken(String name, {String? exceptId}) {
    final low = name.toLowerCase();
    return _now.groups.any(
      (g) => g.id != exceptId && g.name.toLowerCase() == low,
    );
  }

  Future<bool> renameGroup(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _nameTaken(clean, exceptId: id)) return false;
    await _set(
      _now.copyWith(
        groups: [
          for (final g in _now.groups) g.id == id ? SpaceGroup(id, clean) : g,
        ],
      ),
    );
    return true;
  }

  /// Removes one of my groups; its spaces fall back to Other. Favorites and
  /// Other cannot be removed.
  Future<void> removeGroup(String id) => _set(
    _now.copyWith(
      groups: [for (final g in _now.groups) if (g.id != id) g],
      groupOf: {
        for (final e in _now.groupOf.entries)
          if (e.value != id) e.key: e.value,
      },
      folded: {..._now.folded}..remove(id),
    ),
  );

  Future<void> toggleFolded(String groupId) {
    final folded = {..._now.folded};
    if (!folded.remove(groupId)) folded.add(groupId);
    return _set(_now.copyWith(folded: folded));
  }

  Future<void> setSort(SpaceSort sort) => _set(_now.copyWith(sort: sort));

  /// I went into [key] just now.
  Future<void> touch(String key, DateTime at) => _set(
    _now.copyWith(
      lastUsed: {..._now.lastUsed, key: at.millisecondsSinceEpoch},
    ),
  );
}

/// The key a space's row has in [SpacePrefs]: both sides of an environment
/// pair share one.
String spaceRowKeyOf(Workspace space) =>
    space.pairId.isEmpty ? 'space:${space.id}' : 'pair:${space.pairId}';
