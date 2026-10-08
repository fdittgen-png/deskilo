// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import 'calendar_item_row.dart';

/// Uses the same authorized reservation and location reads as booking details.
/// Missing or unreadable sources retain the feed's supplied label or a neutral
/// fallback; opening the original source remains the row's action.
class CalendarBookingTitle extends ConsumerWidget {
  const CalendarBookingTitle({super.key, required this.item});
  final CalendarItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final id = (item.link! as ReservationLink).id;
    final reservations = ref
        .watch(reservationsForMonthProvider(monthKeyOf(item.at)))
        .value;
    final reservation = reservations?.where((r) => r.id == id).firstOrNull;
    final seatId = reservation?.seatId;
    final officeId = reservation?.officeId;
    final target = seatId != null
        ? ref.watch(seatContextProvider(seatId)).value
        : officeId != null
        ? ref.watch(officeContextProvider(officeId)).value
        : null;
    final names = ref.watch(targetNamesProvider).value ?? const {};
    final location = target?.locationLine ?? '';
    final supplied = item.title.trim();
    final resource = location.isNotEmpty
        ? location
        : reservation?.spaceNameFrom(names) ?? '';
    final label = resource.isNotEmpty
        ? resource
        : supplied.isNotEmpty &&
              !CalendarKind.values.any((k) => k.wire == supplied)
        ? supplied
        : words.uxBookingResourceUnavailable;
    return Text(
      '${calendarKindLabel(words, item.kind)} · $label',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
