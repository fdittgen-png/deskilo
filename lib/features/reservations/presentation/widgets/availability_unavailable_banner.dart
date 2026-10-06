// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/reservation_providers.dart';

/// #1848 — a window read that failed with nothing to show is NOT an empty
/// day: drawing every seat free would invite a booking on an occupied one.
/// The selected day is kept; Retry refetches exactly that window.
class AvailabilityUnavailableBanner extends ConsumerWidget {
  const AvailabilityUnavailableBanner({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InlineBanner(
        key: const ValueKey('reserve-availability-unavailable'),
        icon: Icons.cloud_off_outlined,
        severity: InlineBannerSeverity.error,
        text: l10n?.reserveAvailabilityUnavailable ??
            'Availability could not be loaded completely, so no seat is '
                'shown as free. Retry to see it.',
        actionLabel: l10n?.reserveStaleRetry ?? 'Retry',
        onAction: () => ref.invalidate(reservationsForDayProvider(dayKey)),
      ),
    );
  }
}
