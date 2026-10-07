// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the spaces of Me › Home are sorted. [byHand] is the order the person
/// set themselves.
enum SpaceSort {
  byHand('hand'),
  recent('recent'),
  rating('rating'),
  alphabet('alphabet');

  const SpaceSort(this.wire);
  final String wire;

  static SpaceSort fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? byHand;
}

/// A heading that folds. [favoritesGroup] and [otherGroup] are always there
/// and cannot be removed; the rest are the person's own.
class SpaceGroup {
  const SpaceGroup(this.id, this.name);
  final String id, name;

  static const favoritesGroup = 'favorites';
  static const otherGroup = 'other';
}

/// How a person lays out their own spaces on Me › Home: the order they
/// chose, the groups they made, the ones they starred, the stars they gave
/// and when they last went in. Keyed by the space's row key (`pair:<id>` or
/// `space:<id>`), so both sides of an environment pair share one entry.
class SpacePrefs {
  const SpacePrefs({
    this.order = const [],
    this.favorites = const {},
    this.ratings = const {},
    this.groups = const [],
    this.groupOf = const {},
    this.folded = const {},
    this.lastUsed = const {},
    this.sort = SpaceSort.byHand,
  });
  static const empty = SpacePrefs();

  final List<String> order;

  /// The members of the Favorites group.
  final Set<String> favorites;
  final Map<String, int> ratings;

  /// The person's own groups, in the order they made them.
  final List<SpaceGroup> groups;

  /// The own group a space belongs to; a space not listed (or whose group
  /// is gone) is in Other.
  final Map<String, String> groupOf;

  /// The ids of the groups folded shut.
  final Set<String> folded;

  /// When a space was last entered, in milliseconds since the epoch.
  final Map<String, int> lastUsed;
  final SpaceSort sort;

  /// The group [key] sits in.
  String groupIdOf(String key) {
    if (favorites.contains(key)) return SpaceGroup.favoritesGroup;
    final own = groupOf[key];
    return own != null && groups.any((g) => g.id == own)
        ? own
        : SpaceGroup.otherGroup;
  }

  /// Every group id, in display order: Favorites, the own groups, Other.
  List<String> get groupIds => [
    SpaceGroup.favoritesGroup,
    for (final g in groups) g.id,
    SpaceGroup.otherGroup,
  ];

  /// [keys] ranked the way the person chose, then as they came.
  List<String> arrange(List<String> keys) {
    int rank(String k) {
      final i = order.indexOf(k);
      return i < 0 ? order.length : i;
    }

    final indexed = [for (var i = 0; i < keys.length; i++) (i, keys[i])];
    indexed.sort((a, b) {
      final byOrder = rank(a.$2).compareTo(rank(b.$2));
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// [keys] in the order [sort] asks for; [nameOf] names a key for the
  /// alphabet and for ties.
  List<String> sorted(List<String> keys, String Function(String) nameOf) {
    final base = arrange(keys);
    if (sort == SpaceSort.byHand) return base;
    int byName(String a, String b) =>
        nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
    final out = [...base];
    switch (sort) {
      case SpaceSort.byHand:
        break;
      case SpaceSort.alphabet:
        out.sort(byName);
      case SpaceSort.recent:
        out.sort((a, b) {
          final c = (lastUsed[b] ?? 0).compareTo(lastUsed[a] ?? 0);
          return c != 0 ? c : byName(a, b);
        });
      case SpaceSort.rating:
        out.sort((a, b) {
          final c = (ratings[b] ?? 0).compareTo(ratings[a] ?? 0);
          return c != 0 ? c : byName(a, b);
        });
    }
    return out;
  }

  /// [shown] with [key] one place [delta] (-1 up, +1 down) away, or null
  /// when it is at an end.
  List<String>? moved(List<String> shown, String key, int delta) {
    final from = shown.indexOf(key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= shown.length) return null;
    final next = [...shown];
    next[from] = shown[to];
    next[to] = shown[from];
    return next;
  }

  /// [sequence], the new order of one group, as the person's order: the
  /// other groups keep their relative places.
  List<String> withGroupOrder(List<String> sequence) => [
    for (final k in order)
      if (!sequence.contains(k)) k,
    ...sequence,
  ];

  SpacePrefs copyWith({
    List<String>? order,
    Set<String>? favorites,
    Map<String, int>? ratings,
    List<SpaceGroup>? groups,
    Map<String, String>? groupOf,
    Set<String>? folded,
    Map<String, int>? lastUsed,
    SpaceSort? sort,
  }) => SpacePrefs(
    order: order ?? this.order,
    favorites: favorites ?? this.favorites,
    ratings: ratings ?? this.ratings,
    groups: groups ?? this.groups,
    groupOf: groupOf ?? this.groupOf,
    folded: folded ?? this.folded,
    lastUsed: lastUsed ?? this.lastUsed,
    sort: sort ?? this.sort,
  );

  Map<String, Object> toJson() => {
    'order': order,
    'favorites': favorites.toList()..sort(),
    'ratings': ratings,
    'groups': [
      for (final g in groups) {'gid': g.id, 'name': g.name},
    ],
    'groupOf': groupOf,
    'folded': folded.toList()..sort(),
    'lastUsed': lastUsed,
    'sort': sort.wire,
  };

  /// A malformed store (hand-edited, an older format) reads as empty; what
  /// an older version never wrote reads as its default.
  static SpacePrefs fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final order = raw['order'];
    final favorites = raw['favorites'];
    final ratings = raw['ratings'];
    final groups = raw['groups'];
    final groupOf = raw['groupOf'];
    final folded = raw['folded'];
    final lastUsed = raw['lastUsed'];
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
      groups: [
        if (groups is List)
          for (final g in groups)
            if (g is Map &&
                g['gid'] is String &&
                g['name'] is String &&
                g['gid'] != SpaceGroup.favoritesGroup &&
                g['gid'] != SpaceGroup.otherGroup)
              SpaceGroup(g['gid'] as String, g['name'] as String),
      ],
      groupOf: {
        if (groupOf is Map)
          for (final e in groupOf.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
      },
      folded: {if (folded is List) ...folded.whereType<String>()},
      lastUsed: {
        if (lastUsed is Map)
          for (final e in lastUsed.entries)
            if (e.key is String && e.value is int) e.key as String: e.value as int,
      },
      sort: SpaceSort.fromWire(raw['sort']),
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
