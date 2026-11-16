// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the calendar's filter row (K4's FilterBar): level, kind of
// place, member, state. It stays above the grid and carries New booking and
// the period's export. What it keeps is `deskBookingsIn`, so the grid and the
// table filter alike.
//
// #4075 — the filters, New booking and the overflow (⋯, which holds Export)
// share one line. Where the four filters fit that line, each is as wide as the
// room allows; where they do not, one "Filters · 2" control opens them as a
// short task and the filters in use stand beside it as chips, each removable.
// The grid then starts one line higher than when the filters wrapped.
import 'package:flutter/material.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/text/collation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/adaptive/task_choice.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../core/ui/form_kit.dart';
import '../../core/ui/kit/dashboard_grid.dart';
import '../../core/ui/kit/kit_metrics.dart';
import '../../features/plan/domain/level.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../l10n/app_localizations.dart';
import 'desk_calendar.dart';
import 'desk_metrics.dart';

/// The key of the filter row's [name] choice (`level`, `kind`, `member`,
/// `state`).
@visibleForTesting
Key deskFilterKey(String name) => ValueKey('desk-filter-$name');

/// The key of the chip of the filter [name] in use, beside the Filters control.
@visibleForTesting
Key deskFilterChipKey(String name) => ValueKey('desk-filter-chip-$name');

/// The key of the one Filters control, where the four filters do not fit.
@visibleForTesting
const Key deskFiltersKey = ValueKey('desk-filters');

/// The key of the New booking button.
const Key _deskNewKey = ValueKey('desk-new');

/// The key of the overflow button, which holds Export.
@visibleForTesting
const Key deskMoreKey = ValueKey('desk-more');

/// The key of the export entry of the overflow.
const Key _deskExportKey = ValueKey('desk-export');

/// The width each of [count] filters takes on a line of [room], or null
/// where they do not fit at [DeskCalendarMetrics.filterMin] and one Filters
/// control stands for them.
@visibleForTesting
double? deskFilterWidth(double room, {int count = 4}) {
  final each = (room - (count - 1) * AppSpacing.md) / count;
  if (each < DeskCalendarMetrics.filterMin) return null;
  return each > KitMetrics.dropdownMaxWidth ? KitMetrics.dropdownMaxWidth : each;
}

String _kindWords(AppLocalizations l10n, ResourceKind kind) => switch (kind) {
  ResourceKind.seat => l10n.spaceKindSeat,
  ResourceKind.room => l10n.reserveMeetingRoom,
  ResourceKind.parking => l10n.reserveParkingStandard,
};

/// A filter in use: its name, what it keeps, and the filter without it.
typedef _InUse = ({String name, String words, DeskFilter cleared});

/// The four filters, built for a [DeskFilter] and where its change goes: on
/// the line, or in the Filters task.
class _DeskFilters {
  _DeskFilters(this.l10n, this.levels, this.members);

  final AppLocalizations l10n;
  final List<Level> levels;
  final Map<String, String> members;

  Map<String, String> get _levels => {for (final l in levels) l.id: l.name};

  Map<ResourceKind, String> get _kinds => {
    for (final k in ResourceKind.values) k: _kindWords(l10n, k),
  };

  Map<String, String> get _members {
    final byName = members.entries.toList()
      ..sort((a, b) => compareNames(a.value, b.value));
    return {for (final e in byName) e.key: e.value};
  }

  Map<ReservationStatus, String> get _states => {
    for (final s in ReservationStatus.values) s: myReservationStatusWords(l10n, s),
  };

  Widget _choice<T>({
    required String name,
    required String label,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T?> onPicked,
    required double? width,
  }) => SizedBox(
    key: deskFilterKey(name),
    width: width,
    child: DropdownButtonFormField<T?>(
      key: ValueKey('desk-filter-field-$name-${value ?? 'all'}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(
          key: ValueKey('desk-filter-$name-all'),
          child: Text(l10n.calendarDeskAll),
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

  /// The four filters of [f], each [width] wide (null: as wide as the room).
  List<Widget> fields(
    DeskFilter f,
    ValueChanged<DeskFilter> onChanged, {
    double? width,
  }) => [
    _choice<String>(
      name: 'level',
      label: l10n.calendarDeskFilterLevel,
      value: f.levelId,
      options: _levels,
      onPicked: (v) => onChanged(f.withLevel(v)),
      width: width,
    ),
    _choice<ResourceKind>(
      name: 'kind',
      label: l10n.calendarDeskFilterKind,
      value: f.kind,
      options: _kinds,
      onPicked: (v) => onChanged(f.withKind(v)),
      width: width,
    ),
    _choice<String>(
      name: 'member',
      label: l10n.calendarDeskColumnMember,
      value: f.memberId,
      options: _members,
      onPicked: (v) => onChanged(f.withMember(v)),
      width: width,
    ),
    _choice<ReservationStatus>(
      name: 'state',
      label: l10n.calendarDeskColumnState,
      value: f.status,
      options: _states,
      onPicked: (v) => onChanged(f.withStatus(v)),
      width: width,
    ),
  ];

  /// The filters of [f] in use, in the order of the line.
  List<_InUse> inUse(DeskFilter f) => [
    if (f.levelId case final id?)
      (
        name: 'level',
        words: l10n.calendarDeskFilterChip(l10n.calendarDeskFilterLevel, _levels[id] ?? ''),
        cleared: f.withLevel(null),
      ),
    if (f.kind case final kind?)
      (
        name: 'kind',
        words: l10n.calendarDeskFilterChip(l10n.calendarDeskFilterKind, _kindWords(l10n, kind)),
        cleared: f.withKind(null),
      ),
    if (f.memberId case final id?)
      (
        name: 'member',
        words: l10n.calendarDeskFilterChip(l10n.calendarDeskColumnMember, members[id] ?? ''),
        cleared: f.withMember(null),
      ),
    if (f.status case final status?)
      (
        name: 'state',
        words: l10n.calendarDeskFilterChip(l10n.calendarDeskColumnState, myReservationStatusWords(l10n, status)),
        cleared: f.withStatus(null),
      ),
  ];
}

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

  Future<void> _openFilters(BuildContext context, _DeskFilters filters) =>
      showTask<void>(
        context,
        size: TaskSize.short,
        builder: (_) => _DeskFiltersTask(
          filters: filters,
          filter: filter,
          onChanged: onChanged,
        ),
      );

  /// One Filters control with the number in use, and the ones in use beside
  /// it as chips.
  Widget _folded(BuildContext context, _DeskFilters filters) {
    final inUse = filters.inUse(filter);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: deskFiltersKey,
          onPressed: () => _openFilters(context, filters),
          icon: const Icon(Icons.filter_list),
          label: Text(context.l10n.calendarDeskFiltersCount(inUse.length)),
        ),
        for (final f in inUse)
          InputChip(
            key: deskFilterChipKey(f.name),
            label: Text(f.words),
            onDeleted: () => onChanged(f.cleared),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = _DeskFilters(l10n, levels, members);
    return FilterBar(
      filters: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = deskFilterWidth(box.maxWidth);
            if (width == null) return _folded(context, filters);
            final fields = filters.fields(filter, onChanged, width: width);
            return Row(
              children: [
                for (final (i, field) in fields.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  field,
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        FilledButton.icon(
          key: _deskNewKey,
          onPressed: onNew,
          icon: const Icon(Icons.add),
          label: Text(l10n.calendarDeskNew),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            right: AppSpacing.md,
          ),
          child: MenuAnchor(
            menuChildren: [
              MenuItemButton(
                key: _deskExportKey,
                onPressed: onExport,
                leadingIcon: const Icon(Icons.file_download_outlined),
                child: Text(l10n.calendarDeskExport),
              ),
            ],
            builder: (context, menu, _) => IconButton(
              key: deskMoreKey,
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The four filters as a short task, each change applied at once.
class _DeskFiltersTask extends StatefulWidget {
  const _DeskFiltersTask({
    required this.filters,
    required this.filter,
    required this.onChanged,
  });

  final _DeskFilters filters;
  final DeskFilter filter;
  final ValueChanged<DeskFilter> onChanged;

  @override
  State<_DeskFiltersTask> createState() => _DeskFiltersTaskState();
}

class _DeskFiltersTaskState extends State<_DeskFiltersTask> {
  late DeskFilter _filter = widget.filter;

  void _change(DeskFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = widget.filters.fields(_filter, _change);
    return TaskChoice(
      title: l10n.calendarFilters,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, field) in fields.indexed) ...[
            if (i > 0) const FormGap(),
            field,
          ],
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('desk-filters-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
