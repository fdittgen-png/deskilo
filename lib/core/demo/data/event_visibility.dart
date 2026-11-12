// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3293 — which permission lets a member read another member's event of a
// type: event_type_view_permissions (0650, with 0666's privacy branch), the
// map events_select reads through event_types_in_view (0613). The Demo's
// event repository asks it with the persona's effective permissions, so an
// administrator whose matrix lacks viewFinances and issueInvoices reads
// nobody else's payment there either.
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';

import 'workspace_repository.dart';
import 'workspace_roles_repository.dart';

/// The acting member's effective permissions in the space [workspaceId]:
/// the matrix of their role and, while customRoles is on, what the space's
/// own roles grant them (has_permission_raw, 0247).
Set<WorkspacePermission> Function() demoViewerPermissions(
  FakeWorkspaceRepository space,
  FakeWorkspaceRoles roles,
  String workspaceId,
  String Function() actor,
) =>
    () => effectivePermissions(
      space.memberOf(actor()),
      space.workspaces.where((w) => w.id == workspaceId).firstOrNull,
      custom: roles.grantedTo(actor()),
    );

/// The permissions any one of which reads an event of [type] (a db name).
Set<WorkspacePermission> eventTypeViewPermissions(String type) {
  final names = switch (type) {
    'payment' ||
    'adjustment' ||
    'service_charge' ||
    'invoice_payment' ||
    'invoice_payment_reversed' ||
    'invoice_writeoff' ||
    'invoice_reminder' ||
    'invoice_issued' ||
    'invoice_issue' ||
    'invoice_void' ||
    'refund' ||
    'usage_correction' ||
    'usage_record_delete' => const ['viewFinances', 'issueInvoices'],
    'expense' ||
    'expense_schedule' ||
    'expense_repartition' => const ['approveExpenses', 'viewFinances'],
    'reservation' ||
    'space_reservation' ||
    'reservation_delete' => const ['manageReservations'],
    'quota' => const ['manageReservations', 'viewFinances', 'issueInvoices'],
    'member_join' ||
    'member_status_change' ||
    'subscription_change' ||
    'role_change' => const ['manageMembers'],
    'matrix_change' => const ['manageRoles', 'manageMembers'],
    'price_negotiation' => const ['viewNegotiations'],
    'payment_terms_change' => const ['paymentTermsEdit', 'viewNegotiations'],
    'lease_change' => const ['manageLease', 'viewFinances'],
    'commitment_variance' => const ['managePurchases', 'viewFinances'],
    'badge_security_alert' => const ['workspaceSettings'],
    'payment_instructions_change' => const ['manageIntegrations'],
    'privacy_incident' => const ['managePrivacy'],
    'settlement_review' => const ['viewFinances'],
    'kiosk_device' => const ['workspaceSettings'],
    _ => const ['manageConfiguration'],
  };
  return {
    for (final p in WorkspacePermission.values)
      if (names.contains(p.name)) p,
  };
}
