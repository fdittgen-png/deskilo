// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a person lays out their own spaces on Me › Home: the order they
/// chose, the ones they starred and the stars they gave. Keyed by the
/// space's row key (`pair:<id>` or `space:<id>`), so both sides of an
/// environment pair share one entry.
class SpacePrefs {
  const SpacePrefs({
    this.order = const [],
    this.favorites = const {},
    this.ratings = const {},
  });
  static const empty = SpacePrefs();

  final List<String> order;
  final Set<String> favorites;
  final Map<String, int> ratings;

  /// [keys] as the person lays them out: favourites first, then the order
  /// they chose; keys they never placed keep the order they came in.
  List<String> arrange(List<String> keys) {
    int rank(String k) {
      final i = order.indexOf(k);
      return i < 0 ? order.length : i;
    }

    final indexed = [for (var i = 0; i < keys.length; i++) (i, keys[i])];
    indexed.sort((a, b) {
      final fav =
          (favorites.contains(b.$2) ? 1 : 0) -
          (favorites.contains(a.$2) ? 1 : 0);
      if (fav != 0) return fav;
      final byOrder = rank(a.$2).compareTo(rank(b.$2));
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// [shown] with [key] one place [delta] (-1 up, +1 down) away, or null
  /// when it cannot move: at an end, or against a favourite boundary.
  List<String>? moved(List<String> shown, String key, int delta) {
    final from = shown.indexOf(key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= shown.length) return null;
    if (favorites.contains(shown[from]) != favorites.contains(shown[to])) {
      return null;
    }
    final next = [...shown];
    next[from] = shown[to];
    next[to] = shown[from];
    return next;
  }

  SpacePrefs copyWith({
    List<String>? order,
    Set<String>? favorites,
    Map<String, int>? ratings,
  }) => SpacePrefs(
    order: order ?? this.order,
    favorites: favorites ?? this.favorites,
    ratings: ratings ?? this.ratings,
  );

  Map<String, Object> toJson() => {
    'order': order,
    'favorites': favorites.toList()..sort(),
    'ratings': ratings,
  };

  /// A malformed store (hand-edited, an older format) reads as empty.
  static SpacePrefs fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final order = raw['order'];
    final favorites = raw['favorites'];
    final ratings = raw['ratings'];
    return SpacePrefs(
      order: [if (order is List) ...order.whereType<String>()],
      favorites: {if (favorites is List) ...favorites.whereType<String>()},
      ratings: {
        if (ratings is Map)
          for (final e in ratings.entries)
            if (e.key is String &&
                e.value is int &&
                (e.value as int) >= 1 &&
                (e.value as int) <= 5)
              e.key as String: e.value as int,
      },
    );
  }
}

/// Per-device persistence of [SpacePrefs]; widget tests swap in the
/// in-memory store.
abstract class SpacePrefsStore {
  Future<SpacePrefs> read();
  Future<void> write(SpacePrefs prefs);
}

class PrefsSpacePrefsStore implements SpacePrefsStore {
  const PrefsSpacePrefsStore();
  static const _key = 'space_prefs';

  @override
  Future<SpacePrefs> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return SpacePrefs.empty;
    try {
      return SpacePrefs.fromJson(jsonDecode(raw));
    } on FormatException {
      return SpacePrefs.empty;
    }
  }

  @override
  Future<void> write(SpacePrefs prefs) async {
    final store = await SharedPreferences.getInstance();
    await store.setString(_key, jsonEncode(prefs.toJson()));
  }
}

class InMemorySpacePrefsStore implements SpacePrefsStore {
  SpacePrefs prefs = SpacePrefs.empty;

  @override
  Future<SpacePrefs> read() async => prefs;

  @override
  Future<void> write(SpacePrefs next) async => prefs = next;
}

final spacePrefsStoreProvider = Provider<SpacePrefsStore>(
  (ref) => const PrefsSpacePrefsStore(),
);
