// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../providers/reservation_providers.dart';
import '../../domain/reservation.dart';
import 'message_reserver.dart';
import 'reservation_detail_sheet.dart';

/// What a whole-space sheet offers when the space is already taken
/// (#670).
///
/// The two branches are mutually exclusive, and getting that wrong is
/// what the field report was about:
///
///  * the blocker is **someone else's** → offer the message thread
///    (#622), so you can ask them;
///  * the blocker is **your own** → offer to manage it. Before this the
///    sheet stated the conflict and stopped, so a whole-space booking
///    could be made and never undone from the place it was made:
///    re-selecting the level showed only "Reserve" (which the server
///    refuses) and "Show on plan".
///
/// Managing routes to [showReservationDetail] rather than reimplementing
/// anything. That sheet already owns the rules — cancel a future
/// booking, end a running one earlier, request deletion once it has
/// started, each gated as it should be — and a second implementation is
/// how those rules drift apart.
class SpaceConflictActions extends ConsumerWidget {
  const SpaceConflictActions({
    super.key,
    required this.blocking,
    required this.myMemberId,
    required this.spaceName,
    required this.busy,
  });

  final Reservation blocking;
  final String? myMemberId;
  final String spaceName;

  /// The sheet is mid-write; nothing here may start a second one.
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = blocking.memberId == myMemberId;

    if (mine) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          key: const ValueKey('space-manage-mine'),
          onPressed: busy
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  await showReservationDetail(context, ref, blocking);
                  // It may have been cancelled or shortened — this
                  // sheet's conflict state is now stale, so close it
                  // rather than show a stale refusal.
                  if (nav.mounted) nav.pop();
                },
          icon: const Icon(Icons.event_busy_outlined),
          label: Text(l10n?.spaceManageMyBooking ?? 'Manage my booking'),
        ),
      );
    }

    // Offering to message yourself is nonsense, which is why this sits
    // in the else branch rather than beside it.
    if (!canMessageReserver(ref, blocking)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MessageReserverButton(
        widgetKey: const ValueKey('space-conflict-message'),
        blocking: blocking,
        name: (ref.watch(memberNamesProvider).value ??
                const {})[blocking.memberId] ??
            '',
        spaceName: spaceName,
      ),
    );
  }
}
