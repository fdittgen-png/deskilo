// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/walk_up_window.dart';
import 'booking_range_text.dart';

/// What a space act does — the three operations the kiosk one-sheet
/// offers (#529) and, since #622, the app's scan flow too.
enum SpaceAction { checkIn, reserve, checkOut }

/// The state of the act form at completion time: the action, the window
/// it books (ignored for check-out) and whether a begun reservation
/// starts checked in.
typedef SpaceActChoice = ({
  SpaceAction action,
  DateTime start,
  DateTime end,
  bool checkInNow,
});

/// THE action + derived-period core of the kiosk one-sheet (#529),
/// extracted for #622 so the app's scan flow offers the SAME options
/// under the SAME rules — one implementation, two completions: the
/// kiosk appends its badge reader, the signed-in app a confirm button.
///
/// Check in is preselected, the period ALREADY DERIVED from the
/// workspace settings (granularity + working hours, clamped to now),
/// and the rule it derives from is spelled out. [keyPrefix] keeps the
/// kiosk's historical widget keys ('kiosk-…') stable while other
/// surfaces get their own.
class SpaceActForm extends StatefulWidget {
  const SpaceActForm({
    super.key,
    required this.granularity,
    required this.now,
    this.keyPrefix = 'space-act',
    this.footer,
  });

  final BookingGranularity granularity;
  final DateTime now;
  final String keyPrefix;

  /// Rendered under the form with the CURRENT choice — the reactive
  /// seam for blocked-space info and the completion affordance.
  final Widget Function(BuildContext context, SpaceActChoice choice)? footer;

  @override
  State<SpaceActForm> createState() => SpaceActFormState();
}

/// One selectable day-part option (day-based granularity).
typedef _DayOption = ({String key, String label, DateTime start, DateTime end});

class SpaceActFormState extends State<SpaceActForm> {
  SpaceAction _action = SpaceAction.checkIn;
  late DateTime _start;
  late DateTime _end;
  String? _dayKey;
  bool _checkInNow = true;

  bool get _dayBased => widget.granularity.isDayBased;

  int get _snap => widget.granularity.stepMinutes ?? 5;

  /// The form's one truth for completers (badge, confirm button):
  /// [SpaceActChoice.checkInNow] is only true for a reservation whose
  /// window has already begun — the "check in right away" switch.
  SpaceActChoice get choice => (
    action: _action,
    start: _start,
    end: _end,
    checkInNow:
        _action == SpaceAction.reserve &&
        !_start.isAfter(widget.now) &&
        _checkInNow,
  );

  @override
  void initState() {
    super.initState();
    _resetWindow();
  }

  /// The default window for the CURRENT action — derived, never asked:
  /// the day part the member is standing in (day-based) or the shared
  /// walk-up window, start clamped to now.
  void _resetWindow() {
    final options = _dayBased ? _dayOptions(null) : const <_DayOption>[];
    if (options.isNotEmpty) {
      final current = options.firstWhere(
        (o) => !o.start.isAfter(widget.now) && o.end.isAfter(widget.now),
        orElse: () => options.first,
      );
      _dayKey = current.key;
      _start = current.start;
      _end = current.end;
    } else {
      final window = walkUpWindow(widget.granularity, widget.now);
      _start = window.start.isBefore(widget.now) ? widget.now : window.start;
      _end = window.end;
    }
  }

  /// Today's bookable day parts, already clamped to now. Passing [l10n]
  /// labels them; initState passes null (keys only).
  List<_DayOption> _dayOptions(AppLocalizations? l10n) {
    final now = widget.now;
    final morning = HalfDayWindows.morning(now);
    final afternoon = HalfDayWindows.afternoon(now);
    final fullDay = HalfDayWindows.fullDay(now);
    DateTime clamp(DateTime start) => start.isBefore(now) ? now : start;
    final options = <_DayOption>[
      if (widget.granularity != BookingGranularity.fullDay &&
          morning.end.isAfter(now))
        (
          key: 'morning',
          label: l10n?.planMorningChip ?? 'Morning',
          start: clamp(morning.start),
          end: morning.end,
        ),
      if (widget.granularity != BookingGranularity.fullDay &&
          afternoon.end.isAfter(now))
        (
          key: 'afternoon',
          label: l10n?.planAfternoonChip ?? 'Afternoon',
          start: clamp(afternoon.start),
          end: afternoon.end,
        ),
      if (fullDay.end.isAfter(now))
        (
          key: 'day',
          label: l10n?.planFullDayChip ?? 'Day',
          start: clamp(fullDay.start),
          end: fullDay.end,
        ),
    ];
    if (options.isNotEmpty) return options;
    // After the working day: the walk-up overtime rule — now → the end
    // the shared window computes.
    final overtime = walkUpWindow(widget.granularity, now);
    return [
      (
        key: 'rest',
        label: l10n?.kioskRestOfDay ?? 'Rest of the day',
        start: overtime.start,
        end: overtime.end,
      ),
    ];
  }

  Future<void> _pickTime({required bool isStart}) async {
    final base = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null || !mounted) return;
    final now = widget.now;
    // Snap DOWN to the workspace grid, then keep the window inside
    // today and after now — the act books the day you are standing in.
    final minutes = (picked.hour * 60 + picked.minute) ~/ _snap * _snap;
    var at = DateTime(
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    setState(() {
      if (isStart) {
        if (at.isBefore(now)) at = now;
        _start = at;
        if (!_end.isAfter(_start)) {
          _end = _start.add(Duration(minutes: _snap));
        }
      } else {
        if (!at.isAfter(_start)) at = _start.add(Duration(minutes: _snap));
        _end = at;
      }
    });
  }

  /// The rule the derived window follows, spelled out — the settings
  /// ARE the explanation ("include the settings on which base the
  /// check-in must be done").
  String _basisLine(AppLocalizations? l10n, MaterialLocalizations time) {
    final granularityLabel = switch (widget.granularity) {
      BookingGranularity.flexible =>
        l10n?.availabilityGranularityFlexible ?? 'Free time period',
      BookingGranularity.halfDay =>
        l10n?.availabilityGranularityHalfDay ??
            'Half days (morning & afternoon)',
      BookingGranularity.minutes5 =>
        l10n?.availabilityGranularity5 ?? '5-minute slots',
      BookingGranularity.minutes15 =>
        l10n?.availabilityGranularity15 ?? '15-minute slots',
      BookingGranularity.minutes30 =>
        l10n?.availabilityGranularity30 ?? '30-minute slots',
      BookingGranularity.minutes60 =>
        l10n?.availabilityGranularity60 ?? '1-hour slots',
      BookingGranularity.fullDay =>
        l10n?.availabilityGranularityFullDay ?? 'Full days only',
      BookingGranularity.hours =>
        l10n?.availabilityGranularityHours ?? 'Real hours',
    };
    String range(({DateTime start, DateTime end}) w) =>
        '${time.formatTimeOfDay(TimeOfDay.fromDateTime(w.start))}–'
        '${time.formatTimeOfDay(TimeOfDay.fromDateTime(w.end))}';
    final now = widget.now;
    final hours = widget.granularity == BookingGranularity.halfDay
        ? '${range(HalfDayWindows.morning(now))} / '
              '${range(HalfDayWindows.afternoon(now))}'
        : range(HalfDayWindows.fullDay(now));
    return l10n?.kioskBasis(granularityLabel, hours) ??
        '$granularityLabel · today $hours';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final timeLabel = MaterialLocalizations.of(context);
    final prefix = widget.keyPrefix;
    final booksWindow = _action != SpaceAction.checkOut;
    final offerCheckIn =
        _action == SpaceAction.reserve && !_start.isAfter(widget.now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The action — Check in preselected: the walk-up's one truth.
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: ValueKey('$prefix-check-in'),
              avatar: const Icon(Icons.login_outlined, size: 18),
              label: Text(l10n?.kioskCheckIn ?? 'Check in'),
              selected: _action == SpaceAction.checkIn,
              onSelected: (_) => setState(() {
                _action = SpaceAction.checkIn;
                _resetWindow();
              }),
            ),
            ChoiceChip(
              key: ValueKey('$prefix-reserve'),
              avatar: const Icon(Icons.event_available_outlined, size: 18),
              label: Text(l10n?.kioskReserve ?? 'Reserve'),
              selected: _action == SpaceAction.reserve,
              onSelected: (_) => setState(() {
                _action = SpaceAction.reserve;
                _resetWindow();
              }),
            ),
            ChoiceChip(
              key: ValueKey('$prefix-check-out'),
              avatar: const Icon(Icons.logout_outlined, size: 18),
              label: Text(l10n?.kioskCheckOut ?? 'Check out'),
              selected: _action == SpaceAction.checkOut,
              onSelected: (_) => setState(() => _action = SpaceAction.checkOut),
            ),
          ],
        ),
        if (booksWindow) ...[
          const SizedBox(height: 12),
          if (_dayBased)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _dayOptions(l10n))
                  ChoiceChip(
                    key: ValueKey('$prefix-period-${option.key}'),
                    label: Text(option.label),
                    selected: _dayKey == option.key,
                    // Checking in = being there now: a part of the day
                    // that has not begun cannot be checked into.
                    onSelected:
                        _action == SpaceAction.checkIn &&
                            option.start.isAfter(widget.now)
                        ? null
                        : (_) => setState(() {
                            _dayKey = option.key;
                            _start = option.start;
                            _end = option.end;
                          }),
                  ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('$prefix-period-start'),
                    icon: const Icon(Icons.schedule_outlined),
                    // Check-in starts the moment the act confirms.
                    onPressed: _action == SpaceAction.checkIn
                        ? null
                        : () => _pickTime(isStart: true),
                    label: Text(
                      '${l10n?.planFromLabel ?? 'From'} '
                      '${timeLabel.formatTimeOfDay(TimeOfDay.fromDateTime(_start))}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('$prefix-period-end'),
                    icon: const Icon(Icons.schedule),
                    onPressed: () => _pickTime(isStart: false),
                    label: Text(
                      '${l10n?.planToLabel ?? 'To'} '
                      '${timeLabel.formatTimeOfDay(TimeOfDay.fromDateTime(_end))}',
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            bookingRangeText(l10n, _start, _end),
            key: ValueKey('$prefix-period-range'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (offerCheckIn)
            SwitchListTile(
              key: ValueKey('$prefix-period-checkin-now'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n?.kioskCheckInRightAway ?? 'Check in right away'),
              value: _checkInNow,
              onChanged: (value) => setState(() => _checkInNow = value),
            ),
          const SizedBox(height: 2),
          // The rule behind the numbers — settings transparency.
          Text(
            _basisLine(l10n, timeLabel),
            key: ValueKey('$prefix-basis'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (widget.footer case final footer?) footer(context, choice),
      ],
    );
  }
}
