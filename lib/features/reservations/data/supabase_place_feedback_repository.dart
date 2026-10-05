// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — favourites and ratings through the server's own definers
// (0374): `place_feedback_of`, `set_favorite`, `set_rating`, `my_favorites`.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/place_feedback.dart';

class SupabasePlaceFeedbackRepository implements PlaceFeedbackRepository {
  const SupabasePlaceFeedbackRepository(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  @override
  Future<PlaceFeedback> fetch(
      String workspaceId, PlaceKind kind, String id) async {
    if (kind == PlaceKind.workspace) {
      final answer = await _client
          .rpc<dynamic>('workspace_feedback_of', params: {'p_ids': [id]});
      final mine = _map(answer)[id];
      return mine == null ? const PlaceFeedback() : PlaceFeedback.fromJson(_map(mine));
    }
    final answer = await _client.rpc<dynamic>('place_feedback_of', params: {
      'p_workspace': workspaceId,
      'p_kind': kind.wireName,
      'p_ids': [id],
    });
    final map = _map(answer);
    final mine = map[id];
    return mine == null ? const PlaceFeedback() : PlaceFeedback.fromJson(_map(mine));
  }

  @override
  Future<Map<String, PlaceFeedback>> fetchMany(
      String workspaceId, PlaceKind kind, List<String> ids) async {
    final answer = kind == PlaceKind.workspace
        ? await _client.rpc<dynamic>('workspace_feedback_of', params: {'p_ids': ids})
        : await _client.rpc<dynamic>('place_feedback_of', params: {
            'p_workspace': workspaceId,
            'p_kind': kind.wireName,
            'p_ids': ids,
          });
    final map = _map(answer);
    return {
      for (final id in ids)
        id: map[id] == null ? const PlaceFeedback() : PlaceFeedback.fromJson(_map(map[id])),
    };
  }

  @override
  Future<PlaceFeedback> setFavorite(
      String workspaceId, PlaceKind kind, String id,
      {required bool on}) async {
    if (kind == PlaceKind.workspace) {
      final answer = await _client.rpc<dynamic>('set_workspace_favorite',
          params: {'p_workspace': id, 'p_on': on});
      return PlaceFeedback.fromJson(_map(answer));
    }
    final answer = await _client.rpc<dynamic>('set_favorite', params: {
      'p_workspace': workspaceId,
      'p_kind': kind.wireName,
      'p_resource': id,
      'p_on': on,
    });
    return PlaceFeedback.fromJson(_map(answer));
  }

  @override
  Future<PlaceFeedback> setRating(
      String workspaceId, PlaceKind kind, String id, int? stars) async {
    if (kind == PlaceKind.workspace) {
      final answer = await _client.rpc<dynamic>('set_workspace_rating',
          params: {'p_workspace': id, 'p_stars': stars});
      return PlaceFeedback.fromJson(_map(answer));
    }
    final answer = await _client.rpc<dynamic>('set_rating', params: {
      'p_workspace': workspaceId,
      'p_kind': kind.wireName,
      'p_resource': id,
      'p_stars': stars,
    });
    return PlaceFeedback.fromJson(_map(answer));
  }

  @override
  Future<List<FavoritePlace>> favorites(String workspaceId) async {
    final answer = await _client
        .rpc<dynamic>('my_favorites', params: {'p_workspace': workspaceId});
    return [
      for (final row in answer as List)
        FavoritePlace(
          kind: PlaceKind.values.asNameMap()['${_map(row)['kind']}'] ??
              PlaceKind.seat,
          id: '${_map(row)['resource_id']}',
          label: '${_map(row)['label'] ?? ''}',
          feedback: PlaceFeedback.fromJson(_map(_map(row)['rating'])),
        ),
    ];
  }
}
