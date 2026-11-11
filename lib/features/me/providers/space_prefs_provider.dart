// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/space_prefs_store.dart';
import '../../../core/time/clock.dart';

/// The person's own layout of Me › Home (order, favourites, stars).
final spacePrefsProvider =
    AsyncNotifierProvider<_SpacePrefsNotifier, SpacePrefs>(
      _SpacePrefsNotifier.new,
    );

class _SpacePrefsNotifier extends AsyncNotifier<SpacePrefs> {
  @override
  Future<SpacePrefs> build() => ref.watch(spacePrefsStoreProvider).read();

  /// The stored preferences as read; only valid after [_ready].
  SpacePrefs get _now => state.requireValue;

  /// #3683 -- every change starts from what is STORED: it waits for the first
  /// read, and when that read failed it changes nothing, rather than deriving
  /// its change from an empty layout and writing that over the person's
  /// favourites, groups and order.
  Future<bool> _ready() async {
    try {
      await future;
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _set(SpacePrefs next) async {
    state = AsyncData(next);
    await ref.read(spacePrefsStoreProvider).write(next);
  }

  /// Puts [key] in or out of Favorites (the heart).
  Future<void> toggleFavorite(String key) async {
    if (!await _ready()) return;
    await setFavorite(key, on: !_now.favorites.contains(key));
  }

  /// Puts [key] in Favorites when [on], out of them otherwise; nothing is
  /// written when it is there already.
  Future<void> setFavorite(String key, {required bool on}) async {
    if (!await _ready()) return;
    if (_now.favorites.contains(key) == on) return;
    final favorites = {..._now.favorites};
    final groupOf = {..._now.groupOf};
    if (on) {
      favorites.add(key);
      groupOf.remove(key);
    } else {
      favorites.remove(key);
    }
    await _set(_now.copyWith(favorites: favorites, groupOf: groupOf));
  }

  /// [stars] 1–5, or null to clear.
  Future<void> rate(String key, int? stars) async {
    if (!await _ready()) return;
    final ratings = {..._now.ratings};
    if (stars == null) {
      ratings.remove(key);
    } else {
      ratings[key] = stars.clamp(1, 5);
    }
    await _set(_now.copyWith(ratings: ratings));
  }

  /// Moves [key] one place within [shown] (the keys of its group as laid out
  /// now) and keeps that as the person's order.
  Future<void> move(List<String> shown, String key, int delta) async {
    if (!await _ready()) return;
    final next = _now.moved(shown, key, delta);
    if (next == null) return;
    await _set(_now.copyWith(order: _now.withGroupOrder(next)));
  }

  /// A drag: [from] to [to] (the `onReorderItem` indexes, [to] already
  /// counted without the lifted item) within the group whose keys are [shown].
  Future<void> reorder(List<String> shown, int from, int to) async {
    if (!await _ready()) return;
    if (from < 0 || from >= shown.length) return;
    final next = [...shown];
    final key = next.removeAt(from);
    next.insert(to.clamp(0, next.length), key);
    await _set(_now.copyWith(order: _now.withGroupOrder(next)));
  }

  /// Puts [key] in [groupId]: Favorites, Other or one of the own groups.
  Future<void> moveToGroup(String key, String groupId) async {
    if (!await _ready()) return;
    final favorites = {..._now.favorites}..remove(key);
    final groupOf = {..._now.groupOf}..remove(key);
    if (groupId == SpaceGroup.favoritesGroup) {
      favorites.add(key);
    } else if (groupId != SpaceGroup.otherGroup &&
        _now.groups.any((g) => g.id == groupId)) {
      groupOf[key] = groupId;
    }
    await _set(_now.copyWith(favorites: favorites, groupOf: groupOf));
  }

  /// A new group of my own; returns its id, or null for a blank or taken name.
  Future<String?> addGroup(String name) async {
    if (!await _ready()) return null;
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
    if (!await _ready()) return false;
    final clean = name.trim();
    if (clean.isEmpty || _nameTaken(clean, exceptId: id)) return false;
    await _set(
      _now.copyWith(
        groups: [
          for (final g in _now.groups) if (g.id == id) SpaceGroup(id, clean) else g,
        ],
      ),
    );
    return true;
  }

  /// Removes one of my groups; its spaces fall back to Other. Favorites and
  /// Other cannot be removed.
  Future<void> removeGroup(String id) async {
    if (!await _ready()) return;
    await _set(
    _now.copyWith(
      groups: [for (final g in _now.groups) if (g.id != id) g],
      groupOf: {
        for (final e in _now.groupOf.entries)
          if (e.value != id) e.key: e.value,
      },
      folded: {..._now.folded}..remove(id),
    ),
    );
  }

  Future<void> toggleFolded(String groupId) async {
    if (!await _ready()) return;
    final folded = {..._now.folded};
    if (!folded.remove(groupId)) folded.add(groupId);
    await _set(_now.copyWith(folded: folded));
  }

  Future<void> setSort(SpaceSort sort) async {
    if (!await _ready()) return;
    await _set(_now.copyWith(sort: sort));
  }

  /// I went into [key] just now.
  Future<void> touch(String key, DateTime at) async {
    if (!await _ready()) return;
    await _set(
      _now.copyWith(
        lastUsed: {..._now.lastUsed, key: at.millisecondsSinceEpoch},
      ),
    );
  }
}
