// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C3 -- one row of My reservations: its times on its workspace's own
// wall clock (the zone named when it is not the device's), and View,
// Check in and Cancel, each asked of the host the row was read from --
// never the selected workspace's. A refused action says the host's reason
// on the row with Try again; the row stays as it was until its host says
// otherwise. View reads the booking again from its host.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/my_reservations.dart';
import '../../domain/my_reservations_composition.dart';
import '../../domain/reservation.dart';
import '../../providers/reservation_providers.dart';
import 'my_reservations_body.dart';

/// The sentence for an action a host refused: a typed refusal or a lost
/// answer in the read's own words, else the host's booking reason, else
/// the plain failure.
String _actionWords(AppLocalizations l10n, Object error) =>
    switch (error) {
      MyReservationsRefused() || TimeoutException() => problemWords(l10n, error),
      _ => bookingErrorText(
          l10n,
          error,
          knownRefusalText(l10n, error) ?? l10n.myReservationsActionFailed,
        ),
    };

enum _Act { checkIn, cancel }

class MyReservationCard extends ConsumerStatefulWidget {
  const MyReservationCard({super.key, required this.entry, required this.query});

  final MyReservationEntry entry;

  /// The composition the row belongs to: its actions go through it.
  final MyReservationsQuery query;

  @override
  ConsumerState<MyReservationCard> createState() => _MyReservationCardState();
}

class _MyReservationCardState extends ConsumerState<MyReservationCard> {
  _Act? _busy;
  _Act? _failed;
  Object? _error;

  void _set({_Act? busy, _Act? failed, Object? error}) => setState(() {
        _busy = busy;
        _failed = failed;
        _error = error;
      });

  Future<bool> _confirmCancel() async {
    final l10n = context.l10n;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.myReservationsCancelTitle),
        content: Text(l10n.myReservationsCancelBody),
        actions: [
          TextButton(
            key: const ValueKey('my-reservation-cancel-keep'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.myReservationsKeep),
          ),
          FilledButton(
            key: const ValueKey('my-reservation-cancel-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.myReservationsCancel),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _run(_Act act) async {
    final e = widget.entry;
    final composer = ref.read(myReservationsComposerProvider(widget.query).notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    _set(busy: act);
    try {
      await switch (act) {
        _Act.checkIn => composer.checkIn(e.source, e.item.id),
        _Act.cancel => composer.cancel(e.source, e.item.id),
      };
    } on Object catch (error, st) {
      TraceLogger.instance.warn(
        'reservations',
        'a host refused an action on my reservation',
        error: error,
        stackTrace: st,
      );
      if (mounted) _set(failed: act, error: error);
      return;
    }
    // The row may have left this tab: the messenger was taken before.
    messenger?.showSnackBar(SnackBar(
      content: Text(switch (act) {
        _Act.checkIn => l10n.myReservationsCheckInDone,
        _Act.cancel => l10n.myReservationsCancelDone,
      }),
    ));
    if (mounted) _set();
  }

  Future<void> _cancel() async {
    if (await _confirmCancel() && mounted) await _run(_Act.cancel);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.entry;
    final item = e.item;
    final now = ref.watch(clockProvider).now();
    final open = item.status == ReservationStatus.reserved && item.endsAt.isAfter(now);
    final today = e.wall(now);
    final canCheckIn = open &&
        e.day == DateTime(today.year, today.month, today.day);
    final failed = _failed;
    final error = _error;
    final busy = _busy != null;
    return Card(
      key: ValueKey('my-reservation-${item.id}'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Details(entry: e),
            if (failed != null && error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              InlineBanner(
                key: ValueKey('my-reservation-failed-${item.id}'),
                icon: Icons.error_outline,
                text: _actionWords(l10n, error),
                actionLabel: l10n.commonRetry,
                onAction: () => _run(failed),
              ),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: ValueKey('my-reservation-view-${item.id}'),
                  onPressed: () => _showSheet(
                    context,
                    query: widget.query,
                    entry: e,
                  ),
                  child: Text(l10n.myReservationsView),
                ),
                if (canCheckIn)
                  TextButton(
                    key: ValueKey('my-reservation-checkin-${item.id}'),
                    onPressed: busy ? null : () => _run(_Act.checkIn),
                    child: Text(l10n.myReservationsCheckIn),
                  ),
                if (open)
                  TextButton(
                    key: ValueKey('my-reservation-cancel-${item.id}'),
                    onPressed: busy ? null : _cancel,
                    child: Text(l10n.myReservationsCancel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What, where, when and where it stands; the times on the workspace's
/// own wall clock, its zone named when the device's differs.
class _Details extends ConsumerWidget {
  const _Details({required this.entry});

  final MyReservationEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final theme = Theme.of(context);
    final item = entry.item;
    final label = item.placeLabel.isEmpty ? l10n.myReservationsUnnamedPlace : item.placeLabel;
    final checkedIn = item.checkedInAt;
    final checkedOut = item.checkedOutAt;
    final zone = entry.foreignZone;
    String at(DateTime instant) => format.wallTime(entry.wall(instant));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(myReservationKindIcon(item.placeKind)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text(
              myReservationStatusWords(l10n, item.status),
              key: ValueKey('my-reservation-status-${item.id}'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_day(format, entry.day)} · ${at(item.startsAt)}–${at(item.endsAt)}',
          key: ValueKey('my-reservation-times-${item.id}'),
        ),
        if (zone != null)
          Text(
            l10n.myReservationsTimesIn(zone),
            key: ValueKey('my-reservation-zone-${item.id}'),
            style: theme.textTheme.bodySmall,
          ),
        Text(
          '${myReservationKindWords(l10n, item.placeKind)} · ${item.workspaceName}',
          style: theme.textTheme.bodySmall,
        ),
        if (checkedIn != null)
          Text(l10n.myReservationsCheckedInAt(at(checkedIn)), style: theme.textTheme.bodySmall),
        if (checkedOut != null)
          Text(l10n.myReservationsCheckedOutAt(at(checkedOut)), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// A day of the workspace's calendar, already a wall date: formatted as
/// it is, never shifted by another zone.
String _day(AppFormat format, DateTime day) => DateFormat.MMMEd(format.locale).format(day);

/// View: the booking read again from its own host, in a sheet.
Future<void> _showSheet(
  BuildContext context, {
  required MyReservationsQuery query,
  required MyReservationEntry entry,
}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ViewSheet(query: query, entry: entry),
    );

class _ViewSheet extends ConsumerStatefulWidget {
  const _ViewSheet({required this.query, required this.entry});

  final MyReservationsQuery query;
  final MyReservationEntry entry;

  @override
  ConsumerState<_ViewSheet> createState() => _ViewSheetState();
}

class _ViewSheetState extends ConsumerState<_ViewSheet> {
  late Future<MyReservationItem> _read = _load();

  Future<MyReservationItem> _load() => ref
      .read(myReservationsComposerProvider(widget.query).notifier)
      .view(widget.entry.source, widget.entry.item.id);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        key: const ValueKey('my-reservation-sheet'),
        padding: AppSpacing.gutterAll,
        child: FutureBuilder<MyReservationItem>(
          future: _read,
          builder: (context, snapshot) {
            final fresh = snapshot.data;
            final error = snapshot.error;
            if (fresh != null) {
              return _Details(
                entry: MyReservationEntry(
                  item: fresh,
                  source: widget.entry.source,
                  zone: widget.entry.zone,
                ),
              );
            }
            if (error != null) {
              return InlineBanner(
                key: const ValueKey('my-reservation-sheet-failed'),
                icon: Icons.error_outline,
                text: _actionWords(l10n, error),
                actionLabel: l10n.commonRetry,
                onAction: () {
                  final again = _load();
                  setState(() {
                    _read = again;
                  });
                },
              );
            }
            return const LinearProgressIndicator();
          },
        ),
      ),
    );
  }
}
