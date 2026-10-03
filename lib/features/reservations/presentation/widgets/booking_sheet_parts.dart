// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';

/// #2016 — Reserve (the default) or Check in now in the booking sheet: an
/// explicit choice, never inferred from how the sheet was opened.
class BookingModeSelector extends StatelessWidget {
  const BookingModeSelector({
    super.key,
    required this.walkUp,
    required this.onChanged,
  });

  final bool walkUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<bool>(
      key: const ValueKey('booking-mode'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          label: Text(
            key: const ValueKey('booking-mode-reserve'),
            lexiconText(
              context,
              key: 'planReserveButton',
              fallback: l10n?.planReserveButton ?? 'Reserve',
            ),
          ),
        ),
        ButtonSegment(
          value: true,
          label: Text(
            key: const ValueKey('booking-mode-check-in'),
            l10n?.bookingModeCheckInNow ?? 'Check in now',
          ),
        ),
      ],
      selected: {walkUp},
      onSelectionChanged: (v) => onChanged(v.single),
    );
  }
}

/// #2016 — the reservation overlaps another booking on the seat.
class BookingOverlapNotice extends StatelessWidget {
  const BookingOverlapNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      key: const ValueKey('booking-overlap'),
      AppLocalizations.of(context)?.bookingOverlapsAnother ??
          'The seat is already booked during part of this time.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

/// A From / Until row of the booking sheet: the time on the workspace
/// clock, edited through the platform time picker.
class BookingTimeTile extends StatelessWidget {
  const BookingTimeTile({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime value;
  final void Function(TimeOfDay) onPicked;

  @override
  Widget build(BuildContext context) {
    final timeFormat = appFormatOf(context); // #1150
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(timeFormat.time(value)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(WorkspaceTime.display(value)),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}

/// The "Repeat until" row of the booking sheet: up to 180 days ahead of
/// [first].
class BookingDateTile extends StatelessWidget {
  const BookingDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.first,
    required this.onPicked,
  });

  final String label;
  final DateTime value;
  final DateTime first;
  final void Function(DateTime) onPicked;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(DateFormat.yMMMd().format(WorkspaceTime.wall(value))),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: WorkspaceTime.wall(value),
        // display(): TZDateTime.toLocal() lands in package:timezone's
        // default-UTC tz.local (#417) — a Paris midnight became Sunday.
        firstDate: WorkspaceTime.display(first),
        lastDate: WorkspaceTime.display(first).add(const Duration(days: 180)),
      );
      if (picked != null) onPicked(picked);
    },
  );
}
