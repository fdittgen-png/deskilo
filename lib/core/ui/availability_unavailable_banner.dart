// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import 'inline_banner.dart';

/// #1848 — a window read that failed with nothing to show is NOT an empty
/// day: drawing every seat free would invite a booking on an occupied one.
/// The selection is kept; Retry refetches exactly the windows that failed.
class AvailabilityUnavailableBanner extends StatelessWidget {
  const AvailabilityUnavailableBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InlineBanner(
        key: const ValueKey('reserve-availability-unavailable'),
        icon: Icons.cloud_off_outlined,
        text: l10n.reserveAvailabilityUnavailable,
        actionLabel: l10n.reserveStaleRetry,
        onAction: onRetry,
      ),
    );
  }
}
