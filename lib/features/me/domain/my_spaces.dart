// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — "My spaces", from every server this account is linked to.
import '../../../core/data/system_columns.dart';
import '../../workspace/domain/workspace.dart';

/// Where I stand in a space.
enum MySpaceStanding { member, pending, left }

/// One space on another server, as that server's own session reads it.
class LinkedSpace implements SystemStamped, SpaceSide {
  const LinkedSpace({
    required this.id,
    required this.name,
    this.standing = MySpaceStanding.member,
    this.pairId = '',
    this.environment = WorkspaceEnvironment.development,
    this.isOwner = false,
    this.isAdmin = false,
    this.system = SystemColumns.none,
  });

  @override
  final SystemColumns system;

  @override
  final String id;
  final String name;
  @override
  final String pairId;
  final WorkspaceEnvironment environment;
  final MySpaceStanding standing;
  final bool isOwner;
  final bool isAdmin;

  @override
  WorkspaceEnvironment get env => environment;
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
}

/// The member statuses the server writes (0052), as standings.
MySpaceStanding standingOf(String? status) => switch (status) {
      'pending' => MySpaceStanding.pending,
      'exited' => MySpaceStanding.left,
      _ => MySpaceStanding.member,
    };
