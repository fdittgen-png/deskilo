// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the calendar's filter row (K4's FilterBar): level, kind of
// place, member, state. It stays above the grid, wraps onto more lines when the
// room needs it, and carries the period's export. What it keeps is
// `deskBookingsIn`, so the grid and the table filter alike.
import 'package:flutter/material.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/text/collation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/kit/dashboard_grid.dart';
import '../../core/ui/kit/kit_metrics.dart';
import '../../features/plan/domain/level.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../l10n/app_localizations.dart';
import 'desk_calendar.dart';

/// The key of the filter row's [name] choice (`level`, `kind`, `member`,
/// `state`).
@visibleForTesting
Key deskFilterKey(String name) => ValueKey('desk-filter-$name');

/// The key of the New booking button.
const Key _deskNewKey = ValueKey('desk-new');

/// The key of the export button.
const Key _deskExportKey = ValueKey('desk-export');

String _kindWords(AppLocalizations l10n, ResourceKind kind) => switch (kind) {
  ResourceKind.seat => l10n.spaceKindSeat,
  ResourceKind.room => l10n.reserveMeetingRoom,
  ResourceKind.parking => l10n.reserveParkingStandard,
};

class DeskFilterRow extends StatelessWidget {
  const DeskFilterRow({
    required this.filter,
    required this.levels,
    required this.members,
    required this.onChanged,
    required this.onExport,
    required this.onNew,
    super.key,
  });

  final DeskFilter filter;
  final List<Level> levels;

  /// Member id → name.
  final Map<String, String> members;
  final ValueChanged<DeskFilter> onChanged;

  /// Null while there is nothing to export or an export runs.
  final VoidCallback? onExport;

  /// Null while there is no place to book.
  final VoidCallback? onNew;

  Widget _choice<T>(
    BuildContext context, {
    required String name,
    required String label,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T?> onPicked,
  }) => ConstrainedBox(
    key: deskFilterKey(name),
    constraints: const BoxConstraints(
      maxWidth: KitMetrics.dropdownMaxWidth,
      minWidth: KitMetrics.dropdownMaxWidth,
    ),
    child: DropdownButtonFormField<T?>(
      key: ValueKey('desk-filter-field-$name-${value ?? 'all'}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(
          key: ValueKey('desk-filter-$name-all'),
          child: Text(context.l10n.calendarDeskAll),
        ),
        for (final e in options.entries)
          DropdownMenuItem<T?>(
            key: ValueKey('desk-filter-$name-${e.key}'),
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onPicked,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byName = members.entries.toList()
      ..sort((a, b) => compareNames(a.value, b.value));
    return FilterBar(
      filters: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            _choice<String>(
              context,
              name: 'level',
              label: l10n.calendarDeskFilterLevel,
              value: filter.levelId,
              options: {for (final l in levels) l.id: l.name},
              onPicked: (v) =>
                  onChanged(filter.withLevel(v)),
            ),
            _choice<ResourceKind>(
              context,
              name: 'kind',
              label: l10n.calendarDeskFilterKind,
              value: filter.kind,
              options: {for (final k in ResourceKind.values) k: _kindWords(l10n, k)},
              onPicked: (v) =>
                  onChanged(filter.withKind(v)),
            ),
            _choice<String>(
              context,
              name: 'member',
              label: l10n.calendarDeskColumnMember,
              value: filter.memberId,
              options: {for (final e in byName) e.key: e.value},
              onPicked: (v) => onChanged(filter.withMember(v)),
            ),
            _choice<ReservationStatus>(
              context,
              name: 'state',
              label: l10n.calendarDeskColumnState,
              value: filter.status,
              options: {
                for (final s in ReservationStatus.values)
                  s: myReservationStatusWords(l10n, s),
              },
              onPicked: (v) => onChanged(filter.withStatus(v)),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: FilledButton.icon(
            key: _deskNewKey,
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: Text(l10n.calendarDeskNew),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: OutlinedButton.icon(
            key: _deskExportKey,
            onPressed: onExport,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l10n.calendarDeskExport),
          ),
        ),
      ],
    );
  }
}
