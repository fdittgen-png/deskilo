// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/public_facets.dart';

String publicFacetLabel(AppLocalizations l, String id) => switch (id) {
  'wifi' => l.discoveryFacetAmenityWifi,
  'meeting_room' => l.discoveryFacetAmenityMeetingRoom,
  'kitchen' => l.discoveryFacetAmenityKitchen,
  'printer' => l.discoveryFacetAmenityPrinter,
  'parking' => l.discoveryFacetAmenityParking,
  'bike_parking' => l.discoveryFacetAmenityBikeParking,
  'step_free_entrance' => l.discoveryFacetAccessibilityStepFreeEntrance,
  'accessible_toilet' => l.discoveryFacetAccessibilityAccessibleToilet,
  'lift' => l.discoveryFacetAccessibilityLift,
  _ => l.discoveryFieldNotPublished,
};

String publicOpeningHoursLine(BuildContext context, PublicOpeningHours? hours) {
  final l = context.l10n;
  if (hours == null) return l.discoveryFieldNotPublished;
  final note = hours.note;
  if (note != null) return '$note (${hours.timezone})';
  final weekdays = hours.weekdays!;
  if (weekdays.isEmpty) return l.discoveryHoursClosed;
  final format = appFormatOf(context);
  final names = format.dates(DateShape.weekday).dateSymbols.SHORTWEEKDAYS;
  final days = [...weekdays]..sort();
  String time(int minutes) => format.wallTime(
    DateTime.fromMillisecondsSinceEpoch(
      minutes * Duration.millisecondsPerMinute,
      isUtc: true,
    ),
  );
  return '${days.map((d) => names[d % DateTime.daysPerWeek]).join(', ')} · '
      '${time(hours.startMinutes!)}–${time(hours.endMinutes!)} (${hours.timezone})';
}
