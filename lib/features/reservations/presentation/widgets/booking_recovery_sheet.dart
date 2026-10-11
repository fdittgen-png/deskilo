// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — the sheet for a booking whose answer was lost. It shows the
// request exactly as it was confirmed and offers the three honest moves:
// ask the server what became of it (by the original id), resume it (the
// same request, never a new one), or open the booking the server says it
// made. "Let it go" appears only once the server said nothing was booked
// or can no longer say.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/book_seat.dart';
import '../../application/booking_recovery.dart';
import '../../domain/booking_intent.dart';
import '../../providers/reservation_providers.dart';
import 'reference_open.dart';

/// The one sentence for a device that could not keep the intent.
String bookingRecoveryNotSavedText(AppLocalizations l10n) =>
    l10n.bookingRecoveryNotSaved;

Future<void> showBookingRecoverySheet(
  BuildContext context,
  WidgetRef ref,
  BookingIntent intent, {
  String? spaceName,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BookingRecoverySheet(intent: intent, spaceName: spaceName),
);

@visibleForTesting
class BookingRecoverySheet extends ConsumerStatefulWidget {
  const BookingRecoverySheet({super.key, required this.intent, this.spaceName});

  final BookingIntent intent;
  final String? spaceName;

  @override
  ConsumerState<BookingRecoverySheet> createState() =>
      _BookingRecoverySheetState();
}

class _BookingRecoverySheetState extends ConsumerState<BookingRecoverySheet> {
  RecoveryCheck? _check;
  Booked? _resumed;
  bool _busy = false;

  BookingIntent get _intent => _check?.intent ?? widget.intent;

  String? get _reservationId => switch (_check) {
    RecoveryCommitted(:final reservationId) => reservationId,
    _ => _resumed?.reservationId,
  };

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOutcome() => _run(() async {
    final check = await ref.read(bookingRecoveryProvider).check(_intent);
    if (!mounted) return;
    setState(() => _check = check);
    ref.invalidate(unresolvedBookingIntentsProvider);
  });

  Future<void> _resume(AppLocalizations l10n) => _run(() async {
    try {
      final booked = await ref.read(bookingRecoveryProvider).resume(_intent);
      if (!mounted) return;
      setState(() => _resumed = booked);
      ref.invalidate(unresolvedBookingIntentsProvider);
    } on BookingOutcomeUnknown {
      // Lost again: the intent is still open, the sheet still says so.
      if (!mounted) return;
      setState(() => _check = null);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'resume of booking intent ${_intent.requestId} refused',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      // The server's own words: a refusal is an answer, and the intent is
      // closed by the command. The member keeps the sheet's facts.
      AppSnack.error(
        context,
        l10n.reserveBookingFailed,
        replace: true,
      );
      Navigator.of(context).pop();
    }
  });

  Future<void> _discard() => _run(() async {
    await ref.read(bookingRecoveryProvider).discard(_intent);
    ref.invalidate(unresolvedBookingIntentsProvider);
    if (mounted) Navigator.of(context).pop();
  });

  Future<void> _view() async {
    final id = _reservationId;
    if (id == null) return;
    Navigator.of(context).pop();
    await openReservationById(context, ref, id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.MMMd(locale).add_Hm();
    final window =
        l10n.bookingRecoveryWindow(
          // Evaluated only when l10n is non-null (null-aware call).
          widget.spaceName ?? l10n.bookingRecoverySpaceFallback,
          fmt.format(_intent.startsAt.toLocal()),
          fmt.format(_intent.endsAt.toLocal()),
        );
    final (status, severity) = _status(l10n);
    final committed = _reservationId != null;
    final settledNegative =
        _check is RecoveryNotCommitted || _check is RecoveryUnresolved;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookingRecoveryTitle,
              key: const ValueKey('booking-recovery-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(window, key: const ValueKey('booking-recovery-window')),
            const SizedBox(height: AppSpacing.md),
            InlineBanner(
              key: ValueKey('booking-recovery-status-${_statusKey()}'),
              icon: committed ? Icons.check_circle_outline : Icons.help_outline,
              severity: severity,
              text: status,
            ),
            const SizedBox(height: AppSpacing.md),
            if (committed)
              FilledButton(
                key: const ValueKey('booking-recovery-view'),
                onPressed: _busy ? null : _view,
                child: Text(l10n.bookingRecoveryView),
              )
            else ...[
              FilledButton(
                key: const ValueKey('booking-recovery-check'),
                onPressed: _busy ? null : _checkOutcome,
                child: Text(l10n.bookingRecoveryCheck),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const ValueKey('booking-recovery-resume'),
                // Beyond retention the server cannot vouch for a replay
                // either way: the member looks at their bookings instead.
                onPressed: _busy || _check is RecoveryUnresolved
                    ? null
                    : () => _resume(l10n),
                child: Text(
                  l10n.bookingRecoveryResume,
                ),
              ),
            ],
            if (settledNegative) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('booking-recovery-discard'),
                onPressed: _busy ? null : _discard,
                child: Text(l10n.bookingRecoveryDiscard),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusKey() => _resumed != null
      ? 'resumed'
      : switch (_check) {
          null => 'unknown',
          RecoveryCommitted() => 'committed',
          RecoveryInProgress() => 'inProgress',
          RecoveryNotCommitted() => 'notCommitted',
          RecoveryUnresolved() => 'unresolved',
          RecoveryUnavailable() => 'unavailable',
        };

  (String, InlineBannerSeverity) _status(AppLocalizations l10n) {
    if (_resumed != null) {
      return (
        l10n.bookingRecoveryResumed,
        InlineBannerSeverity.info,
      );
    }
    return switch (_check) {
      null => (
        l10n.bookingRecoveryUnknown,
        InlineBannerSeverity.error,
      ),
      RecoveryCommitted() => (
        l10n.bookingRecoveryCommitted,
        InlineBannerSeverity.info,
      ),
      RecoveryInProgress() => (
        l10n.bookingRecoveryInProgress,
        InlineBannerSeverity.info,
      ),
      RecoveryNotCommitted() => (
        l10n.bookingRecoveryNotCommitted,
        InlineBannerSeverity.info,
      ),
      RecoveryUnresolved() => (
        l10n.bookingRecoveryUnresolved,
        InlineBannerSeverity.error,
      ),
      RecoveryUnavailable() => (
        l10n.bookingRecoveryUnavailable,
        InlineBannerSeverity.error,
      ),
    };
  }
}
