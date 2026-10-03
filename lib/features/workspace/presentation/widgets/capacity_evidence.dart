// SPDX-License-Identifier: AGPL-3.0-or-later
// A booking ratio is not attendance, a forecast or a past as-of snapshot.
// Keep these distinctions beside the number in both capacity consumers.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/kpi_contract.dart';

String biQualityLabel(Set<KpiQuality> quality, AppLocalizations? l10n) {
  if (quality.contains(KpiQuality.forbidden) ||
      quality.contains(KpiQuality.unavailable)) {
    return l10n?.biDataUnavailable ?? 'Unavailable';
  }
  if (quality.contains(KpiQuality.notRecorded)) {
    return l10n?.biDataNotRecorded ?? 'Not recorded';
  }
  if (quality.contains(KpiQuality.notApplicable)) {
    return l10n?.biDataNotApplicable ?? 'No applicable capacity';
  }
  return [
    if (quality.contains(KpiQuality.partial))
      l10n?.biDataPartial ?? 'Partial data',
    if (quality.contains(KpiQuality.stale)) l10n?.biDataStale ?? 'Out of date',
  ].join(' · ');
}

class CapacityEvidence extends StatelessWidget {
  const CapacityEvidence({super.key, required this.kpi});

  final SeatCapacityKpi kpi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final future = !kpi.from.isBefore(kpi.computedAt);
    final closed = !kpi.to.isAfter(kpi.computedAt);
    final period = future
        ? l10n?.biRecordedFuture ?? 'Future period · bookings on record'
        : closed
        ? l10n?.biRecordedPast ?? 'Past period · current records'
        : l10n?.biRecordedPresent ?? 'Current period · includes future dates';
    final explanation = future
        ? l10n?.biFutureBasis ??
              'Existing bookings and current opening rules; not a demand '
                  'forecast or guaranteed usage.'
        : closed
        ? l10n?.biPastBasis ??
              'Recomputed from records available now, not a snapshot of what '
                  'was known then.'
        : l10n?.biCurrentBasis ??
              'The whole period is included. Comparison with a completed '
                  'period is not like-for-like.';
    final quality = biQualityLabel(kpi.quality, l10n);
    final asOf = DateFormat.yMd(locale)
        .add_Hm()
        .format(WorkspaceTime.wall(kpi.computedAt));
    final hours = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    );
    final free = kpi.offeredSeatHours - kpi.reservedSeatHours;
    final blocked = kpi.physicalSeatHours - kpi.offeredSeatHours;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period,
            key: const ValueKey('capacity-period-basis'),
            style: theme.textTheme.labelLarge,
          ),
          Text(explanation, style: theme.textTheme.bodySmall),
          Text(
            l10n?.biBookingBasis ??
                'Reserved capacity measures bookings, not actual attendance.',
            style: theme.textTheme.bodySmall,
          ),
          if (quality.isNotEmpty)
            Text(
              quality,
              key: const ValueKey('capacity-data-quality'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Text(
            l10n?.biComputedWorkspaceTime(asOf) ??
                'Computed $asOf · workspace time',
            key: const ValueKey('capacity-computed-at'),
            style: theme.textTheme.bodySmall,
          ),
          if (kpi.hasValue)
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                if (free >= 0)
                  Text(
                    l10n?.biSeatHoursFree(hours.format(free)) ??
                        '${hours.format(free)} unreserved seat-hours',
                  ),
                if (blocked >= 0)
                  Text(
                    l10n?.biSeatHoursBlocked(hours.format(blocked)) ??
                        '${hours.format(blocked)} blocked seat-hours',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
