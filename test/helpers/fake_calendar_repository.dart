// SPDX-License-Identifier: 0BSD
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/domain/calendar_repository.dart';

/// In-memory [CalendarRepository] (#718). Seed [items] and [locked];
/// [fetchItems] filters by range and kinds the way `calendar_items`
/// does — the ACCESS rules stay the server's and are not re-modelled
/// here, so a test that wants a locked kind says so via [locked].
class FakeCalendarRepository implements CalendarRepository {
  final List<CalendarItem> items = [];
  Set<CalendarKind> locked = {};
  final List<CalendarQuery> queries = [];
  AccessMap accessMap = AccessMap.empty;
  final List<DataAccessEntry> log = [];
  Map<String, dynamic> export = const {};
  bool erased = false;
  Object? failure;

  @override
  Future<CalendarPage> fetchItems(String workspaceId, CalendarQuery query) async {
    if (failure != null) throw failure!;
    queries.add(query);
    final kinds = query.kinds;
    return CalendarPage(
      subjectMemberId: query.memberId ?? 'member-1',
      locked: {for (final k in locked) if (kinds == null || kinds.contains(k)) k},
      items: [
        for (final i in items)
          if (!i.at.isBefore(query.from) &&
              i.at.isBefore(query.to) &&
              (kinds == null || kinds.contains(i.kind)) &&
              !locked.contains(i.kind) &&
              (query.memberId == null || i.memberId == query.memberId))
            i,
      ]..sort((a, b) => a.at.compareTo(b.at)),
    );
  }

  @override
  Future<AccessMap> whoCanAccessMe(String workspaceId) async => accessMap;

  @override
  Future<List<DataAccessEntry>> fetchAccessLog(String workspaceId) async =>
      List.of(log);

  @override
  Future<Map<String, dynamic>> exportMyData(String workspaceId) async => export;

  @override
  Future<void> eraseMyMembership(String workspaceId) async {
    erased = true;
  }
}
