// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/l10n/lexicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import 'booking_review_summary.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/booking_gate.dart';
import '../../domain/place_feedback.dart';
import 'place_feedback_bar.dart';
import '../../domain/picked_time.dart';
import '../../domain/reservation_repository.dart';
import 'booking_range_text.dart';
import 'booking_sheet_parts.dart';
import '../../../../core/i18n/format_controller.dart';

/// What the booking sheet returns: the chosen window (start + end), an
/// optional recurrence and who the booking is for (null/self = caller).
class BookingChoice {
  const BookingChoice(
    this.start,
    this.end,
    this.pattern,
    this.until,
    this.forMemberId, {
    this.block = false,
    this.checkInNow = false,
    this.walkUp = false,
  });

  final DateTime start;
  final DateTime end;
  final SeriesPattern? pattern;
  final DateTime? until;
  final String? forMemberId;

  /// True: block the seat for maintenance instead of booking it (#161).
  /// Every other field is ignored then.
  final bool block;

  /// #772 — reserve AND check in in one gesture (browsed window contains
  /// now); false for a plain reservation.
  final bool checkInNow;

  /// #2016 — the action CONFIRMED in the sheet was a walk-up check-in
  /// ("I am sitting here now"). The caller writes what the member chose
  /// here, never a flag it captured before the sheet opened.
  final bool walkUp;
}

/// #2016 — the walk-up a reservation sheet may switch to: "check in now"
/// as an explicit choice, with its own window and next-booking cap.
typedef WalkUpOption = ({
  DateTime start,
  DateTime end,
  DateTime? cap,
  bool capped,
});

/// Bottom-sheet body for booking a seat (#206): walk-up check-in or a
/// punctual reservation. The **period is editable right here** — a
/// granularity-aware picker matching the workspace configuration
/// (Morning/Afternoon/Full day under half-days, From/To under minute
/// grids and flexible, a locked Full day under full-day granularity) —
/// alongside the "Book for" picker (#106), the **repeat** picker (spec
/// §5.2) and the owner/admin blocking affordance (#161).
///
/// Pure presentation: pops with a [BookingChoice] (or null on dismiss);
/// the caller runs the repository calls and maps errors.
class BookingSheet extends StatefulWidget {
  const BookingSheet({
    super.key,
    this.seatId,
    required this.seatName,
    this.resourceContext = const [],
    this.timezone,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
    this.granularity = BookingGranularity.flexible,
    this.walkUp = true,
    this.liveWindow = false,
    this.fixedEnd = false,
    this.members = const [],
    this.myMemberId,
    this.allowSeries = true,
    this.allowBlocking = false,
    this.refusalOf,
    this.refusalTextOf,
    this.walkUpOption,
    this.now,
    this.overlaps,
    this.onFieldCommitted,
  });

  /// #1865 — told WHICH field a person committed ('time', 'for_whom',
  /// 'repeat', 'check_in'), never its value; the task recorder's seam.
  final void Function(String field)? onFieldCommitted;

  /// Null for a WHOLE-SPACE booking (0065): the sheet then shows no
  /// accessory row; [seatName] carries the space's name either way.
  final String? seatId;
  final String seatName;
  final List<String> resourceContext;
  final String? timezone;
  final DateTime start;
  final DateTime initialEnd;
  final DateTime? cap;
  final bool capped;

  /// The workspace booking granularity (#200/0032): drives which period
  /// picker the sheet shows so the choice always fits the configuration.
  final BookingGranularity granularity;

  /// True: the sheet STARTS as a live walk-up (check in now). False: a
  /// punctual reservation. With [walkUpOption] the member switches
  /// between the two; the confirmed one is [BookingChoice.walkUp].
  final bool walkUp;

  /// #2016 — offers "Check in now" beside "Reserve" as an explicit
  /// choice. Null: the sheet has one action only.
  final WalkUpOption? walkUpOption;

  /// #2016 — this moment, when known: the "check in right away" switch
  /// then follows the window being EDITED (it shows only while that
  /// window contains now), not the one the hub browsed when it opened.
  final DateTime? now;

  /// #2016 — whether the seat is already taken somewhere in a window: a
  /// reservation that overlaps another booking cannot be confirmed.
  final bool Function(DateTime start, DateTime end)? overlaps;

  /// #772 — the browsed window CONTAINS this very moment: the plain
  /// reserve gains a "check in right away" switch (on by default), so
  /// the Morning chip during the morning can check a member in — the
  /// map then matches what the seat-QR sheet always could.
  final bool liveWindow;

  /// Day-based granularity (#201): the window covers a canonical day
  /// window, edited via the period chips rather than a free "Until".
  final bool fixedEnd;

  /// Active members an admin can book for (#106); empty for non-admins
  /// or when the bookForOthers feature is off (#146).
  final List<({String id, String name})> members;
  final String? myMemberId;

  /// Series booking feature gate (#146): false hides the repeat picker.
  final bool allowSeries;

  /// Seat-blocking affordance (#161): true adds "Make not reservable" for
  /// owners and delegated admins.
  final bool allowBlocking;

  /// #814 — the booking gate, asked for every window the member picks:
  /// a refusal disables the confirm button and names its reason. Null
  /// (feature off) keeps the server as the only judge.
  final BookingRefusal? Function(DateTime start, DateTime end, bool walkUp)?
      refusalOf;
  final String Function(BookingRefusal refusal)? refusalTextOf;

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  // OFF by default: a live window must stay bookable as a plain
  // reservation — checking in is the member's explicit extra gesture.
  bool _checkInNow = false;
  late bool _walkUp = widget.walkUp;
  late DateTime _start = widget.walkUp && widget.walkUpOption != null
      ? widget.walkUpOption!.start
      : widget.start;
  late DateTime _end = widget.walkUp && widget.walkUpOption != null
      ? widget.walkUpOption!.end
      : widget.initialEnd;

  /// #2016 — the reservation draft kept aside while the member looks at
  /// the walk-up, so switching back restores what they had chosen.
  late ({DateTime start, DateTime end}) _reserveDraft = (
    start: widget.start,
    end: widget.initialEnd,
  );

  DateTime? get _cap => _walkUp && widget.walkUpOption != null
      ? widget.walkUpOption!.cap
      : widget.cap;
  bool get _capped => _walkUp && widget.walkUpOption != null
      ? widget.walkUpOption!.capped
      : widget.capped;

  /// #772/#2016 — the edited window contains this very moment.
  bool get _liveWindow {
    if (_walkUp) return false;
    final now = widget.now;
    if (now == null) return widget.liveWindow;
    return !_start.isAfter(now) && _end.isAfter(now);
  }

  void _setMode(bool walkUp) {
    final option = widget.walkUpOption;
    if (option == null || walkUp == _walkUp) return;
    setState(() {
      if (walkUp) {
        _reserveDraft = (start: _start, end: _end);
        _start = option.start;
        _end = option.end;
        _pattern = null;
      } else {
        _start = _reserveDraft.start;
        _end = _reserveDraft.end;
      }
      _walkUp = walkUp;
      _checkInNow = false;
    });
  }
  SeriesPattern? _pattern;
  late DateTime _until = widget.start.add(const Duration(days: 28));
  // #638 — the subject defaults to me, EXCEPT when the caller offered a
  // roster I am not part of (a delegated admin who may assign a whole
  // level without holding the personal grant): the booking then lands on
  // the first candidate, never silently on a subject the server refuses.
  late String? _forMemberId = widget.members.isEmpty ||
          widget.members.any((m) => m.id == widget.myMemberId)
      ? widget.myMemberId
      : widget.members.first.id;

  bool get _forOther =>
      _forMemberId != null && _forMemberId != widget.myMemberId;

  /// The workspace-local day the booking sits on (canonical windows).
  DateTime get _day => WorkspaceTime.dateOf(widget.start);

  String _patternLabel(AppLocalizations? l10n, SeriesPattern? pattern) {
    return switch (pattern) {
      null => l10n?.repeatNone ?? 'Does not repeat',
      SeriesPattern.daily => l10n?.repeatDaily ?? 'Every day',
      SeriesPattern.weekdays => l10n?.repeatWeekdays ?? 'Every weekday',
      SeriesPattern.weekly => l10n?.repeatWeekly ?? 'Weekly',
    };
  }

  bool _isWindow(HalfDayWindow w) =>
      _start.isAtSameMomentAs(w.start) && _end.isAtSameMomentAs(w.end);

  void _selectWindow(HalfDayWindow w) {
    setState(() {
      _start = w.start;
      _end = w.end;
    });
    widget.onFieldCommitted?.call('time');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = l10n ?? AppLocalizationsEn();
    final timeFormat = appFormatOf(context); // #1150
    // Half-day granularity offers the three canonical windows (hours
    // offers them as shortcuts too, #446); full-day is a single locked
    // window; a walk-up keeps its computed end — except under hours,
    // where the implicit reservation lets the user set its end.
    final showHalfDayPicker = !_walkUp &&
        (widget.granularity == BookingGranularity.halfDay ||
            widget.granularity == BookingGranularity.hours);
    final showTimePickers = !_walkUp && !widget.fixedEnd;
    final hoursWalkUp = _walkUp &&
        widget.granularity == BookingGranularity.hours;
    // #574 — minute-grid workspaces get the SLIDER: the duration in the
    // workspace's own steps, walk-up and punctual alike (a 10:00 arrival
    // under a 5-minute grid slides to "until 12:00" in 5-minute ticks).
    final gridStep = switch (widget.granularity) {
      BookingGranularity.minutes5 ||
      BookingGranularity.minutes15 ||
      BookingGranularity.minutes30 ||
      BookingGranularity.minutes60 =>
        widget.granularity.stepMinutes,
      _ => null,
    };
    final maxDuration =
        gridStep == null ? 0 : _maxDurationMinutes(gridStep);
    final showDurationSlider =
        gridStep != null && maxDuration >= gridStep && !widget.fixedEnd;
    // #814 — asked on EVERY build: the window changes with each chip,
    // picker and slider tick, and the verdict must follow it.
    final refusal = widget.refusalOf?.call(_start, _end, _walkUp);
    // #2016 — a reservation may not overlap another booking on the seat;
    // a walk-up is already capped at the next one.
    final overlap =
        !_walkUp && (widget.overlaps?.call(_start, _end) ?? false);
    final showRepeat = !_walkUp && !_forOther && widget.allowSeries;
    final offerModes = widget.walkUpOption != null && !_forOther;

    return BookingSheetFrame(
      action: FilledButton(
              key: const ValueKey('booking-confirm'),
              onPressed: refusal != null || overlap
                  ? null
                  : () => Navigator.of(context).pop(
                BookingChoice(
                  checkInNow: _liveWindow && _checkInNow,
                  walkUp: _walkUp,
                  _start,
                  _end,
                  _forOther ? null : _pattern,
                  _forOther || _pattern == null ? null : _until,
                  _forMemberId,
                ),
              ),
              child: Text(
                _forOther
                    ? (l10n?.planSendForConfirmation ??
                        'Send for confirmation')
                    : _walkUp
                        ? (lexiconText(context, key: 'planCheckInButton', fallback: l10n?.planCheckInButton ?? 'Check in'))
                        : (lexiconText(context, key: 'planReserveButton', fallback: l10n?.planReserveButton ?? 'Reserve')),
              ),
            ),
      children: [
            Row(children: [
              Expanded(
                child: Text(
                  widget.seatName.isEmpty
                      ? (lexiconText(context, key: 'planCheckInTitle', fallback: l10n?.planCheckInTitle ?? 'Check in'))
                      : widget.seatName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // #763 — ONE dot for the whole sheet, beside its header.
              // The kiosk never opens this sheet (its wall flow is
              // SpaceActForm), and pure-widget tests pump it without a
              // ProviderScope: no scope, no dot.
              if (_hasProviderScope(context))
                HelpDot(
                  l10n?.helpHintReserveTip4Topic ?? 'How booking behaves',
                  anchor: HelpAnchor.reservationsBookingSheet,
                ),
            ]),
            if (offerModes) ...[
              const SizedBox(height: AppSpacing.sm),
              BookingModeSelector(walkUp: _walkUp, onChanged: _setMode),
            ],
            if (offerModes)
              Text(words.uxBookingModesHelp,
                style: Theme.of(context).textTheme.bodySmall),

            BookingReviewSummary(
              resource: [...widget.resourceContext, widget.seatName],
              person: widget.members.where((m) => m.id == _forMemberId)
                  .firstOrNull?.name ?? words.levelAssignMyself,
              window: (start: _start, end: _end), timezone: widget.timezone, walkUp: _walkUp,
              today: WorkspaceTime.dateOf(widget.now ?? widget.start),
              recurrence: _pattern == null || _forOther
                  ? _patternLabel(l10n, null)
                  : '${_patternLabel(l10n, _pattern)} · '
                      '${appFormatOf(context).date(_until)}',
            ),
            // ── period (fits the workspace granularity) ──
            if (showHalfDayPicker) ...[
              const SizedBox(height: AppSpacing.sm),
              _periodChips(l10n),
            ],
            if (showTimePickers) ...[
              BookingTimeTile(
                key: const ValueKey('booking-from-tile'),
                label: lexiconText(context, key: 'planFromLabel', fallback: l10n?.planFromLabel ?? 'From'),
                value: _start,
                onPicked: (t) {
                  var start = _snap(pickedInstantAt(_day, t.hour, t.minute));
                  var end = _end;
                  if (!end.isAfter(start)) end = start.add(_slot);
                  setState(() {
                    _start = start;
                    _end = end;
                  });
                  widget.onFieldCommitted?.call('time');
                },
              ),
              BookingTimeTile(
                key: const ValueKey('booking-until-tile'),
                label: l10n?.planUntilLabel ?? 'Until',
                value: _end,
                onPicked: (t) {
                  var end = _snap(pickedInstantAt(_day, t.hour, t.minute));
                  if (!end.isAfter(_start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  final cap = _cap;
                  if (cap != null && end.isAfter(cap)) end = cap;
                  setState(() => _end = end);
                  widget.onFieldCommitted?.call('time');
                },
              ),
            ],
            if (showDurationSlider) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${lexiconText(context, key: 'planDurationLabel', fallback: l10n?.planDurationLabel ?? 'Duration')} · '
                '${bookingRangeText(context, appFormatOf(context), l10n, _start, _end)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Slider(
                key: const ValueKey('booking-duration-slider'),
                value: _end
                    .difference(_start)
                    .inMinutes
                    .clamp(gridStep, maxDuration)
                    .toDouble(),
                min: gridStep.toDouble(),
                max: maxDuration.toDouble(),
                divisions:
                    ((maxDuration - gridStep) ~/ gridStep).clamp(1, 288),
                label: bookingRangeText(context, appFormatOf(context), l10n, _start, _end),
                onChanged: (v) {
                  final minutes = (v / gridStep).round() * gridStep;
                  setState(() =>
                      _end = _start.add(Duration(minutes: minutes)));
                  widget.onFieldCommitted?.call('time');
                },
              ),
            ],
            // #446 hours walk-up: the check-in creates the reservation
            // implicitly — the start is "now", the end is the user's to
            // fill (prefilled with the end of the working day).
            if (hoursWalkUp)
              BookingTimeTile(
                key: const ValueKey('booking-until-tile'),
                label: l10n?.planUntilLabel ?? 'Until',
                value: _end,
                onPicked: (t) {
                  var end = _snap(pickedInstantAt(_day, t.hour, t.minute));
                  if (!end.isAfter(_start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  final cap = _cap;
                  if (cap != null && end.isAfter(cap)) end = cap;
                  setState(() => _end = end);
                  widget.onFieldCommitted?.call('time');
                },
              ),

            // Shown whenever there is a real choice OR the only subject
            // is not me — the actor must always SEE who it lands on
            // (#638, the rule the deleted level sheet enforced).
            if (widget.members.length > 1 ||
                (widget.members.length == 1 &&
                    widget.members.first.id != widget.myMemberId))
              DropdownButtonFormField<String>(
                key: const ValueKey('booking-for-member'),
                initialValue: _forMemberId,
                decoration: InputDecoration(
                  labelText: lexiconText(context, key: 'planBookForLabel', fallback: l10n?.planBookForLabel ?? 'Book for'),
                ),
                items: [
                  for (final m in widget.members)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (id) {
                  // #2016 — a walk-up is the actor sitting down; booking
                  // for someone else is a reservation.
                  if (id != widget.myMemberId) _setMode(false);
                  setState(() => _forMemberId = id);
                  widget.onFieldCommitted?.call('for_whom');
                },
              ),

            if (_capped && _cap != null)
              Text(
                l10n?.planCappedByNext(
                      timeFormat.time(_cap!),
                    ) ??
                    'The seat is reserved from '
                        '${timeFormat.time(_cap!)}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (overlap) const BookingOverlapNotice(),
            if (refusal != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  key: const ValueKey('booking-gate-refusal'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.refusalTextOf?.call(refusal) ??
                            (l10n?.bookingGateBlocked ??
                                'Not bookable as chosen'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (showRepeat)
              ExpansionTile(
                key: const ValueKey('booking-more-options'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _pattern != null,
                title: Text(l10n?.bookingMoreOptions ?? 'More options'),
                children: [
                  // ── repeat (spec §5.2) — available whenever booking for self ──
                  if (showRepeat) ...[
                    DropdownButtonFormField<SeriesPattern?>(
                      key: const ValueKey('booking-repeat'),
                      initialValue: _pattern,
                      decoration: InputDecoration(
                        labelText: l10n?.planRepeatLabel ?? 'Repeat',
                      ),
                      items: [
                        for (final p in [null, ...SeriesPattern.values])
                          DropdownMenuItem(
                            value: p,
                            child: Text(_patternLabel(l10n, p)),
                          ),
                      ],
                      onChanged: (p) {
                        setState(() => _pattern = p);
                        widget.onFieldCommitted?.call('repeat');
                      },
                    ),
                    if (_pattern != null)
                      BookingDateTile(
                        label: l10n?.planUntilDateLabel ?? 'Repeat until',
                        value: _until,
                        first: widget.start,
                        onPicked: (d) {
                          setState(() => _until = d);
                          widget.onFieldCommitted?.call('repeat');
                        },
                      ),
                  ],
                ],
              ),
            if (_liveWindow)
              SwitchListTile(
                key: const ValueKey('booking-check-in-now'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                    l10n?.kioskCheckInRightAway ?? 'Check in right away'),
                subtitle: Text(words.uxBookingCheckInHelp),
                value: _checkInNow,
                onChanged: (v) {
                  setState(() => _checkInNow = v);
                  widget.onFieldCommitted?.call('check_in');
                },
              ),
            if (widget.seatId != null) ...[
              SeatAccessoryRow(seatId: widget.seatId!),
              PlaceFeedbackBar(kind: PlaceKind.seat, id: widget.seatId!),
            ],
            if (widget.allowBlocking)
              BookingManagementOptions(onBlock: () => Navigator.of(context).pop(
                BookingChoice(_start, _end, null, null, null, block: true))),
      ],
    );
  }

  /// Whether a Riverpod scope is above this sheet (#763): the scope's
  /// inherited widget is private, so probing means asking for the
  /// container and treating the StateError as "none".
  bool _hasProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } on StateError {
      return false;
    }
  }

  /// The longest grid-aligned duration from [_start] (#574): bounded by
  /// the next reservation on the seat ([widget.cap]) or the day's last
  /// slot, floored to the step.
  int _maxDurationMinutes(int step) {
    final lastSlot =
        WorkspaceTime.at(_day.year, _day.month, _day.day, 23, 45);
    final cap = _cap;
    final limit =
        cap != null && cap.isBefore(lastSlot) ? cap : lastSlot;
    final minutes = limit.difference(_start).inMinutes;
    return (minutes ~/ step) * step;
  }

  Duration get _slot => Duration(
        minutes: widget.granularity.stepMinutes ?? 15,
      );

  DateTime _snap(DateTime t) {
    // #638 — the shared grid rule; no surface snaps on its own any more.
    // #1082 — and it snaps ON THE WORKSPACE CLOCK: `t` is a workspace
    // instant, so its components are workspace wall-clock and the
    // snapped result must be rebuilt in that zone, not the device's.
    final m = widget.granularity.snapMinutesOfDay(t.hour * 60 + t.minute);
    return pickedInstantAt(t, m ~/ 60, m % 60);
  }

  /// Morning / Afternoon / Full day under half-day granularity — the same
  /// language as the hub chips, but here it edits the booking's window.
  Widget _periodChips(AppLocalizations? l10n) {
    Widget chip(String key, String label, HalfDayWindow w) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ChoiceChip(
            key: ValueKey(key),
            label: Text(label),
            selected: _isWindow(w),
            onSelected: (_) => _selectWindow(w),
          ),
        );
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        chip('booking-am', lexiconText(context, key: 'planMorningChip', fallback: l10n?.planMorningChip ?? 'Morning'),
            HalfDayWindows.morning(_day)),
        chip('booking-pm', lexiconText(context, key: 'planAfternoonChip', fallback: l10n?.planAfternoonChip ?? 'Afternoon'),
            HalfDayWindows.afternoon(_day)),
        chip('booking-day', lexiconText(context, key: 'reserveFullDayChip', fallback: l10n?.reserveFullDayChip ?? 'Full day'),
            HalfDayWindows.fullDay(_day)),
      ],
    );
  }
}
