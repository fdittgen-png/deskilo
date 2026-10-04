// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — favourites and ratings in memory, for Demo and the test suite.
import 'package:deskilo/features/reservations/domain/place_feedback.dart';

class FakePlaceFeedbackRepository implements PlaceFeedbackRepository {
  final Set<String> _favorites = {};
  final Map<String, int> _mine = {};

  /// What everybody else gave, by place: a test seeds it.
  final Map<String, List<int>> others = {};

  String _key(PlaceKind kind, String id) => '${kind.name}:$id';

  PlaceFeedback _feedback(PlaceKind kind, String id) {
    final key = _key(kind, id);
    final all = [...?others[key], if (_mine[key] != null) _mine[key]!];
    return PlaceFeedback(
      favorite: _favorites.contains(key),
      average: all.isEmpty ? null : all.reduce((a, b) => a + b) / all.length,
      count: all.length,
      mine: _mine[key],
    );
  }

  @override
  Future<PlaceFeedback> fetch(String workspaceId, PlaceKind kind, String id) async =>
      _feedback(kind, id);

  @override
  Future<PlaceFeedback> setFavorite(
      String workspaceId, PlaceKind kind, String id,
      {required bool on}) async {
    on ? _favorites.add(_key(kind, id)) : _favorites.remove(_key(kind, id));
    return _feedback(kind, id);
  }

  @override
  Future<PlaceFeedback> setRating(
      String workspaceId, PlaceKind kind, String id, int? stars) async {
    stars == null ? _mine.remove(_key(kind, id)) : _mine[_key(kind, id)] = stars;
    return _feedback(kind, id);
  }

  @override
  Future<List<FavoritePlace>> favorites(String workspaceId) async {
    PlaceKind kindOf(String key) =>
        PlaceKind.values.asNameMap()[key.split(':').first] ?? PlaceKind.seat;
    return [
      for (final key in _favorites)
        FavoritePlace(
          kind: kindOf(key),
          id: key.split(':').last,
          label: key,
          feedback: _feedback(kindOf(key), key.split(':').last),
        ),
    ];
  }
}
