// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2185 — a member's favourite mark and 0-5 star rating of a bookable place
// (a seat, a desk, an office or a level), and the place's average.

/// What a mark or a rating is about: any resource but a person — a seat, a
/// desk, an office, a level, a service, an accessory, or a whole workspace.
enum PlaceKind {
  seat,
  desk,
  office,
  level,
  service,
  accessory,
  workspace;

  String get wireName => name;
}

/// A place's feedback as the person sees it: whether they favourited it, the
/// average of everybody's ratings and how many there are, and their own.
class PlaceFeedback {
  const PlaceFeedback({
    this.favorite = false,
    this.average,
    this.count = 0,
    this.mine,
  });

  factory PlaceFeedback.fromJson(Map<String, dynamic> json) => PlaceFeedback(
        favorite: json['favorite'] as bool? ?? false,
        average: (json['average'] as num?)?.toDouble(),
        count: (json['count'] as num?)?.toInt() ?? 0,
        mine: (json['mine'] as num?)?.toInt(),
      );

  final bool favorite;
  final double? average;
  final int count;

  /// 0 to 5 stars, or null when the person has not rated it.
  final int? mine;

  @override
  bool operator ==(Object other) =>
      other is PlaceFeedback &&
      other.favorite == favorite &&
      other.average == average &&
      other.count == count &&
      other.mine == mine;

  @override
  int get hashCode => Object.hash(favorite, average, count, mine);
}

/// A favourite place with its label.
class FavoritePlace {
  const FavoritePlace({
    required this.kind,
    required this.id,
    required this.label,
    required this.feedback,
  });

  final PlaceKind kind;
  final String id;
  final String label;
  final PlaceFeedback feedback;
}

abstract interface class PlaceFeedbackRepository {
  Future<PlaceFeedback> fetch(String workspaceId, PlaceKind kind, String id);

  /// Several places of one kind at once (a list on screen): one request.
  Future<Map<String, PlaceFeedback>> fetchMany(
      String workspaceId, PlaceKind kind, List<String> ids);

  Future<PlaceFeedback> setFavorite(
      String workspaceId, PlaceKind kind, String id, {required bool on});

  /// 0-5 stars; null takes the rating back.
  Future<PlaceFeedback> setRating(
      String workspaceId, PlaceKind kind, String id, int? stars);

  Future<List<FavoritePlace>> favorites(String workspaceId);
}
