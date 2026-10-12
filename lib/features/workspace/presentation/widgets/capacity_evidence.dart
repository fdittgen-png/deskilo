// SPDX-License-Identifier: AGPL-3.0-or-later
// A booking ratio is not attendance, a forecast or a past as-of snapshot.
// Keep these distinctions beside the number in both capacity consumers.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/kpi_contract.dart';

String biQualityLabel(Set<KpiQuality> quality, AppLocalizations l10n) {
  if (quality.contains(KpiQuality.forbidden) ||
      quality.contains(KpiQuality.unavailable)) {
    return l10n.biDataUnavailable;
  }
  if (quality.contains(KpiQuality.notRecorded)) {
    return l10n.biDataNotRecorded;
  }
  if (quality.contains(KpiQuality.notApplicable)) {
    return l10n.biDataNotApplicable;
  }
  return [
    if (quality.contains(KpiQuality.partial))
      l10n.biDataPartial,
    if (quality.contains(KpiQuality.stale)) l10n.biDataStale,
  ].join(' · ');
}

class CapacityEvidence extends StatelessWidget {
  const CapacityEvidence({super.key, required this.kpi});

  final SeatCapacityKpi kpi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final future = !kpi.from.isBefore(kpi.computedAt);
    final closed = !kpi.to.isAfter(kpi.computedAt);
    final period = future
        ? l10n.biRecordedFuture
        : closed
        ? l10n.biRecordedPast
        : l10n.biRecordedPresent;
    final explanation = future
        ? l10n.biFutureBasis
        : closed
        ? l10n.biPastBasis
        : l10n.biCurrentBasis;
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
            l10n.biBookingBasis,
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
            l10n.biComputedWorkspaceTime(asOf),
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
                    l10n.biSeatHoursFree(hours.format(free)),
                  ),
                if (blocked >= 0)
                  Text(
                    l10n.biSeatHoursBlocked(hours.format(blocked)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
