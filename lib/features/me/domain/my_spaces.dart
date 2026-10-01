// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — "My spaces", from every server this account is linked to.
import '../../../core/data/system_columns.dart';

/// Where I stand in a space.
enum MySpaceStanding { member, pending, left }

/// One space on another server, as that server's own session reads it.
class LinkedSpace implements SystemStamped {
  const LinkedSpace({
    required this.id,
    required this.name,
    this.standing = MySpaceStanding.member,
    this.isOwner = false,
    this.isAdmin = false,
    this.system = SystemColumns.none,
  });

  @override
  final SystemColumns system;

  final String id;
  final String name;
  final MySpaceStanding standing;
  final bool isOwner;
  final bool isAdmin;
}

/// The spaces one linked server holds for me, or why it could not say.
class LinkedServerSpaces {
  const LinkedServerSpaces({
    required this.source,
    required this.key,
    this.spaces = const [],
    this.unavailable = false,
  });

  /// The server's canonical URL — the connection's key.
  final String source;

  /// Its public (anon) key, needed to open it as the app's server.
  final String key;
  final List<LinkedSpace> spaces;

  /// The server did not answer: the list is incomplete, not empty.
  final bool unavailable;

  /// The quiet subtitle: the host alone, never the whole URL.
  String get host => Uri.tryParse(source)?.host ?? source;
}

/// The member statuses the server writes (0052), as standings.
MySpaceStanding standingOf(String? status) => switch (status) {
      'pending' => MySpaceStanding.pending,
      'exited' => MySpaceStanding.left,
      _ => MySpaceStanding.member,
    };
