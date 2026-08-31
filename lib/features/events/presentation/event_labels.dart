// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_event.dart';

/// The human name of an event type — the feed's, the calendar's, the
/// validation settings': one wording everywhere.
String eventTypeLabel(AppLocalizations? l10n, EventType type) {
  return switch (type) {
    EventType.reservation => l10n?.eventTypeReservation ?? 'Reservation',
    EventType.payment => l10n?.eventTypePayment ?? 'Payment',
    EventType.expense => l10n?.eventTypeExpense ?? 'Expense',
    EventType.adjustment => l10n?.eventTypeAdjustment ?? 'Adjustment',
    EventType.serviceCharge =>
      l10n?.eventTypeServiceCharge ?? 'Service',
    EventType.quota => l10n?.eventTypeQuota ?? 'Extra half-days',
    EventType.roleChange => l10n?.eventTypeRoleChange ?? 'Role change',
    EventType.memberJoin => l10n?.eventTypeMemberJoin ?? 'New member',
    EventType.spaceReservation =>
      l10n?.eventTypeSpaceReservation ?? 'Whole-space reservations',
    EventType.invoicePayment =>
      l10n?.eventTypeInvoicePayment ?? 'Invoice payment',
    EventType.reservationDelete =>
      l10n?.eventTypeReservationDelete ?? 'Booking deletion',
    EventType.invoiceWriteoff =>
      l10n?.eventTypeInvoiceWriteoff ?? 'Outstanding write-off',
    EventType.invoiceReminder =>
      l10n?.eventTypeInvoiceReminder ?? 'Payment reminder',
    EventType.priceNegotiation =>
      l10n?.eventTypePriceNegotiation ?? 'Price negotiation',
    EventType.expenseSchedule =>
      l10n?.eventTypeExpenseSchedule ?? 'Scheduled expense',
  };
}
