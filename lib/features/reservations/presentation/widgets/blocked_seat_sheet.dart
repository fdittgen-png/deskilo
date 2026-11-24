// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// Sheet on a blocked seat for owners/delegated admins (#161): explains the
/// block and offers to make the seat reservable again (pops true).
class BlockedSeatSheet extends StatelessWidget {
  const BlockedSeatSheet({super.key, required this.seatName});

  /// The seat's own name (empty when it has none).
  final String seatName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blockedText = l10n.planSeatBlocked;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(seatName.isEmpty ? blockedText : seatName),
            subtitle: seatName.isEmpty ? null : Text(blockedText),
          ),
          ListTile(
            key: const ValueKey('reserve-make-reservable'),
            leading: const Icon(Icons.event_seat_outlined),
            title: Text(l10n.planMakeReservable),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
