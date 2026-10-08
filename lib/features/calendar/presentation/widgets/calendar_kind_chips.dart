// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The hub's filter row: "All", one chip per kind, and the member the
// timeline is about. It lived inside calendar_hub_screen.dart until #843
// added a twelfth kind and pushed that file past its budget; the screen
// keeps the selection and the queries, this file draws the row.
import 'package:flutter/material.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import 'calendar_item_row.dart';
import '../../../../core/ui/edge_fade_scroll.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = l10n ?? AppLocalizationsEn();
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
      EdgeFadeScroll(
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
            // #1191 — the chip's own tick would land on this.
            showCheckmark: false,
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
      ]),
    ),
    ]);
  }
}
