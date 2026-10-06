// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/space_prefs_store.dart';

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

  Future<void> toggleFavorite(String key) {
    final favorites = {..._now.favorites};
    if (!favorites.remove(key)) favorites.add(key);
    return _set(_now.copyWith(favorites: favorites));
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

  /// Moves [key] one place within [shown] (the keys as laid out now) and
  /// keeps the whole layout as the person's order.
  Future<void> move(List<String> shown, String key, int delta) {
    final next = _now.moved(shown, key, delta);
    return next == null ? Future.value() : _set(_now.copyWith(order: next));
  }
}
