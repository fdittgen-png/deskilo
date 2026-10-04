// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1884 B — the first management forms past the feature switch: the
// role matrix, the roles a space defines and who holds them, and the
// validation rules.
//
// What a step keeps: which PERMISSION was switched for which BUILT-IN
// role (both finite product vocabularies), whether a role was created,
// edited or renamed, whether a role was given or taken back, and which
// event type's rule was saved. Never a role's own name (somebody typed
// it), a member, an approver, a count or a rule's contents. Each command
// is an attempt before it runs and its real result after: saved, sent
// for validation, refused, or unknown; a held act is never "saved".
part of 'action_registry.dart';

/// The permission keys (WorkspacePermission.wireName), pinned to the enum
/// by test/features/task_recorder/admin_journey_test.dart.
const Set<String> workspacePermissionKeys = {
  'manageRoles',
  'manageMembers',
  'manageValidation',
  'workspaceSettings',
  'issueInvoices',
  'viewFinances',
  'manageDocuments',
  'manageServices',
  'approveExpenses',
  'viewNegotiations',
  'manageNegotiations',
  'paymentTermsEdit',
  'manageSites',
  'manageBilling',
  'manageReservations',
  'operateKiosk',
  'exportData',
  'designDocuments',
  'viewPersonalData',
  'manageIntegrations',
  'manageConfiguration',
  'deployToProd',
  'deployToDev',
  'accessProd',
  'viewAnalytics',
  'useMessages',
  'makeReservations',
  'viewCalendar',
  'viewDirectory',
  'viewMyMoney',
  'viewDocuments',
};

/// The event types a validation rule can be for (EventType.dbName, the
/// fallback `unknown` excluded), pinned to the enum by the same test.
const Set<String> validationRuleKeys = {
  'reservation',
  'payment',
  'expense',
  'adjustment',
  'service_charge',
  'quota',
  'role_change',
  'member_join',
  'space_reservation',
  'invoice_payment',
  'reservation_delete',
  'invoice_reminder',
  'price_negotiation',
  'expense_schedule',
  'expense_repartition',
  'invoice_writeoff',
  'usage_correction',
  'usage_record_delete',
  'payment_terms_change',
  'invoice_issue',
  'invoice_void',
  'refund',
  'member_status_change',
  'subscription_change',
  'matrix_change',
};

/// The validation rule that applies when a type has none of its own.
const String validationDefaultRule = 'default';

/// What a management command's result can be.
const Set<String> _settingOutcomes = {
  RecorderOutcomes.settingSaved,
  RecorderOutcomes.settingPending,
  RecorderOutcomes.settingNotSaved,
  RecorderOutcomes.settingUnknown,
};

const List<ActionSpec> _adminActions = [
  ActionSpec(
    RecorderActions.togglePermission,
    surface: RecorderSurfaces.roles,
    kind: ActionKind.submit,
    targets: workspacePermissionKeys,
    payloadFields: {'role_kind', 'switch_to'},
    outcomes: _settingOutcomes,
  ),
  ActionSpec(
    RecorderActions.saveRole,
    surface: RecorderSurfaces.roles,
    kind: ActionKind.submit,
    payloadFields: {'role_change'},
    outcomes: _settingOutcomes,
  ),
  ActionSpec(
    RecorderActions.giveRole,
    surface: RecorderSurfaces.roles,
    kind: ActionKind.submit,
    payloadFields: {'switch_to'},
    outcomes: _settingOutcomes,
  ),
  ActionSpec(
    RecorderActions.cancelRoleEdit,
    surface: RecorderSurfaces.roles,
    kind: ActionKind.cancel,
  ),
  ActionSpec(
    RecorderActions.saveValidationRule,
    surface: RecorderSurfaces.validationRules,
    kind: ActionKind.submit,
    targets: {...validationRuleKeys, validationDefaultRule},
    outcomes: _settingOutcomes,
  ),
  ActionSpec(
    RecorderActions.cancelValidationRule,
    surface: RecorderSurfaces.validationRules,
    kind: ActionKind.cancel,
  ),
];

const List<OutcomeSpec> _adminOutcomes = [
  OutcomeSpec(RecorderOutcomes.settingPending, state: ObservationState.pending),
];
