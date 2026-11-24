// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/public_network/public_network_operations.dart';

/// Stable public wire ids; labels belong to the presentation layer.
abstract final class PublicFacets {
  /// The two facet fields of a public page, in the order the editor shows
  /// them.
  static const amenities = 'amenities';
  static const accessibility = 'accessibility';
  static const fields = [amenities, accessibility];

  static List<String> ids(String field) =>
      publicNetworkSchemas['PublicationInput']!.fields[field]!.values;

  /// Missing or unreadable facts are unknown, never a negative assertion.
  static List<String>? read(String field, Object? raw) {
    if (raw is! List ||
        raw.length > ids(field).length ||
        raw.any((v) => v is! String || !ids(field).contains(v)) ||
        raw.toSet().length != raw.length) {
      return null;
    }
    return List<String>.unmodifiable(raw.cast<String>());
  }
}

/// Regular hours in the business's timezone, not live availability.
class PublicOpeningHours {
  const PublicOpeningHours._(
    this.timezone,
    this.weekdays,
    this.startMinutes,
    this.endMinutes,
    this.note,
  );

  static PublicOpeningHours? read(Object? raw) {
    if (raw is! Map || raw['timezone'] is! String) return null;
    final timezone = raw['timezone'] as String;
    if (timezone.isEmpty) return null;
    final note = raw['note'];
    if (note is String && note.trim().isNotEmpty) {
      return PublicOpeningHours._(timezone, null, null, null, note);
    }
    final days = raw['weekdays'],
        start = raw['start_minutes'],
        end = raw['end_minutes'];
    final weekdayField =
        publicNetworkSchemas['PublicOpeningHours']!.fields['weekdays']!;
    if (days is! List ||
        days.length > DateTime.daysPerWeek ||
        days.any(
          (d) => d is! int || d < weekdayField.min! || d > weekdayField.max!,
        ) ||
        days.toSet().length != days.length ||
        start is! int ||
        end is! int ||
        start < 0 ||
        start >= end ||
        end > Duration.minutesPerDay) {
      return null;
    }
    return PublicOpeningHours._(
      timezone,
      List<int>.unmodifiable(days.cast<int>()),
      start,
      end,
      null,
    );
  }

  final String timezone;
  final List<int>? weekdays;
  final int? startMinutes, endMinutes;
  final String? note;
}
