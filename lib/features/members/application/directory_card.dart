// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what a directory row and the member's profile sheet show, as a
// decision on facts instead of conditions inside two widgets' builds. The
// row and the sheet map these answers to their chips, badge, subtitle and
// buttons; the table test pins who sees what.
//
// Pure Dart.
library;

import '../../profile/domain/profile.dart';
import '../../reservations/domain/reservation.dart';
import '../../workspace/domain/member.dart';
import '../domain/directory_status.dart';

/// The single role label a member carries in the directory: roles are
/// additive flags (spec §2), owner outranks admin.
enum DirectoryRole { owner, admin, member }

/// One member as the directory row and the profile sheet see them.
class DirectoryCard {
  const DirectoryCard({
    required this.member,
    required this.name,
    this.email = '',
    required this.isSelf,
    required this.profile,
    required this.presence,
    required this.reservationInfo,
    required this.memberReservations,
    required this.targetNames,
    required this.now,
  });

  final Member member;
  final String name;

  /// The member's email — non-empty only for admin/owner viewers
  /// (#410, member_emails RPC); '' renders nothing.
  final String email;
  final bool isSelf;
  final Profile? profile;
  final DirectoryPresence presence;
  final ReservationInfo? reservationInfo;
  final List<Reservation> memberReservations;
  final Map<String, String> targetNames;
  final DateTime now;

  /// The self-set status line (#231), '' when none.
  String get statusText => profile?.statusText ?? '';

  /// The WhatsApp link when the member shared a number (#223).
  Uri? get whatsappUri => profile?.whatsappUri;

  bool get hasAvatar => profile?.hasAvatar ?? false;

  /// Online right now: the ringed dot on the avatar.
  bool get online => presence.kind == DirectoryPresenceKind.online;

  /// Checked in right now: the success-tinted card.
  bool get onSite => reservationInfo is CheckedInNow;

  /// A presence chip: online, or a last-seen time; never seen → none.
  bool get showsPresence => online || presence.lastSeenAt != null;

  /// A reservation chip (#237).
  bool get showsReservation => reservationInfo != null;

  bool get hasChips => showsPresence || showsReservation;

  /// The row's subtitle: email, status line or chips.
  bool get hasSubtitle =>
      hasChips || statusText.isNotEmpty || email.isNotEmpty;

  DirectoryRole get role => member.isOwner
      ? DirectoryRole.owner
      : member.isAdmin
          ? DirectoryRole.admin
          : DirectoryRole.member;

  /// The booked space's name; a deleted target falls back to its audit
  /// substitution text (#587).
  String get seatName =>
      reservationInfo?.reservation.spaceNameFrom(targetNames) ?? '';
}
