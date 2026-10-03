// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — the hub's one line about an answer still owed: a booking this
// device confirmed whose outcome it never read (a lost connection, a
// restart). Nothing is drawn when every intent is settled, and nothing
// here books: the line opens the recovery sheet, which asks the server.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/reservation_providers.dart';
import 'booking_recovery_sheet.dart';

class PendingBookingBanner extends ConsumerWidget {
  const PendingBookingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(unresolvedBookingIntentsProvider).value;
    if (pending == null || pending.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InlineBanner(
        key: const ValueKey('pending-booking-banner'),
        icon: Icons.help_outline,
        severity: InlineBannerSeverity.error,
        text:
            l10n?.bookingRecoveryBanner ??
            'A booking request of yours is still unanswered.',
        actionLabel: l10n?.bookingRecoveryBannerAction ?? 'Check',
        onAction: () async {
          await showBookingRecoverySheet(context, ref, pending.first);
          ref.invalidate(unresolvedBookingIntentsProvider);
        },
      ),
    );
  }
}
