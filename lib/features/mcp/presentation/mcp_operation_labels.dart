// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';

/// What each MCP operation does, in the person's language: the consent
/// screen lists them, the confirmation screen names the one asked.
String mcpOperationLabel(AppLocalizations l10n, String op) => switch (op) {
  'list_workspaces' =>
    l10n.mcpOpListWorkspaces,
  'get_capabilities' => l10n.mcpOpCapabilities,
  'get_availability' => l10n.mcpOpAvailability,
  'list_my_reservations' =>
    l10n.mcpOpMyReservations,
  'get_my_statement' => l10n.mcpOpMyStatement,
  'get_member_statement' => l10n.mcpOpMemberStatement,
  'list_my_invoices' => l10n.mcpOpMyInvoices,
  'create_reservation' =>
    l10n.mcpOpCreateReservation,
  'update_reservation' =>
    l10n.mcpOpUpdateReservation,
  'check_in' => l10n.mcpOpCheckIn,
  'check_out' => l10n.mcpOpCheckOut,
  'get_place' =>
    l10n.mcpOpGetPlace,
  'list_my_favorites' =>
    l10n.mcpOpListMyFavorites,
  'set_favorite' =>
    l10n.mcpOpSetFavorite,
  'rate_place' => l10n.mcpOpRatePlace,
  'cancel_reservation' =>
    l10n.mcpOpCancelReservation,
  'request_reservation_deletion' =>
    l10n.mcpOpReservationDeletion,
  'list_pending_validations' =>
    l10n.mcpOpPendingValidations,
  'get_validation' => l10n.mcpOpGetValidation,
  'request_invoice_issue' => l10n.mcpOpInvoiceIssue,
  'request_invoice_void' => l10n.mcpOpInvoiceVoid,
  'request_refund' => l10n.mcpOpRefund,
  'request_member_status_change' =>
    l10n.mcpOpMemberStatus,
  'request_subscription_change' =>
    l10n.mcpOpSubscription,
  'respond_to_validation' =>
    l10n.mcpOpRespond,
  _ => op,
};

/// #1809 — what each optional field discloses, in the person's language.
String mcpOptionalFieldLabel(AppLocalizations l10n, String field) =>
    switch (field) {
      'name' => l10n.mcpFieldName,
      _ => field,
    };

/// #1809 — a fictional value for a field in the disclosure preview.
String mcpOptionalFieldSample(AppLocalizations l10n, String field) =>
    switch (field) {
      'name' => l10n.mcpFieldNameSample,
      _ => '…',
    };
