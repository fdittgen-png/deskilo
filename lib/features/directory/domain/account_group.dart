// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Groups of people (0384): members of one workspace, several, or none.

class AccountGroupInfo {
  const AccountGroupInfo({
    required this.id,
    required this.title,
    this.description = '',
    this.announceOnly = false,
    this.memberCount = 0,
    this.iAmAdmin = false,
  });

  final String id, title, description;
  final bool announceOnly, iAmAdmin;
  final int memberCount;

  factory AccountGroupInfo.fromJson(Map<String, dynamic> j) => AccountGroupInfo(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        announceOnly: j['announce_only'] == true,
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        iAmAdmin: j['i_am_admin'] == true,
      );
}

class GroupMember {
  const GroupMember({required this.userId, required this.name, this.isAdmin = false});
  final String userId, name;
  final bool isAdmin;

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['user_id'] as String,
        name: j['name'] as String? ?? '',
        isAdmin: j['is_admin'] == true,
      );
}

/// Who a message of mine in a group reached, by name.
class GroupReach {
  const GroupReach({this.readers = const [], this.pending = const []});
  final List<({String name, DateTime readAt})> readers;
  final List<String> pending;

  factory GroupReach.fromJson(Map<String, dynamic> j) => GroupReach(
        readers: [
          for (final r in (j['readers'] as List<dynamic>? ?? const []))
            (
              name: (r as Map)['name'] as String? ?? '',
              readAt: DateTime.parse(r['read_at'] as String).toUtc(),
            ),
        ],
        pending: [
          for (final r in (j['pending'] as List<dynamic>? ?? const []))
            (r as Map)['name'] as String? ?? '',
        ],
      );
}
