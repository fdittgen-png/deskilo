// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/reservation_repository.dart';
import 'booking_range_text.dart';

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
  });

  final DateTime start;
  final DateTime end;
  final SeriesPattern? pattern;
  final DateTime? until;
  final String? forMemberId;

  /// True: block the seat for maintenance instead of booking it (#161).
  /// Every other field is ignored then.
  final bool block;
}

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
    required this.seatId,
    required this.seatName,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
    this.granularity = BookingGranularity.flexible,
    this.walkUp = true,
    this.fixedEnd = false,
    this.members = const [],
    this.myMemberId,
    this.allowSeries = true,
    this.allowBlocking = false,
  });

  final String seatId;
  final String seatName;
  final DateTime start;
  final DateTime initialEnd;
  final DateTime? cap;
  final bool capped;

  /// The workspace booking granularity (#200/0032): drives which period
  /// picker the sheet shows so the choice always fits the configuration.
  final BookingGranularity granularity;

  /// True: live walk-up (check in now). False: future punctual reservation.
  final bool walkUp;

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

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  late DateTime _start = widget.start;
  late DateTime _end = widget.initialEnd;
  SeriesPattern? _pattern;
  late DateTime _until = widget.start.add(const Duration(days: 28));
  late String? _forMemberId = widget.myMemberId;

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

  void _selectWindow(HalfDayWindow w) =>
      setState(() {
        _start = w.start;
        _end = w.end;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
    // Half-day granularity offers the three canonical windows; full-day
    // is a single locked window; a walk-up keeps its computed end.
    final showHalfDayPicker = !widget.walkUp &&
        widget.granularity == BookingGranularity.halfDay;
    final showTimePickers = !widget.walkUp && !widget.fixedEnd;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.seatName.isEmpty
                  ? (l10n?.planCheckInTitle ?? 'Check in')
                  : widget.seatName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.walkUp
                  ? '${l10n?.planStartNow ?? 'Starts now'} · '
                      '${timeFormat.format(WorkspaceTime.display(widget.start))}'
                  : '${DateFormat.MMMEd().format(WorkspaceTime.display(_start))}'
                      ' · ${bookingRangeText(l10n, _start, _end)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SeatAccessoryRow(seatId: widget.seatId),

            // ── period (fits the workspace granularity) ──
            if (showHalfDayPicker) ...[
              const SizedBox(height: AppSpacing.sm),
              _periodChips(l10n),
            ],
            if (showTimePickers) ...[
              _timeTile(
                key: const ValueKey('booking-from-tile'),
                label: l10n?.planFromLabel ?? 'From',
                value: _start,
                onPicked: (t) {
                  final local = _day;
                  var start = _snap(DateTime(local.year, local.month,
                      local.day, t.hour, t.minute));
                  var end = _end;
                  if (!end.isAfter(start)) end = start.add(_slot);
                  setState(() {
                    _start = start;
                    _end = end;
                  });
                },
              ),
              _timeTile(
                key: const ValueKey('booking-until-tile'),
                label: l10n?.planUntilLabel ?? 'Until',
                value: _end,
                onPicked: (t) {
                  final local = _day;
                  var end = _snap(DateTime(local.year, local.month,
                      local.day, t.hour, t.minute));
                  if (!end.isAfter(_start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  final cap = widget.cap;
                  if (cap != null && end.isAfter(cap)) end = cap;
                  setState(() => _end = end);
                },
              ),
            ],

            if (widget.members.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _forMemberId,
                decoration: InputDecoration(
                  labelText: l10n?.planBookForLabel ?? 'Book for',
                ),
                items: [
                  for (final m in widget.members)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (id) => setState(() => _forMemberId = id),
              ),

            // ── repeat (spec §5.2) — available whenever booking for self ──
            if (!widget.walkUp && !_forOther && widget.allowSeries) ...[
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
                onChanged: (p) => setState(() => _pattern = p),
              ),
              if (_pattern != null)
                _dateTile(
                  label: l10n?.planUntilDateLabel ?? 'Repeat until',
                  value: _until,
                  onPicked: (d) => setState(() => _until = d),
                ),
            ],

            if (widget.capped && widget.cap != null)
              Text(
                l10n?.planCappedByNext(
                      timeFormat.format(WorkspaceTime.display(widget.cap!)),
                    ) ??
                    'The seat is reserved from '
                        '${timeFormat.format(WorkspaceTime.display(widget.cap!))}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                BookingChoice(
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
                    : widget.walkUp
                        ? (l10n?.planCheckInButton ?? 'Check in')
                        : (l10n?.planReserveButton ?? 'Reserve'),
              ),
            ),
            if (widget.allowBlocking) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.block),
                label: Text(
                  l10n?.planMakeNotReservable ?? 'Make not reservable',
                ),
                onPressed: () => Navigator.of(context).pop(
                  BookingChoice(_start, _end, null, null, null, block: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Duration get _slot => Duration(
        minutes: widget.granularity.stepMinutes ?? 15,
      );

  DateTime _snap(DateTime t) {
    final step = widget.granularity.stepMinutes ?? 15;
    final m = (t.hour * 60 + t.minute) ~/ step * step;
    return DateTime(t.year, t.month, t.day, m ~/ 60, m % 60);
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
        chip('booking-am', l10n?.planMorningChip ?? 'Morning',
            HalfDayWindows.morning(_day)),
        chip('booking-pm', l10n?.planAfternoonChip ?? 'Afternoon',
            HalfDayWindows.afternoon(_day)),
        chip('booking-day', l10n?.reserveFullDayChip ?? 'Full day',
            HalfDayWindows.fullDay(_day)),
      ],
    );
  }

  Widget _timeTile({
    required Key key,
    required String label,
    required DateTime value,
    required void Function(TimeOfDay) onPicked,
  }) {
    final timeFormat = DateFormat.Hm();
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(timeFormat.format(WorkspaceTime.display(value))),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(WorkspaceTime.display(value)),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime value,
    required void Function(DateTime) onPicked,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(DateFormat.yMMMd().format(value.toLocal())),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value.toLocal(),
          firstDate: widget.start.toLocal(),
          lastDate: widget.start.toLocal().add(const Duration(days: 180)),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}
