// SPDX-License-Identifier: 0BSD
//
// The hub's filter row: "All", one chip per kind, and the member the
// timeline is about. It lived inside calendar_hub_screen.dart until #843
// added a twelfth kind and pushed that file past its budget; the screen
// keeps the selection and the queries, this file draws the row.
import 'package:flutter/material.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'calendar_item_row.dart';

/// The horizontal filter row above the feed.
class CalendarKindChips extends StatelessWidget {
  const CalendarKindChips({
    super.key,
    required this.kinds,
    required this.offered,
    required this.onKinds,
    required this.memberLabel,
    required this.onPickMember,
  });

  /// The selected kinds, or null for "all of them".
  final Set<CalendarKind>? kinds;

  /// The kinds this workspace offers — a feature that is off has no chip.
  final List<CalendarKind> offered;
  final ValueChanged<Set<CalendarKind>?> onKinds;

  /// Null when the member chip is not on offer for this viewer.
  final String? memberLabel;
  final VoidCallback onPickMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(children: [
        FilterChip(
          key: const ValueKey('calendar-kind-all'),
          label: Text(l10n?.eventsFilterAll ?? 'All'),
          selected: kinds == null,
          onSelected: (_) => onKinds(null),
        ),
        for (final kind in offered) ...[
          const SizedBox(width: AppSpacing.xs),
          FilterChip(
            key: ValueKey('calendar-kind-${kind.wire}'),
            avatar: Icon(calendarKindIcon(kind), size: 18),
            label: Text(calendarKindLabel(l10n, kind)),
            selected: kinds?.contains(kind) ?? false,
            onSelected: (on) {
              final next = {...?kinds};
              on ? next.add(kind) : next.remove(kind);
              onKinds(next.isEmpty ? null : next);
            },
          ),
        ],
        if (memberLabel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          // Another member's dated facts — as far as the server lets
          // THIS viewer see them.
          ActionChip(
            key: const ValueKey('calendar-member-chip'),
            avatar: const Icon(Icons.person_search_outlined, size: 18),
            label: Text(memberLabel!),
            onPressed: onPickMember,
          ),
        ],
      ]),
    );
  }
}
