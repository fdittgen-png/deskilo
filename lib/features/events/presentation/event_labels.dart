// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/notification_feed.dart';
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
    EventType.usageCorrection =>
      l10n?.eventTypeUsageCorrection ?? 'Early departure',
    EventType.usageRecordDelete =>
      l10n?.eventTypeUsageRecordDelete ?? 'Usage record removal',
    EventType.paymentTermsChange =>
      l10n?.eventTypePaymentTermsChange ?? 'Payment conditions',
    EventType.invoiceIssue => l10n?.eventTypeInvoiceIssue ?? 'Invoice issue',
    EventType.invoiceVoid => l10n?.eventTypeInvoiceVoid ?? 'Invoice cancellation',
    EventType.refund => l10n?.eventTypeRefund ?? 'Refund',
    EventType.memberStatusChange =>
      l10n?.eventTypeMemberStatusChange ?? 'Membership change',
    EventType.subscriptionChange =>
      l10n?.eventTypeSubscriptionChange ?? 'Subscription change',
    EventType.matrixChange =>
      l10n?.eventTypeMatrixChange ?? 'Permission matrix change',
    // #1088 — a type this build does not know still names itself as
    // something that happened, rather than emptying the feed.
    EventType.unknown => l10n?.eventTypeUnknown ?? 'Activity',
    EventType.invoiceWriteoff =>
      l10n?.eventTypeInvoiceWriteoff ?? 'Outstanding write-off',
    EventType.invoiceReminder =>
      l10n?.eventTypeInvoiceReminder ?? 'Payment reminder',
    EventType.priceNegotiation =>
      l10n?.eventTypePriceNegotiation ?? 'Price negotiation',
    EventType.expenseSchedule =>
      l10n?.eventTypeExpenseSchedule ?? 'Scheduled expense',
    EventType.expenseRepartition =>
      l10n?.eventTypeExpenseRepartition ?? 'Shared expense',
  };
}

/// The name of one notification category (#581/#598).
///
/// The filter chips and the grouped feed's headers say the same
/// words, so they read it from one place. Moved out of the Alerts
/// screen (#1184) — it is a label, and this is where labels live.
String notificationCategoryLabel(
  AppLocalizations? l10n,
  NotificationCategory category,
) {
  return switch (category) {
    NotificationCategory.messages =>
      l10n?.eventsMessagesHeader ?? 'Messages',
    NotificationCategory.reservations =>
      l10n?.eventTypeReservation ?? 'Reservation',
    NotificationCategory.checkIns =>
      l10n?.notifCategoryCheckIns ?? 'Check-ins',
    NotificationCategory.money => l10n?.notifCategoryMoney ?? 'Money',
    NotificationCategory.members =>
      l10n?.notifCategoryMembers ?? 'Members',
  };
}
