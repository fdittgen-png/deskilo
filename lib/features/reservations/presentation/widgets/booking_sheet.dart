// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../core/time/workspace_time.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../domain/reservation_repository.dart';

/// What the booking sheet returns: end time, an optional recurrence and
/// who the booking is for (null/self = the caller).
class BookingChoice {
  const BookingChoice(
    this.end,
    this.pattern,
    this.until,
    this.forMemberId, {
    this.block = false,
  });

  final DateTime end;
  final SeriesPattern? pattern;
  final DateTime? until;
  final String? forMemberId;

  /// True: block the seat for maintenance instead of booking it (#161).
  /// Every other field is ignored then.
  final bool block;
}

/// Bottom-sheet body for booking a seat (#206): walk-up check-in or a
/// punctual reservation, with the optional "Book for" picker (#106),
/// repeat picker (spec §5.2) and owner/admin blocking affordance (#161).
///
/// Pure presentation: pops with a [BookingChoice] (or null on dismiss);
/// the caller derives the window, runs the repository calls and maps
/// errors. Extracted from the plan screen so the Reserve hub (#208) can
/// share it.
class BookingSheet extends StatefulWidget {
  const BookingSheet({
    super.key,
    required this.seatId,
    required this.seatName,
    required this.start,
    required this.initialEnd,
    required this.cap,
    required this.capped,
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

  /// True: live walk-up (check in now). False: future punctual reservation.
  final bool walkUp;

  /// Half-day granularity (#201): the end is the canonical window's (or
  /// the current half-day boundary for walk-ups) and not adjustable — the
  /// "Until" tile is hidden.
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
  late DateTime _end = widget.initialEnd;
  SeriesPattern? _pattern;
  late DateTime _until = widget.start.add(const Duration(days: 28));
  late String? _forMemberId = widget.myMemberId;

  bool get _forOther =>
      _forMemberId != null && _forMemberId != widget.myMemberId;

  String _patternLabel(AppLocalizations? l10n, SeriesPattern? pattern) {
    return switch (pattern) {
      null => l10n?.repeatNone ?? 'Does not repeat',
      SeriesPattern.daily => l10n?.repeatDaily ?? 'Every day',
      SeriesPattern.weekdays => l10n?.repeatWeekdays ?? 'Every weekday',
      SeriesPattern.weekly => l10n?.repeatWeekly ?? 'Weekly',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFormat = DateFormat.Hm();
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
                  : (l10n?.planStartsAt(
                        timeFormat.format(WorkspaceTime.display(widget.start)),
                      ) ??
                      'Starts at '
                          '${timeFormat.format(WorkspaceTime.display(widget.start))}'),
            ),
            // The seat's active accessories (#169): self-loading, renders
            // nothing when the seat has none. Both booking flows (walk-up
            // and browsed-time) share this sheet, so both get the row.
            SeatAccessoryRow(seatId: widget.seatId),
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
            // Half-day granularity (#201): the end is fixed to the
            // canonical window boundary — no "Until" affordance.
            if (!widget.fixedEnd)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.planUntilLabel ?? 'Until'),
                trailing: Text(timeFormat.format(WorkspaceTime.display(_end))),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_end.toLocal()),
                  );
                  if (picked == null) return;
                  final local = widget.start.toLocal();
                  var candidate = DateTime(
                    local.year,
                    local.month,
                    local.day,
                    picked.hour,
                    picked.minute,
                  );
                  if (!candidate.isAfter(local)) {
                    candidate = candidate.add(const Duration(days: 1));
                  }
                  var end = candidate;
                  final cap = widget.cap?.toLocal();
                  if (cap != null && end.isAfter(cap)) end = cap;
                  setState(() => _end = end);
                },
              ),
            if (!widget.walkUp && !_forOther && widget.allowSeries) ...[
              DropdownButtonFormField<SeriesPattern?>(
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.planUntilDateLabel ?? 'Repeat until'),
                  trailing:
                      Text(DateFormat.yMMMd().format(_until.toLocal())),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _until.toLocal(),
                      firstDate: widget.start.toLocal(),
                      lastDate: widget.start
                          .toLocal()
                          .add(const Duration(days: 180)),
                    );
                    if (picked != null) setState(() => _until = picked);
                  },
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
              // Owner/delegated-admin maintenance block (#161): open-ended,
              // lifted again from the blocked-seat sheet.
              TextButton.icon(
                icon: const Icon(Icons.block),
                label: Text(
                  l10n?.planMakeNotReservable ?? 'Make not reservable',
                ),
                onPressed: () => Navigator.of(context).pop(
                  BookingChoice(_end, null, null, null, block: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
