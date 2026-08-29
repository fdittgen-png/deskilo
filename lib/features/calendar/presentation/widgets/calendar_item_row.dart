// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/status_colors.dart';
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
    };

/// One row of the hub's feed (#718): kind icon, what, who, when, and a
/// chevron — because every row leads somewhere.
class CalendarItemRow extends ConsumerWidget {
  const CalendarItemRow({
    super.key,
    required this.item,
    required this.memberName,
    required this.onTap,
  });

  final CalendarItem item;
  final String memberName;
  final VoidCallback onTap;

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
            ? AppStatusColors.successOf(brightness)
            : theme.colorScheme.error;
    return ListTile(
      key: ValueKey('calendar-item-${item.id}'),
      leading: Icon(calendarKindIcon(item.kind)),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          time,
          if (memberName.isNotEmpty) memberName,
          if (item.status.isNotEmpty && item.kind != CalendarKind.reservation)
            item.status,
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

  String _eventTitle(AppLocalizations? l10n, CalendarItem item) {
    // `type.action` from the server; the feed's own localized phrasing
    // lives in the events screen and is the source the row opens.
    final label = item.title.replaceAll('.', ' · ');
    return l10n?.calendarEventTitle(label) ?? 'Alert: $label';
  }
}
