// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3077 — the invariant: the Reserve hub never speaks to someone who can
// configure the space as a plain member. An active owner, an active
// co-owner and an administrator are addressed as such; a pending person is
// pending; a person without a row is inactive.
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_hub_header.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member({
  bool owner = false,
  bool admin = false,
  CoOwnerStatus coOwner = CoOwnerStatus.none,
  MemberStatus status = MemberStatus.active,
}) => Member(
  id: 'm1',
  workspaceId: 'ws-1',
  userId: 'u1',
  isAdmin: admin,
  isOwner: owner,
  coOwner: coOwner,
  status: status,
);

void main() {
  test('who can configure is addressed as such, never as a member', () {
    expect(ReserveHubHeader.standingOf(_member(owner: true)),
        MembershipStanding.owner);
    expect(ReserveHubHeader.standingOf(_member(coOwner: CoOwnerStatus.active)),
        MembershipStanding.owner);
    expect(ReserveHubHeader.standingOf(_member(admin: true)),
        MembershipStanding.administrator);
    expect(ReserveHubHeader.standingOf(_member()), MembershipStanding.member);
  });

  test('a pending person is pending and no row is inactive', () {
    expect(ReserveHubHeader.standingOf(_member(status: MemberStatus.pending)),
        MembershipStanding.pending);
    expect(ReserveHubHeader.standingOf(null), MembershipStanding.inactive);
  });
}
