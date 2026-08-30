// SPDX-License-Identifier: 0BSD
import '../../../core/calendar/calendar_item.dart';

/// One entry in the access log (#719): who read what about whom, when.
class DataAccessEntry {
  const DataAccessEntry({
    required this.id,
    required this.actorMemberId,
    required this.subjectMemberId,
    required this.category,
    required this.at,
  });

  final String id;
  final String actorMemberId;
  final String subjectMemberId;

  /// `finances` · `messages` · `export`.
  final String category;
  final DateTime at;

  factory DataAccessEntry.fromRow(Map<String, dynamic> row) => DataAccessEntry(
        id: row['id'] as String,
        actorMemberId: row['actor_member_id'] as String,
        subjectMemberId: row['subject_member_id'] as String,
        category: row['category'] as String,
        at: DateTime.parse(row['at'] as String).toUtc(),
      );
}

/// Who could look at my data, by category (#719) — member ids for the
/// categories a role grants, and a rule name for the ones every member
/// or only participants hold.
class AccessMap {
  const AccessMap({
    required this.finances,
    required this.membersAdmin,
    this.negotiations = const [],
  });

  final List<String> finances;
  final List<String> membersAdmin;

  /// #739 — who may read my price negotiations besides me.
  final List<String> negotiations;

  factory AccessMap.fromJson(Map<String, dynamic> json) => AccessMap(
        finances: [for (final id in (json['finances'] as List? ?? const [])) id as String],
        membersAdmin: [
          for (final id in (json['members_admin'] as List? ?? const [])) id as String
        ],
        negotiations: [
          for (final id in (json['negotiations'] as List? ?? const [])) id as String
        ],
      );

  static const empty = AccessMap(finances: [], membersAdmin: []);
}

/// The calendar hub's data (#718) and the GDPR self-service behind it
/// (#719). Every method's AUTHORITY is the server's: the RPCs apply the
/// access rules and write the access log; this is only the wire.
abstract class CalendarRepository {
  Future<CalendarPage> fetchItems(String workspaceId, CalendarQuery query);

  Future<AccessMap> whoCanAccessMe(String workspaceId);

  /// Rows about ME (any member), or the workspace's (manageMembers).
  Future<List<DataAccessEntry>> fetchAccessLog(String workspaceId);

  /// Art. 20 — everything I am the subject of, as one JSON document.
  Future<Map<String, dynamic>> exportMyData(String workspaceId);

  /// Art. 17 — leave the workspace and clear what may be cleared.
  Future<void> eraseMyMembership(String workspaceId);
}
