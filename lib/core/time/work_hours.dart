// SPDX-License-Identifier: 0BSD
import 'workspace_time.dart';

/// The active workspace's working day (#446) — stored inside the
/// `booking_rules` jsonb (keys below) and enforced server-side by
/// `enforce_booking_rules` (migration 0087). Defaults: 8:00–17:00 with
/// the half-day boundary at 12:00, a half day billed as 4 hours and a
/// full day as 8 (the hour counts only matter under the `hours`
/// granularity, where the statement converts booked time into half-day
/// equivalents).
///
/// Ambient like `WorkspaceTime` and for the same reason: the
/// `HalfDayWindows` builders travel as function references through the
/// booking surface, so threading a config into every call would churn
/// all of it. The shell installs the active workspace's hours on
/// connect (and on profile switch); out-of-shell routes (kiosk) install
/// it themselves. Unset — tests, pre-connect boot — means [defaults].
class WorkHours {
  const WorkHours({
    required this.startMinutes,
    required this.halfBoundaryMinutes,
    required this.endMinutes,
    required this.halfDayHours,
    required this.fullDayHours,
  });

  /// Reads the work-hours keys of a `booking_rules` jsonb map. Absent
  /// keys take their defaults; an inconsistent triple (not start <
  /// boundary < end within one day) falls back to [defaults] entirely —
  /// the server does the same, so client and constraint stay aligned.
  factory WorkHours.fromRules(Map<String, dynamic> rules) {
    int? asInt(String key) => (rules[key] as num?)?.toInt();
    final hours = WorkHours(
      startMinutes: asInt(keyStart) ?? defaults.startMinutes,
      halfBoundaryMinutes: asInt(keyBoundary) ?? defaults.halfBoundaryMinutes,
      endMinutes: asInt(keyEnd) ?? defaults.endMinutes,
      halfDayHours: asInt(keyHalfDayHours) ?? defaults.halfDayHours,
      fullDayHours: asInt(keyFullDayHours) ?? defaults.fullDayHours,
    );
    return hours.isValid ? hours : defaults;
  }

  /// Workspace-local minutes after midnight the working day starts.
  final int startMinutes;

  /// Workspace-local minutes after midnight separating the two halves.
  final int halfBoundaryMinutes;

  /// Workspace-local minutes after midnight the working day ends.
  final int endMinutes;

  /// Hours billed as one half day under the `hours` granularity.
  final int halfDayHours;

  /// Hours billed as one full day under the `hours` granularity.
  final int fullDayHours;

  /// 8:00–17:00, boundary 12:00, half day 4h, full day 8h (#446).
  static const WorkHours defaults = WorkHours(
    startMinutes: 8 * 60,
    halfBoundaryMinutes: 12 * 60,
    endMinutes: 17 * 60,
    halfDayHours: 4,
    fullDayHours: 8,
  );

  // booking_rules keys — shared with enforce_booking_rules and
  // member_statement (0087); pinned by test, renaming is a
  // data-compatibility decision.
  static const String keyStart = 'work_start_minutes';
  static const String keyBoundary = 'half_boundary_minutes';
  static const String keyEnd = 'work_end_minutes';
  static const String keyHalfDayHours = 'half_day_hours';
  static const String keyFullDayHours = 'full_day_hours';

  static WorkHours _current = defaults;

  /// The ambient working day ([defaults] until a workspace installed
  /// its own).
  static WorkHours get current => _current;

  /// Installs [hours] as the ambient working day; null restores
  /// [defaults].
  static void install(WorkHours? hours) => _current = hours ?? defaults;

  /// Back to [defaults] (tests).
  static void reset() => _current = defaults;

  /// start < boundary < end, all within one day, positive hour counts.
  bool get isValid =>
      startMinutes >= 0 &&
      startMinutes < halfBoundaryMinutes &&
      halfBoundaryMinutes < endMinutes &&
      endMinutes <= 24 * 60 &&
      halfDayHours > 0 &&
      fullDayHours >= halfDayHours;

  /// The work-hours keys as they are merged into `booking_rules`.
  Map<String, int> toRules() => {
        keyStart: startMinutes,
        keyBoundary: halfBoundaryMinutes,
        keyEnd: endMinutes,
        keyHalfDayHours: halfDayHours,
        keyFullDayHours: fullDayHours,
      };

  WorkHours copyWith({
    int? startMinutes,
    int? halfBoundaryMinutes,
    int? endMinutes,
    int? halfDayHours,
    int? fullDayHours,
  }) =>
      WorkHours(
        startMinutes: startMinutes ?? this.startMinutes,
        halfBoundaryMinutes: halfBoundaryMinutes ?? this.halfBoundaryMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        halfDayHours: halfDayHours ?? this.halfDayHours,
        fullDayHours: fullDayHours ?? this.fullDayHours,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkHours &&
      other.startMinutes == startMinutes &&
      other.halfBoundaryMinutes == halfBoundaryMinutes &&
      other.endMinutes == endMinutes &&
      other.halfDayHours == halfDayHours &&
      other.fullDayHours == fullDayHours;

  @override
  int get hashCode => Object.hash(startMinutes, halfBoundaryMinutes,
      endMinutes, halfDayHours, fullDayHours);
}

/// #908 — the open day of [on], as instants, on the WORKSPACE clock.
///
/// "08:00–17:00" is a wall-clock statement about the space, not about
/// the device reading it. A naive `DateTime(y, m, d).add(startMinutes)`
/// agrees with the setting only while the two clocks coincide; from a
/// device an hour away it slides the whole day by the offset, so a seat
/// booked for the morning is placed in the afternoon of the plan and
/// the day sheet offers free stretches that are not free.
({DateTime start, DateTime end}) workDayWindow(
  DateTime on, {
  WorkHours? hours,
}) {
  final h = hours ?? WorkHours.current;
  DateTime at(int minutes) =>
      WorkspaceTime.at(on.year, on.month, on.day, minutes ~/ 60, minutes % 60);
  return (start: at(h.startMinutes), end: at(h.endMinutes));
}
