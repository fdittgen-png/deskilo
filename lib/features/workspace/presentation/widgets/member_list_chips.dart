// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The chips under a member's name in the members list (moved out of
// members_screen.dart by #3618, unchanged).
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../domain/booking_policies.dart';
import '../../domain/member.dart';
import '../subscription_text.dart';

/// The chips under a member's name: email, subscription or kiosk,
/// allowances; the role and status chips follow them on the list.
List<Widget> memberListChips(
  BuildContext context,
  Member member,
  String email,
  BookingPolicies policies,
) {
  final l10n = context.l10n;
  // #628 — the EFFECTIVE overlap allowance (member permission, else the
  // workspace default); 1 is one place at a time and needs no chip.
  final simultaneous = BookingPolicies.allowanceFor(
    member.maxSimultaneousReservations,
    policies,
  );
  return [
    if (email.isNotEmpty) Text(email),
    // A kiosk is a device, not a paying member — no
    // subscription line.
    if (!member.isKiosk)
      Text(
        subscriptionText(l10n, appFormatOf(context), member.subscriptionPct),
      ),
    if (member.isKiosk) Text(l10n.memberKioskLabel),
    if (member.maxActiveReservations != null)
      Text(l10n.memberReservationLimitChip(member.maxActiveReservations!)),
    if (simultaneous > BookingPolicies.defaultSimultaneous)
      Text(l10n.memberSimultaneousLimitChip(simultaneous)),
  ];
}
