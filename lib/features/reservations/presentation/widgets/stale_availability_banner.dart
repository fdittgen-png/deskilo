// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/stale_reads.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/reservation_providers.dart';

/// #1305 S3 — availability served from the cache's stale tier says so.
///
/// Offline, the hub draws the last reservations it saved rather than
/// nothing, which is right. It used to draw them exactly like live ones,
/// so a seat taken ten minutes ago still looked free and the member found
/// out only when the booking was refused. While any reservation read is
/// stale, this banner names the time the data was saved and offers a
/// retry; it disappears the moment a read succeeds.
class StaleAvailabilityBanner extends ConsumerWidget {
  const StaleAvailabilityBanner({super.key});

  /// The cache keys availability is read under.
  static const prefixes = ['resv:'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: StaleReads.instance,
      builder: (context, _) {
        final savedAt = StaleReads.instance.oldestSavedAt(prefixes);
        if (savedAt == null) {
          return const SizedBox.shrink(key: ValueKey('reserve-availability-live'));
        }
        final l10n = AppLocalizations.of(context);
        final time = appFormatOf(context).time(savedAt);
        return InlineBanner(
          key: const ValueKey('reserve-stale-banner'),
          icon: Icons.cloud_off_outlined,
          severity: InlineBannerSeverity.info,
          text: l10n?.reserveStaleAvailability(time) ??
              'Offline — availability as of $time. A seat shown free may '
                  'have been taken since.',
          actionLabel: l10n?.reserveStaleRetry ?? 'Retry',
          // Refetch what the hub draws; a success clears the banner.
          onAction: () => ref
            ..invalidate(reservationsForDayProvider)
            ..invalidate(reservationsForMonthProvider),
        );
      },
    );
  }
}
