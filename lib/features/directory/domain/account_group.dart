// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Groups of people (0384): members of one workspace, several, or none.

import '../../../core/data/json_reader.dart';

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

  factory AccountGroupInfo.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'account_group');
    return AccountGroupInfo(
      id: r.string('id'),
      title: r.stringOr('title'),
      description: r.stringOr('description'),
      announceOnly: r.boolOr('announce_only', fallback: false),
      memberCount: r.intOrNull('member_count') ?? 0,
      iAmAdmin: r.boolOr('i_am_admin', fallback: false),
    );
  }
}

class GroupMember {
  const GroupMember({required this.userId, required this.name, this.isAdmin = false});
  final String userId, name;
  final bool isAdmin;

  factory GroupMember.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'group_member');
    return GroupMember(
      userId: r.string('user_id'),
      name: r.stringOr('name'),
      isAdmin: r.boolOr('is_admin', fallback: false),
    );
  }
}

/// Who a message of mine in a group reached, by name.
class GroupReach {
  const GroupReach({this.readers = const [], this.pending = const []});
  final List<({String name, DateTime readAt})> readers;
  final List<String> pending;

  factory GroupReach.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'group_reach');
    return GroupReach(
      readers: r.objects(
        'readers',
        (row) => (
          name: row.stringOr('name'),
          readAt: row.dateTime('read_at').toUtc(),
        ),
      ),
      pending: r.objects('pending', (row) => row.stringOr('name')),
    );
  }
}
