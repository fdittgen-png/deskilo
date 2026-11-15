// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The hub's filter row: "All", one chip per kind, and the member the
// timeline is about. It lived inside calendar_hub_screen.dart until #843
// added a twelfth kind and pushed that file past its budget; the screen
// keeps the selection and the queries, this file draws the row.
import 'package:flutter/material.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/calendar/calendar_kind_labels.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';

/// The horizontal filter row above the feed.
class CalendarKindChips extends StatelessWidget {
  const CalendarKindChips({
    super.key,
    required this.kinds,
    required this.offered,
    required this.onKinds,
    required this.memberLabel,
    required this.onPickMember,
    required this.myBookings,
    required this.onMyBookings,
    required this.onReset,
  });

  /// The selected kinds, or null for "all of them".
  final Set<CalendarKind>? kinds;

  /// The kinds this workspace offers — a feature that is off has no chip.
  final List<CalendarKind> offered;
  final ValueChanged<Set<CalendarKind>?> onKinds;

  /// Null when the member chip is not on offer for this viewer.
  final String? memberLabel;
  final VoidCallback onPickMember;
  final bool myBookings;
  final VoidCallback onMyBookings, onReset;

  /// The kinds, in a sheet: "All", one chip per kind, and Clear. Each
  /// choice applies at once, so the list behind follows.
  Future<void> _openKinds(BuildContext context) {
    var chosen = kinds;
    return showAppSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final l10n = sheet.l10n;
          void choose(Set<CalendarKind>? next) {
            setSheet(() => chosen = next);
            onKinds(next);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.lgAll,
              child: Column(
                key: const ValueKey('calendar-filters-sheet'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.calendarFilters,
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      FilterChip(
                        key: const ValueKey('calendar-kind-all'),
                        label: Text(l10n.eventsFilterAll),
                        selected: chosen == null,
                        onSelected: (_) => choose(null),
                      ),
                      for (final kind in offered)
                        FilterChip(
                          key: ValueKey('calendar-kind-${kind.wire}'),
                          // #1191 — the chip's own tick would land on this.
                          showCheckmark: false,
                          avatar: Icon(calendarKindIcon(kind), size: 18),
                          label: Text(calendarKindLabel(l10n, kind)),
                          selected: chosen?.contains(kind) ?? false,
                          onSelected: (on) {
                            final next = {...?chosen};
                            on ? next.add(kind) : next.remove(kind);
                            choose(next.isEmpty ? null : next);
                          },
                        ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const ValueKey('calendar-filters-clear'),
                      onPressed: chosen == null ? null : () => choose(null),
                      child: Text(l10n.calendarFiltersClear),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = l10n;
    final scopeLabel = '${memberLabel ?? words.calendarMemberMe} · ${kinds == null ? words.eventsFilterAll : kinds!.map((k) => calendarKindLabel(words, k)).join(', ')}';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: AppSpacing.smH, child: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(key: const ValueKey('calendar-my-bookings'),
              showCheckmark: false, avatar: const Icon(Icons.event_seat_outlined, size: 18),
              label: Text(words.uxMyBookings), selected: myBookings,
              onSelected: (_) => onMyBookings()),
          if (memberLabel != null) ActionChip(
            key: const ValueKey('calendar-member-chip'),
            avatar: const Icon(Icons.person_search_outlined, size: 18),
            label: Text(memberLabel!), onPressed: onPickMember),
          // #4021 — the kinds sit behind one control that says how many are
          // chosen; the summary line below says which.
          ActionChip(
            key: const ValueKey('calendar-filters'),
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(kinds == null
                ? words.calendarFilters
                : '${words.calendarFilters} · ${kinds!.length}'),
            onPressed: () => _openKinds(context),
          ),
          IconButton(key: const ValueKey('calendar-reset-filters'),
              tooltip: words.uxResetFilters, onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined)),
        ],
      )),
      Padding(padding: AppSpacing.smH, child: Align(
        alignment: Alignment.centerLeft,
        child: Text(scopeLabel, key: const ValueKey('calendar-filter-summary'),
            style: Theme.of(context).textTheme.bodySmall),
      )),
    ]);
  }
}
