// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/notification_feed.dart';
import '../domain/workspace_event.dart';

/// The human name of an event type — the feed's, the calendar's, the
/// validation settings': one wording everywhere.
String eventTypeLabel(AppLocalizations l10n, EventType type) {
  return switch (type) {
    EventType.reservation => l10n.eventTypeReservation,
    EventType.payment => l10n.eventTypePayment,
    EventType.expense => l10n.eventTypeExpense,
    EventType.adjustment => l10n.eventTypeAdjustment,
    EventType.serviceCharge =>
      l10n.eventTypeServiceCharge,
    EventType.quota => l10n.eventTypeQuota,
    EventType.roleChange => l10n.eventTypeRoleChange,
    EventType.memberJoin => l10n.eventTypeMemberJoin,
    EventType.spaceReservation =>
      l10n.eventTypeSpaceReservation,
    EventType.invoicePayment =>
      l10n.eventTypeInvoicePayment,
    EventType.reservationDelete =>
      l10n.eventTypeReservationDelete,
    EventType.usageCorrection =>
      l10n.eventTypeUsageCorrection,
    EventType.usageRecordDelete =>
      l10n.eventTypeUsageRecordDelete,
    EventType.paymentTermsChange =>
      l10n.eventTypePaymentTermsChange,
    EventType.invoiceIssue => l10n.eventTypeInvoiceIssue,
    EventType.invoiceVoid => l10n.eventTypeInvoiceVoid,
    EventType.refund => l10n.eventTypeRefund,
    EventType.memberStatusChange =>
      l10n.eventTypeMemberStatusChange,
    EventType.subscriptionChange =>
      l10n.eventTypeSubscriptionChange,
    EventType.matrixChange =>
      l10n.eventTypeMatrixChange,
    // #1088 — a type this build does not know still names itself as
    // something that happened, rather than emptying the feed.
    EventType.unknown ||
    EventType.leaseChange ||
    EventType.commitmentVariance => _specialLabel(l10n, type),
    EventType.invoiceWriteoff =>
      l10n.eventTypeInvoiceWriteoff,
    EventType.invoiceReminder =>
      l10n.eventTypeInvoiceReminder,
    EventType.priceNegotiation =>
      l10n.eventTypePriceNegotiation,
    EventType.expenseSchedule =>
      l10n.eventTypeExpenseSchedule,
    EventType.expenseRepartition =>
      l10n.eventTypeExpenseRepartition,
  };
}

/// The types whose name is not a plain table entry: the one this build does
/// not know, the lease change (#2569) and the rent difference (#2575).
String _specialLabel(AppLocalizations l10n, EventType type) => switch (type) {
  EventType.leaseChange => l10n.eventTypeLeaseChange,
  EventType.commitmentVariance => l10n.eventTypeCommitmentVariance,
  _ => l10n.eventTypeUnknown,
};

/// The name of one notification category (#581/#598).
///
/// The filter chips and the grouped feed's headers say the same
/// words, so they read it from one place. Moved out of the Alerts
/// screen (#1184) — it is a label, and this is where labels live.
String notificationCategoryLabel(
  AppLocalizations l10n,
  NotificationCategory category,
) {
  return switch (category) {
    NotificationCategory.messages =>
      l10n.eventsMessagesHeader,
    NotificationCategory.reservations =>
      l10n.eventTypeReservation,
    NotificationCategory.checkIns =>
      l10n.notifCategoryCheckIns,
    NotificationCategory.money => l10n.notifCategoryMoney,
    NotificationCategory.members =>
      l10n.notifCategoryMembers,
  };
}
