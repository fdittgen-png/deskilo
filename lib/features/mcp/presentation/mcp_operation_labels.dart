// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';

/// What each MCP operation does, in the person's language: the consent
/// screen lists them, the confirmation screen names the one asked.
String mcpOperationLabel(AppLocalizations? l10n, String op) => switch (op) {
  'list_workspaces' =>
    l10n?.mcpOpListWorkspaces ?? 'See which workspaces it may use',
  'get_capabilities' => l10n?.mcpOpCapabilities ?? 'See what it may do there',
  'get_availability' => l10n?.mcpOpAvailability ?? 'See free places',
  'list_my_reservations' =>
    l10n?.mcpOpMyReservations ?? 'See your reservations',
  'get_my_statement' => l10n?.mcpOpMyStatement ?? 'See your account statement',
  'list_my_invoices' => l10n?.mcpOpMyInvoices ?? 'See your invoices',
  'create_reservation' =>
    l10n?.mcpOpCreateReservation ?? 'Book a place for you',
  'update_reservation' =>
    l10n?.mcpOpUpdateReservation ?? 'Change your reservations',
  'check_in' => l10n?.mcpOpCheckIn ?? 'Check you in',
  'check_out' => l10n?.mcpOpCheckOut ?? 'Check you out',
  'request_reservation_deletion' =>
    l10n?.mcpOpReservationDeletion ?? 'Ask to delete a reservation',
  'list_pending_validations' =>
    l10n?.mcpOpPendingValidations ?? 'See pending validation requests',
  'get_validation' => l10n?.mcpOpGetValidation ?? 'Read a validation request',
  'request_invoice_issue' => l10n?.mcpOpInvoiceIssue ?? 'Issue an invoice',
  'request_invoice_void' => l10n?.mcpOpInvoiceVoid ?? 'Void an invoice',
  'request_refund' => l10n?.mcpOpRefund ?? 'Refund an invoice',
  'request_member_status_change' =>
    l10n?.mcpOpMemberStatus ?? 'Change a member\'s status',
  'request_subscription_change' =>
    l10n?.mcpOpSubscription ?? 'Change a member\'s subscription share',
  'respond_to_validation' =>
    l10n?.mcpOpRespond ?? 'Answer a validation request',
  _ => op,
};
