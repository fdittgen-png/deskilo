// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- which management actions a member's sheet offers, as a
// decision on facts instead of thirty conditions inside a widget build. The
// screen maps each action to its tile; the table test pins who sees what.
//
// Pure Dart.
library;

import 'member.dart';

/// One action of the member sheet, in the order the sheet lists them.
enum MemberSheetAction {
  employment,
  sendAgreement,
  messages,
  approveJoin,
  rejectJoin,
  addConsumption,
  subscription,
  negotiation,
  overagePolicy,
  reservationLimit,
  simultaneousLimit,
  levelPermission,
  badges,
  addRole,
  makeAdminOrMember,
  coOwnerAppoint,
  coOwnerActivate,
  kioskToggle,
  kioskSelfRevert,
  pauseOrReactivate,
}

/// What the sheet's decisions read: the member and the viewer's standing.
class MemberSheetFacts {
  const MemberSheetFacts({
    required this.member,
    required this.isOwner,
    required this.isSelf,
    required this.staff,
    required this.canGiveRoles,
    required this.mayOperateKiosk,
    this.servicesOn = false,
    this.levelBookingOn = false,
    this.kioskOn = false,
    this.coOwnerOn = false,
    this.notesOn = false,
    this.reportsOn = false,
    this.rolesOn = false,
  });

  final Member member;

  /// The viewer holds owner-level standing.
  final bool isOwner;

  /// The sheet is the viewer's own row.
  final bool isSelf;

  /// The viewer may administer reservations (the allowances, 0364).
  final bool staff;
  final bool canGiveRoles;
  final bool mayOperateKiosk;
  final bool servicesOn;
  final bool levelBookingOn;
  final bool kioskOn;
  final bool coOwnerOn;
  final bool notesOn;
  final bool reportsOn;
  final bool rolesOn;
}

/// The actions offered for [f], in sheet order.
List<MemberSheetAction> memberSheetActions(MemberSheetFacts f) {
  final m = f.member;
  final active = m.status == MemberStatus.active;
  final pending = m.status == MemberStatus.pending;
  final kiosk = m.isKiosk;
  final others = !f.isSelf;
  return [
    if (f.isOwner || f.isSelf) MemberSheetAction.employment,
    if (f.reportsOn && !kiosk && active) MemberSheetAction.sendAgreement,
    // #887 -- nobody reads a message to a managed member.
    if (f.notesOn && others && !kiosk && !m.isManaged && active)
      MemberSheetAction.messages,
    if (pending && others) ...[
      MemberSheetAction.approveJoin,
      MemberSheetAction.rejectJoin,
    ],
    if (f.servicesOn && !kiosk && active) MemberSheetAction.addConsumption,
    if (f.isOwner && !kiosk) MemberSheetAction.subscription,
    if (!kiosk && active) MemberSheetAction.negotiation,
    if (f.isOwner && !kiosk && active) MemberSheetAction.overagePolicy,
    if (f.staff && others && !kiosk && active) ...[
      MemberSheetAction.reservationLimit,
      // #628 -- same authorization as the cap, never for themselves.
      MemberSheetAction.simultaneousLimit,
    ],
    if (f.staff && f.levelBookingOn && others && !kiosk && active)
      MemberSheetAction.levelPermission,
    if (!kiosk && !m.isOwner && active) MemberSheetAction.badges,
    if (f.rolesOn && others && !kiosk && active && f.canGiveRoles)
      MemberSheetAction.addRole,
    if (f.isOwner && !m.isOwner && !kiosk && active && !f.rolesOn)
      MemberSheetAction.makeAdminOrMember,
    if (f.isOwner && f.coOwnerOn && !m.isOwner && !kiosk && others && active)
      MemberSheetAction.coOwnerAppoint,
    if (f.isOwner && f.coOwnerOn && m.coOwner != CoOwnerStatus.none && active)
      MemberSheetAction.coOwnerActivate,
    // #982 -- the kiosk is operateKiosk's; a kiosk viewing itself keeps the
    // one self-revert action instead.
    if (f.mayOperateKiosk &&
        others &&
        !m.isOwner &&
        active &&
        (kiosk || f.kioskOn))
      MemberSheetAction.kioskToggle,
    if (f.isSelf && kiosk) MemberSheetAction.kioskSelfRevert,
    if (f.isOwner && m.status != MemberStatus.exited)
      MemberSheetAction.pauseOrReactivate,
  ];
}
