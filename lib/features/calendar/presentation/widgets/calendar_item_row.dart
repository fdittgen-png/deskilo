// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/presentation/event_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note_refs.dart';

IconData calendarKindIcon(CalendarKind kind) => switch (kind) {
      CalendarKind.reservation => Icons.event_seat_outlined,
      CalendarKind.checkIn => Icons.login_outlined,
      CalendarKind.checkOut => Icons.logout_outlined,
      CalendarKind.event => Icons.notifications_outlined,
      CalendarKind.message => Icons.forum_outlined,
      CalendarKind.invoice => Icons.receipt_long_outlined,
      CalendarKind.payment => Icons.payments_outlined,
      CalendarKind.consumption => Icons.local_cafe_outlined,
      CalendarKind.reminder => Icons.alarm_outlined,
      CalendarKind.due => Icons.event_available_outlined,
      CalendarKind.scheduled => Icons.event_repeat_outlined,
    };

/// #818 — the group's colour, the same on the grid marker and the row.
Color calendarGroupColor(ColorScheme scheme, CalendarGroup group) =>
    switch (group) {
      CalendarGroup.bookings => scheme.primary,
      CalendarGroup.activity => scheme.tertiary,
      CalendarGroup.money => scheme.secondary,
    };

String calendarGroupLabel(AppLocalizations? l10n, CalendarGroup group) =>
    switch (group) {
      CalendarGroup.bookings =>
        l10n?.calendarGroupBookings ?? 'Bookings & presence',
      CalendarGroup.activity =>
        l10n?.calendarGroupActivity ?? 'Alerts & messages',
      CalendarGroup.money => l10n?.calendarGroupMoney ?? 'Money',
    };

String calendarKindLabel(AppLocalizations? l10n, CalendarKind kind) =>
    switch (kind) {
      CalendarKind.reservation => l10n?.calendarKindReservation ?? 'Bookings',
      CalendarKind.checkIn => l10n?.calendarKindCheckIn ?? 'Check-ins',
      CalendarKind.checkOut => l10n?.calendarKindCheckOut ?? 'Check-outs',
      CalendarKind.event => l10n?.calendarKindEvent ?? 'Alerts',
      CalendarKind.message => l10n?.calendarKindMessage ?? 'Messages',
      CalendarKind.invoice => l10n?.calendarKindInvoice ?? 'Invoices',
      CalendarKind.payment => l10n?.calendarKindPayment ?? 'Payments',
      CalendarKind.consumption => l10n?.calendarKindConsumption ?? 'Consumption',
      CalendarKind.reminder => l10n?.calendarKindReminder ?? 'Reminders',
      CalendarKind.due => l10n?.calendarKindDue ?? 'Payments due',
      CalendarKind.scheduled =>
        l10n?.calendarKindScheduled ?? 'Scheduled expenses',
    };

/// One row of the hub's feed (#718): kind icon, what, who, when, and a
/// chevron — because every row leads somewhere.
class CalendarItemRow extends ConsumerWidget {
  const CalendarItemRow({
    super.key,
    required this.item,
    required this.memberName,
    required this.onTap,
    this.coloured = false,
  });

  final CalendarItem item;
  final String memberName;
  final VoidCallback onTap;

  /// #818 — the leading icon in its group's colour (the views), else
  /// the plain icon the hub always drew.
  final bool coloured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final time = item.until == null
        ? format.time(item.at)
        : '${format.time(item.at)}–${format.time(item.until!)}';
    final title = switch (item.kind) {
      CalendarKind.message => item.body.isEmpty
          ? item.title
          : notePlainText(item.body),
      CalendarKind.event => _eventTitle(l10n, item),
      // #818 — the two due kinds say WHAT is due, not just the number.
      CalendarKind.due =>
        l10n?.calendarDueTitle(item.title) ?? 'Payment due · ${item.title}',
      CalendarKind.scheduled => l10n?.calendarScheduledTitle(item.title) ??
          'Scheduled expense · ${item.title}',
      _ => item.title.isEmpty ? calendarKindLabel(l10n, item.kind) : item.title,
    };
    final money = item.amountCents == null
        ? null
        : format.money(item.amountCents!, currency: item.currency);
    // Status colours from the shared tokens (#196), which are checked
    // for contrast in both schemes — never a raw green.
    final brightness = theme.brightness;
    final amountColor = item.amountCents == null
        ? null
        : item.amountCents! >= 0
            ? AppStatusColors.successTextOf(brightness)
            : theme.colorScheme.error;
    final groupColor = calendarGroupColor(theme.colorScheme, item.kind.group);
    return ListTile(
      key: ValueKey('calendar-item-${item.id}'),
      leading: coloured
          ? CircleAvatar(
              radius: 18,
              backgroundColor: groupColor.withValues(alpha: 0.15),
              foregroundColor: groupColor,
              child: Icon(calendarKindIcon(item.kind), size: 20),
            )
          : Icon(calendarKindIcon(item.kind)),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          time,
          if (memberName.isNotEmpty) memberName,
          ?_statusLabel(l10n, item),
        ].join(' · '),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (money != null)
          Text(money, style: theme.textTheme.bodyMedium?.copyWith(color: amountColor)),
        const Icon(Icons.chevron_right),
      ]),
      onTap: onTap,
    );
  }

  /// `type.action` from the server, read the way the feed reads it: the
  /// type's own name and a verb — never the wire words.
  String _eventTitle(AppLocalizations? l10n, CalendarItem item) {
    final parts = item.title.split('.');
    final type = EventType.values
        .where((t) => t.dbName == parts.first)
        .firstOrNull;
    final typeLabel =
        type == null ? parts.first : eventTypeLabel(l10n, type);
    final action = parts.length > 1 ? parts[1] : '';
    final actionLabel = switch (action) {
      'created' => l10n?.calendarEventActionCreated ?? 'created',
      'modified' => l10n?.calendarEventActionModified ?? 'changed',
      'cancelled' => l10n?.calendarEventActionCancelled ?? 'cancelled',
      'submitted' => l10n?.calendarEventActionSubmitted ?? 'submitted',
      'approved' => l10n?.calendarEventActionApproved ?? 'approved',
      'rejected' => l10n?.calendarEventActionRejected ?? 'rejected',
      _ => action,
    };
    final label = actionLabel.isEmpty ? typeLabel : '$typeLabel · $actionLabel';
    return l10n?.calendarEventTitle(label) ?? 'Alert: $label';
  }

  /// A status worth a word: what still waits or was refused. "applied"
  /// and "confirmed" are the normal course and say nothing.
  String? _statusLabel(AppLocalizations? l10n, CalendarItem item) {
    if (item.kind == CalendarKind.reservation) return null;
    return switch (item.status) {
      'pending' => l10n?.calendarEventStatusPending ?? 'awaiting confirmation',
      'rejected' => l10n?.calendarEventStatusRejected ?? 'rejected',
      'expired' => l10n?.calendarEventStatusExpired ?? 'expired',
      _ => null,
    };
  }
}
