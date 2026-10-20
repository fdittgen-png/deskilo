// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- who is offered which management action on a member's
// sheet, as a table on the decision (no taps): the screen only maps each
// action to its tile.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_sheet_actions.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member({
  MemberStatus status = MemberStatus.active,
  bool kiosk = false,
  bool owner = false,
  String userId = 'u',
  CoOwnerStatus coOwner = CoOwnerStatus.none,
}) => Member(
  id: 'm',
  workspaceId: 'w',
  userId: userId,
  isAdmin: false,
  isOwner: owner,
  status: status,
  isKiosk: kiosk,
  coOwner: coOwner,
);

MemberSheetFacts _facts(
  Member m, {
  bool owner = false,
  bool self = false,
  bool staff = false,
  bool roles = false,
  bool kioskPerm = false,
  bool services = false,
  bool level = false,
  bool kioskOn = false,
  bool coOwnerOn = false,
  bool notes = false,
  bool reports = false,
  bool canGive = false,
}) => MemberSheetFacts(
  member: m,
  isOwner: owner,
  isSelf: self,
  staff: staff,
  canGiveRoles: canGive,
  mayOperateKiosk: kioskPerm,
  servicesOn: services,
  levelBookingOn: level,
  kioskOn: kioskOn,
  coOwnerOn: coOwnerOn,
  notesOn: notes,
  reportsOn: reports,
  rolesOn: roles,
);

void main() {
  test('a plain viewer sees the always-on rows for an active member', () {
    expect(memberSheetActions(_facts(_member())), [
      MemberSheetAction.negotiation,
      MemberSheetAction.badges,
    ]);
  });

  test(
    'the owner of an active member sees the full owner surface in order',
    () {
      expect(
        memberSheetActions(
          _facts(
            _member(),
            owner: true,
            staff: true,
            services: true,
            level: true,
            coOwnerOn: true,
            notes: true,
            reports: true,
          ),
        ),
        [
          MemberSheetAction.employment,
          MemberSheetAction.sendAgreement,
          MemberSheetAction.messages,
          MemberSheetAction.addConsumption,
          MemberSheetAction.subscription,
          MemberSheetAction.negotiation,
          MemberSheetAction.overagePolicy,
          MemberSheetAction.reservationLimit,
          MemberSheetAction.simultaneousLimit,
          MemberSheetAction.levelPermission,
          MemberSheetAction.badges,
          MemberSheetAction.makeAdminOrMember,
          MemberSheetAction.coOwnerAppoint,
          MemberSheetAction.pauseOrReactivate,
        ],
      );
    },
  );

  test('roleAssignment replaces make-admin with add-a-role', () {
    final actions = memberSheetActions(
      _facts(_member(), owner: true, roles: true, canGive: true),
    );
    expect(actions, contains(MemberSheetAction.addRole));
    expect(actions, isNot(contains(MemberSheetAction.makeAdminOrMember)));
    expect(
      memberSheetActions(_facts(_member(), roles: true)),
      isNot(contains(MemberSheetAction.addRole)),
      reason: 'a viewer who may not give roles is not offered the row',
    );
  });

  test('a pending member is decided first, never by themselves', () {
    final pending = _member(status: MemberStatus.pending);
    expect(memberSheetActions(_facts(pending)), [
      MemberSheetAction.approveJoin,
      MemberSheetAction.rejectJoin,
    ]);
    expect(memberSheetActions(_facts(pending, self: true)), [
      MemberSheetAction.employment,
    ]);
  });

  test('your own row offers no limits, roles, co-owner or messages', () {
    final own = memberSheetActions(
      _facts(
        _member(),
        owner: true,
        self: true,
        staff: true,
        roles: true,
        canGive: true,
        notes: true,
        coOwnerOn: true,
        level: true,
      ),
    );
    expect(own, [
      MemberSheetAction.employment,
      MemberSheetAction.subscription,
      MemberSheetAction.negotiation,
      MemberSheetAction.overagePolicy,
      MemberSheetAction.badges,
      MemberSheetAction.pauseOrReactivate,
    ]);
  });

  test('a kiosk has its own few rows, and reverts itself', () {
    final kiosk = _member(kiosk: true);
    expect(
      memberSheetActions(
        _facts(kiosk, owner: true, staff: true, services: true, reports: true),
      ),
      [MemberSheetAction.employment, MemberSheetAction.pauseOrReactivate],
    );
    expect(memberSheetActions(_facts(kiosk, owner: true, self: true)), [
      MemberSheetAction.employment,
      MemberSheetAction.kioskSelfRevert,
      MemberSheetAction.pauseOrReactivate,
    ]);
    expect(memberSheetActions(_facts(kiosk, kioskPerm: true)), [
      MemberSheetAction.kioskToggle,
    ], reason: 'a kiosk is un-made by operateKiosk even with the flag off');
  });

  test('making a kiosk needs the flag; an owner is never made one', () {
    expect(
      memberSheetActions(_facts(_member(), kioskPerm: true)),
      isNot(contains(MemberSheetAction.kioskToggle)),
    );
    expect(
      memberSheetActions(_facts(_member(), kioskPerm: true, kioskOn: true)),
      contains(MemberSheetAction.kioskToggle),
    );
    expect(
      memberSheetActions(
        _facts(_member(owner: true), kioskPerm: true, kioskOn: true),
      ),
      isNot(contains(MemberSheetAction.kioskToggle)),
    );
  });

  test('a managed member is not messaged; a co-owner can be activated', () {
    expect(
      memberSheetActions(_facts(_member(userId: ''), notes: true)),
      isNot(contains(MemberSheetAction.messages)),
    );
    expect(
      memberSheetActions(
        _facts(
          _member(coOwner: CoOwnerStatus.passive),
          owner: true,
          coOwnerOn: true,
        ),
      ),
      contains(MemberSheetAction.coOwnerActivate),
    );
  });

  test(
    'an exited member offers nothing to pause, a paused one reactivates',
    () {
      expect(
        memberSheetActions(
          _facts(_member(status: MemberStatus.exited), owner: true),
        ),
        [MemberSheetAction.employment, MemberSheetAction.subscription],
      );
      expect(
        memberSheetActions(
          _facts(_member(status: MemberStatus.paused), owner: true),
        ),
        containsAllInOrder([
          MemberSheetAction.subscription,
          MemberSheetAction.pauseOrReactivate,
        ]),
      );
    },
  );
}
