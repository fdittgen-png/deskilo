// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../reservations/domain/walk_up_window.dart';
import '../../../reservations/presentation/widgets/booking_range_text.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../screens/kiosk_screen.dart' show KioskAction;

/// What the kiosk period step hands back: the window to book and — for
/// a reservation whose window has already begun — whether the member,
/// who is after all standing at the kiosk, wants to be checked in with
/// it right away.
typedef KioskPeriod = ({DateTime start, DateTime end, bool checkInNow});

/// The kiosk's period step (field request): BEFORE the badge is
/// presented the member says WHEN — a choice that follows the
/// workspace's booking granularity exactly, and never leaves today
/// (walk-ups belong to the day the person walked up).
///
///  * Day-based granularity: Morning / Afternoon / Day chips built from
///    the canonical working-hours windows. Windows already over are
///    disabled; a window already running starts NOW (a morning booked
///    at 10:00 books 10:00–12:00, not a past 08:00 the server would
///    refuse — the bug this step fixes). After the working day, one
///    "rest of the day" option remains, as the walk-up rule always
///    allowed.
///  * Time-based granularity: From/To pickers snapped to the slot grid
///    (5/15/30/60 min; real-hours and flexible snap to 5). Checking in
///    means BEING there, so its start is pinned to now and only the end
///    moves.
///
/// For a RESERVATION whose window contains now, the sheet also asks
/// "Check in right away?" (default on): confirming books and checks in
/// with one badge presentation — no second scan, no second dialog.
Future<KioskPeriod?> showKioskPeriodSheet(
  BuildContext context, {
  required KioskAction action,
  required BookingGranularity granularity,
  required DateTime now,
  required String targetName,
}) {
  assert(action != KioskAction.checkOut, 'check-out books no window');
  return showModalBottomSheet<KioskPeriod>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _KioskPeriodSheet(
      action: action,
      granularity: granularity,
      now: now,
      targetName: targetName,
    ),
  );
}

class _KioskPeriodSheet extends StatefulWidget {
  const _KioskPeriodSheet({
    required this.action,
    required this.granularity,
    required this.now,
    required this.targetName,
  });

  final KioskAction action;
  final BookingGranularity granularity;
  final DateTime now;
  final String targetName;

  @override
  State<_KioskPeriodSheet> createState() => _KioskPeriodSheetState();
}

/// One selectable day-part option (day-based granularity).
typedef _DayOption = ({
  String key,
  String label,
  DateTime start,
  DateTime end,
});

class _KioskPeriodSheetState extends State<_KioskPeriodSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _dayKey;
  bool _checkInNow = true;

  bool get _dayBased => widget.granularity.isDayBased;

  int get _snap => widget.granularity.stepMinutes ?? 5;

  @override
  void initState() {
    super.initState();
    final options = _dayBased ? _dayOptions(null) : const <_DayOption>[];
    if (options.isNotEmpty) {
      // Preselect the part of the day the member is standing in.
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
    // the shared window computes (next local midnight under day rules).
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
    // today and after now — the kiosk books the day you are standing in.
    final minutes = (picked.hour * 60 + picked.minute) ~/ _snap * _snap;
    var at = DateTime(
        now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The check-in question only makes sense for a reservation whose
    // window has already begun — the member is physically here.
    final offerCheckIn = widget.action == KioskAction.reserve &&
        !_start.isAfter(widget.now);
    final timeLabel = MaterialLocalizations.of(context);

    return SheetShell(
      title: widget.targetName,
      children: [
        Text(
          widget.action == KioskAction.checkIn
              ? (l10n?.kioskPeriodCheckInHint ??
                  'Until when will you stay? Checking in starts now.')
              : (l10n?.kioskPeriodReserveHint ??
                  'Pick the period — today only.'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (_dayBased)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _dayOptions(l10n))
                ChoiceChip(
                  key: ValueKey('kiosk-period-${option.key}'),
                  label: Text(option.label),
                  selected: _dayKey == option.key,
                  // Checking in = being there now: a part of the day
                  // that has not begun cannot be checked into.
                  onSelected: widget.action == KioskAction.checkIn &&
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
                  key: const ValueKey('kiosk-period-start'),
                  icon: const Icon(Icons.schedule_outlined),
                  // Check-in starts the moment the badge confirms.
                  onPressed: widget.action == KioskAction.checkIn
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
                  key: const ValueKey('kiosk-period-end'),
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
        const SizedBox(height: 8),
        Text(
          bookingRangeText(l10n, _start, _end),
          key: const ValueKey('kiosk-period-range'),
          style: theme.textTheme.bodySmall,
        ),
        if (offerCheckIn)
          SwitchListTile(
            key: const ValueKey('kiosk-period-checkin-now'),
            contentPadding: EdgeInsets.zero,
            title: Text(
                l10n?.kioskCheckInRightAway ?? 'Check in right away'),
            subtitle: Text(l10n?.kioskCheckInRightAwayHint ??
                "You're here — the reservation starts checked in."),
            value: _checkInNow,
            onChanged: (value) => setState(() => _checkInNow = value),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('kiosk-period-continue'),
          onPressed: () => Navigator.of(context).pop((
            start: _start,
            end: _end,
            checkInNow: offerCheckIn && _checkInNow,
          )),
          child: Text(l10n?.kioskPresentBadgeNext ?? 'Present the badge'),
        ),
      ],
    );
  }
}
