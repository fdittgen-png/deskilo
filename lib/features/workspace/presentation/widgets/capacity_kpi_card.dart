// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the first KPI tile: seat utilisation for one month.
//
// The server computes the figure under the KPI contract; this card shows
// the value, its unit and period, its numerator and denominator, what
// the data cannot know, and when it was computed. An undefined ratio is
// shown as undefined, a refusal as a refusal and a failure as a failure —
// never as 0 %. Reading it changes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/kpi_contract.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/kpi_providers.dart';
import '../../providers/workspace_providers.dart';

/// Shown only when the feature is on and the reader holds viewAnalytics
/// (#1921); the server checks both again.
class CapacityKpiCard extends ConsumerStatefulWidget {
  const CapacityKpiCard({super.key});

  @override
  ConsumerState<CapacityKpiCard> createState() => _CapacityKpiCardState();
}

class _CapacityKpiCardState extends ConsumerState<CapacityKpiCard> {
  late DateTime _month = () {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month);
  }();

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.capacityKpi);
    final may = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.viewAnalytics);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (!on || !may || workspace == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final provider = seatCapacityMonthProvider(
      workspace.id,
      _month.year,
      _month.month,
    );
    final kpi = ref.watch(provider);
    final monthLabel = DateFormat.yMMMM(locale).format(_month);

    return Card(
      key: const ValueKey('capacity-kpi-card'),
      margin: AppSpacing.mdAll,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n?.capacityKpiTitle ?? 'Seat utilisation',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('capacity-kpi-previous'),
                  tooltip: MaterialLocalizations.of(context)
                      .previousMonthTooltip,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Text(monthLabel, key: const ValueKey('capacity-kpi-month')),
                IconButton(
                  key: const ValueKey('capacity-kpi-next'),
                  tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
            switch (kpi) {
              AsyncData(:final value) => _Figure(kpi: value),
              AsyncError(:final error) => _Failure(
                forbidden: error is KpiForbidden,
                onRetry: () => ref.invalidate(provider),
              ),
              _ => const LoadingView(),
            },
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.forbidden, required this.onRetry});

  final bool forbidden;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (forbidden) {
      return Text(
        l10n?.capacityKpiForbidden ??
            'You may not read the capacity figures of this workspace.',
        key: const ValueKey('capacity-kpi-forbidden'),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n?.capacityKpiUnavailable ??
              'The seat utilisation could not be computed.',
          key: const ValueKey('capacity-kpi-unavailable'),
        ),
        TextButton(
          key: const ValueKey('capacity-kpi-retry'),
          onPressed: onRetry,
          child: Text(l10n?.capacityKpiRetry ?? 'Try again'),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.kpi});

  final SeatCapacityKpi kpi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final ratio = kpi.utilisation;
    final value = ratio == null
        ? '—'
        : NumberFormat.decimalPercentPattern(
            locale: locale,
            decimalDigits: 1,
          ).format(ratio);
    final notes = capacityKpiNotes(kpi, l10n, locale);
    final details = capacityKpiDetails(kpi, l10n, locale);
    final ratioLine = capacityKpiRatioLine(kpi, l10n, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          key: const ValueKey('capacity-kpi-value'),
          style: theme.textTheme.headlineMedium,
        ),
        Text(ratioLine, key: const ValueKey('capacity-kpi-ratio')),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: theme.textTheme.bodySmall),
          ),
        ExpansionTile(
          key: const ValueKey('capacity-kpi-explain'),
          tilePadding: EdgeInsets.zero,
          title: Text(l10n?.capacityKpiExplain ?? 'How is this computed?'),
          children: [
            for (final line in details)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

NumberFormat _hours(String locale) =>
    NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1);

String _since(SeatCapacityKpi kpi, String locale) {
  final since = kpi.historySince;
  return since == null ? '' : DateFormat.yMMMd(locale).format(since.toLocal());
}

/// "25 of 100 seat-hours reserved" — the ratio's two sides (#1918). The
/// Web-BI module (#1923) prints the same line.
String capacityKpiRatioLine(
  SeatCapacityKpi kpi,
  AppLocalizations? l10n,
  String locale,
) {
  final hours = _hours(locale);
  final reserved = hours.format(kpi.reservedSeatHours);
  final offered = hours.format(kpi.offeredSeatHours);
  return l10n?.capacityKpiRatio(reserved, offered) ??
      '$reserved of $offered seat-hours reserved';
}

/// What the figure cannot know or does not count, shown beside it.
List<String> capacityKpiNotes(
  SeatCapacityKpi kpi,
  AppLocalizations? l10n,
  String locale,
) {
  final sinceLabel = _since(kpi, locale);
  final ratio = kpi.utilisation;
  final notRecorded = kpi.quality.contains(KpiQuality.notRecorded);
  return <String>[
    if (notRecorded)
      l10n?.capacityKpiNotRecorded(sinceLabel) ??
          'This period lies before the workspace’s history began on '
              '$sinceLabel; there is nothing recorded to count.'
    else if (ratio == null)
      l10n?.capacityKpiUndefined ??
          'No seat time was offered in this period, so there is no '
              'utilisation to show.',
    if (kpi.quality.contains(KpiQuality.knownZero))
      l10n?.capacityKpiKnownZero ?? 'Measured: nothing was reserved.',
    if (!notRecorded && kpi.reasons.contains('history_not_recorded_before'))
      l10n?.capacityKpiHistorySince(sinceLabel) ??
          'Counted from $sinceLabel, when this workspace’s history '
              'began; earlier time is not known and not counted.',
    if (kpi.reasons.contains('unattributed_reservations'))
      l10n?.capacityKpiUnattributed ??
          'Some reservations in this period point to a place that no '
              'longer exists; they are not counted.',
  ];
}

/// How the figure is made, for the explanation.
List<String> capacityKpiDetails(
  SeatCapacityKpi kpi,
  AppLocalizations? l10n,
  String locale,
) {
  final hours = _hours(locale);
  final since = kpi.historySince;
  final sinceLabel = _since(kpi, locale);
  final computed = DateFormat.yMd(locale)
      .add_Hm()
      .format(kpi.computedAt.toLocal());
  return <String>[
    l10n?.capacityKpiDefinition ??
        'Reserved seat-hours inside the opening hours, divided by offered '
            'seat-hours.',
    l10n?.capacityKpiPhysical(hours.format(kpi.physicalSeatHours)) ??
        'Physical capacity: ${hours.format(kpi.physicalSeatHours)} '
            'seat-hours',
    if (kpi.reservedOutsideOfferedSeatHours > 0)
      l10n?.capacityKpiOutside(
            hours.format(kpi.reservedOutsideOfferedSeatHours),
          ) ??
          'Reserved outside the offered hours: '
              '${hours.format(kpi.reservedOutsideOfferedSeatHours)} '
              'seat-hours, not in the ratio',
    if (kpi.overlappingSeatHours > 0)
      l10n?.capacityKpiOverlap(hours.format(kpi.overlappingSeatHours)) ??
          'Claimed twice at the same time: '
              '${hours.format(kpi.overlappingSeatHours)} seat-hours, '
              'counted once',
    if (kpi.roomsWithoutSeats > 0)
      l10n?.capacityKpiRooms(
            '${kpi.roomsWithoutSeats}',
            hours.format(kpi.reservedRoomHours),
            hours.format(kpi.offeredRoomHours),
          ) ??
          'Rooms without seats: ${kpi.roomsWithoutSeats}',
    if (kpi.reasons.contains('rooms_current_structure'))
      l10n?.capacityKpiRoomsToday ??
          'Rooms without seats are read as they are today.',
    if (since != null)
      l10n?.capacityKpiHistory(sinceLabel) ??
          'History recorded since $sinceLabel',
    l10n?.capacityKpiAsOf(computed) ?? 'Computed $computed',
  ];
}
