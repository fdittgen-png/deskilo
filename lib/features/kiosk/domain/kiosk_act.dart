// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- what a badge presented at the kiosk does, and how the
// server's refusal reads, as decisions on values instead of conditions
// inside the screen. The screen maps each answer to its call and its
// words; the table test pins them.
//
// Pure Dart.
library;

/// The three actions a member can perform through the kiosk.
enum KioskAction {
  checkIn('check_in'),
  reserve('reserve'),
  checkOut('check_out');

  const KioskAction(this.wireName);

  /// The kiosk_act RPC's action parameter.
  final String wireName;
}

/// What is sent for [asked]: a reservation made standing at the kiosk can
/// start checked in (one badge covers both), and only a check-out books no
/// window.
({KioskAction action, bool booksWindow}) kioskActPlan(
  KioskAction asked, {
  required bool checkInNow,
}) => (
  action: asked == KioskAction.reserve && checkInNow
      ? KioskAction.checkIn
      : asked,
  booksWindow: asked != KioskAction.checkOut,
);

/// How the kiosk words a refusal of kiosk_act (migration 0043).
enum KioskRefusal { badgeRejected, notCheckedIn, other }

/// The refusal [serverMessage] is; the substrings are the server's own.
KioskRefusal kioskRefusalOf(String serverMessage) =>
    serverMessage.contains('badge not recognized')
    ? KioskRefusal.badgeRejected
    : serverMessage.contains('not checked in')
    ? KioskRefusal.notCheckedIn
    : KioskRefusal.other;
