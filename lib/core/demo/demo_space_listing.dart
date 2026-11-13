// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3846 — the part of a Demo space the switcher needs at the start: its row
// in the shared list of spaces and its people. Everything else a space holds
// (plan, bookings, requests, money) is built when the space is first read
// (demo_fixture.dart); this is what [viewAs] moves with the persona and what
// a build is seeded under.
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace.dart';
import 'data/workspace_repository.dart';

class DemoSpaceListing {
  /// The space [id] over [workspaces] (its own members, the list of spaces
  /// shared with [home]). Built after the space's row has joined the list and
  /// its people are seeded: those members are the viewpoint the space's data
  /// is seeded under, whenever that happens.
  DemoSpaceListing(this.id, this.workspaces, this._home)
    : _seededRows = [workspaces.myMember, ...workspaces.otherMembers];

  final String id;
  final FakeWorkspaceRepository workspaces;
  final FakeWorkspaceRepository _home;
  final List<Member> _seededRows;

  /// The space's row while the persona is not a member there.
  Workspace? _parked;
  int _seeding = 0;

  /// Looks at the space as [memberId]: their membership becomes "mine" here
  /// and in the home list of memberships. A persona with no membership here
  /// (the kiosk tablet) does not see the space at all.
  void viewAs(String memberId) {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final mine = rows.where((m) => m.id == memberId).firstOrNull;
    _home.extraMyMemberships.removeWhere((m) => m.workspaceId == id);
    final listed = _home.workspaces.indexWhere((w) => w.id == id);
    if (mine == null) {
      if (listed >= 0) _parked = _home.workspaces.removeAt(listed);
      return;
    }
    workspaces.myMember = mine;
    workspaces.otherMembers
      ..clear()
      ..addAll(rows.where((m) => m.id != mine.id));
    _home.extraMyMemberships.add(mine);
    if (listed < 0 && _parked != null) _home.workspaces.add(_parked!);
    _parked = null;
  }

  /// Runs [build] with the space as it was when it was listed (its row in the
  /// list, the cast as seeded), whatever persona is looked through now, and
  /// then looks at the space as [memberId] again: what a space holds does not
  /// depend on when it is built.
  T seeded<T>(String memberId, T Function() build) {
    if (_seeding > 0) return build();
    _seeding++;
    try {
      if (_parked != null) _home.workspaces.add(_parked!);
      _parked = null;
      workspaces.myMember = _seededRows.first;
      workspaces.otherMembers
        ..clear()
        ..addAll(_seededRows.skip(1));
      return build();
    } finally {
      _seeding--;
      viewAs(memberId);
    }
  }
}
