// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/save_calendar_file.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_calendar_file.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';

/// #1643 — "Save calendar file" on an owned reservation.
///
/// The button asks `CalendarFiles` for a preview, shows exactly what the
/// file will say — event, when, where, status, file name, and the bytes
/// themselves under a fold — with the snapshot warning, and only then
/// saves. The widget resolves no repository: the command behind
/// `calendarFilesProvider` does, which is what keeps this file off the
/// layering ratchet.
class CalendarFileButton extends ConsumerWidget {
  const CalendarFileButton({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const ValueKey('reservation-calendar-file'),
      icon: const Icon(Icons.event_available_outlined),
      onPressed: () => _open(context, ref),
      label: Text(
        l10n?.reservationCalendarFileButton ?? 'Save calendar file',
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Captured BEFORE any await: a profile switch while the backend
    // answers must not turn this into somebody else's preview.
    final memberId = ref.read(myMemberProvider).value?.id;
    if (memberId == null) return;
    CalendarFileOutcome? outcome;
    CalendarFiles? files;
    final ok = await runGuarded(
      context,
      domain: 'reservations',
      message: 'calendar file preview failed',
      errorText: l10n?.commonSaveFailed ?? 'Could not save the file.',
      action: () async {
        files = await ref.read(calendarFilesProvider.future);
        outcome = await files!.prepare(
          reservationId: reservation.id,
          memberId: memberId,
        );
      },
    );
    if (!ok || !context.mounted) return;
    switch (outcome!) {
      case CalendarFileRefused():
        AppSnack.error(
          context,
          l10n?.reservationCalendarFileRefused ??
              'This booking cannot be exported: it is not yours, or it '
                  'no longer exists.',
        );
      case CalendarFileReady(:final preview):
        await showDialog<void>(
          context: context,
          builder: (_) => _CalendarFileDialog(
            files: files!,
            memberId: memberId,
            initial: preview,
          ),
        );
    }
  }
}

class _CalendarFileDialog extends StatefulWidget {
  const _CalendarFileDialog({
    required this.files,
    required this.memberId,
    required this.initial,
  });

  final CalendarFiles files;
  final String memberId;
  final CalendarFilePreview initial;

  @override
  State<_CalendarFileDialog> createState() => _CalendarFileDialogState();
}

class _CalendarFileDialogState extends State<_CalendarFileDialog> {
  late CalendarFilePreview _preview = widget.initial;
  bool _stale = false;
  bool _saving = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    CalendarSaveOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'reservations',
      message: 'calendar file save failed',
      errorText: l10n?.commonSaveFailed ?? 'Could not save the file.',
      action: () async {
        outcome = await widget.files.save(_preview, memberId: widget.memberId);
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    switch (outcome!) {
      case CalendarFileSaved(:final handle):
        Navigator.of(context).pop();
        AppSnack.success(
          context,
          l10n?.commonSavedTo(handle) ?? 'Saved to $handle',
        );
      case CalendarFileStale(:final fresh):
        // The member looks again and decides again — nothing was written.
        setState(() {
          _preview = fresh;
          _stale = true;
        });
      case CalendarSaveRefused():
        Navigator.of(context).pop();
        AppSnack.error(
          context,
          l10n?.reservationCalendarFileRefused ??
              'This booking cannot be exported: it is not yours, or it '
                  'no longer exists.',
        );
      case CalendarSaveFailed():
        // The dialog stays: the file is still right, only the platform
        // refused, and the Save button is the retry.
        AppSnack.error(
          context,
          l10n?.commonSaveFailed ?? 'Could not save the file.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = _preview.snapshot;
    final start = WorkspaceTime.display(snapshot.startUtc);
    final when = '${DateFormat.MMMEd().format(start)} · '
        '${bookingRangeText(context, appFormatOf(context), l10n, snapshot.startUtc, snapshot.endUtc)}';
    final status = switch (snapshot.status) {
      CalendarEventStatus.confirmed =>
        l10n?.reservationCalendarFileStatusConfirmed ?? 'Confirmed',
      CalendarEventStatus.cancelled =>
        l10n?.reservationCalendarFileStatusCancelled ?? 'Cancelled',
    };
    final staleText = l10n?.reservationCalendarFileStale ??
        'The booking changed since this preview. Check it again before '
            'saving.';
    final noteText = l10n?.reservationCalendarFileSnapshotNote ??
        'This file is a snapshot of the booking as it is now. If the '
            'booking is moved or cancelled later, a file already saved or '
            'shared does not change — and a shared file cannot be taken '
            'back.';
    return AlertDialog(
      key: const ValueKey('calendar-file-preview'),
      title: Text(l10n?.reservationCalendarFileTitle ?? 'Calendar file'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_stale) ...[
              Text(
                staleText,
                key: const ValueKey('calendar-file-stale'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _row(l10n?.reservationCalendarFileEvent ?? 'Event',
                snapshot.summary),
            _row(l10n?.reservationCalendarFileWhen ?? 'When', when),
            if (snapshot.location.isNotEmpty)
              _row(l10n?.reservationCalendarFileLocation ?? 'Location',
                  snapshot.location),
            _row(l10n?.reservationCalendarFileStatus ?? 'Status', status),
            _row(l10n?.reservationCalendarFileName ?? 'File',
                _preview.fileName),
            const SizedBox(height: AppSpacing.md),
            Text(noteText, style: theme.textTheme.bodySmall),
            ExpansionTile(
              key: const ValueKey('calendar-file-contents'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                l10n?.reservationCalendarFileContents ?? 'File contents',
                style: theme.textTheme.bodySmall,
              ),
              children: [
                SelectableText(
                  _preview.text,
                  key: const ValueKey('calendar-file-text'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('calendar-file-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('calendar-file-save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(context).textTheme.bodyMedium?.emphasised,
            ),
            TextSpan(text: value),
          ]),
        ),
      );
}
