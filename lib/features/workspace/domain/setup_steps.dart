// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 (ADR 0047 §1, §4, §5) — the setup guide's step catalogue: the one
// canonical definition the app, the MCP, the help and `web/setup.html`
// read. `tool/build_setup_steps.dart` writes it to
// `contracts/setup/steps.json` and to the server's
// `setup_step_catalogue()`; `workspace_setup_status` computes each step's
// state from its evidence. Pure Dart: the CLI imports it.
import 'dart:convert';

import 'package:meta/meta.dart';

import 'workspace_feature.dart';

/// The guide's groups, in the order an owner meets them.
enum SetupGroup { open, run, grow, launch }

/// The outcome a step serves (ADR 0047 §4): never "configuration saved".
enum SetupMilestone { bookable, money, invoice, live }

/// Who can act on a step.
enum SetupActor { owner, operator }

/// One step of the guide.
class SetupStep {
  const SetupStep(
    this.id, {
    required this.group,
    required this.milestone,
    required this.route,
    required this.evidence,
    this.feature,
    this.required = true,
    this.dependsOn = const [],
    this.actor = SetupActor.owner,
    this.estimateMinutes = 5,
  });

  /// Stable id, shared by the app, the server, the MCP and the help.
  final String id;
  final SetupGroup group;
  final SetupMilestone milestone;

  /// The workspace screen where it is done.
  final String route;

  /// The server detector that proves it (`workspace_setup_status`), or
  /// `manual` for a step the server cannot verify: only those may be
  /// marked done by the owner (ADR 0047 §5).
  final String evidence;

  /// The feature without which the step does not apply; null for always.
  final WorkspaceFeature? feature;

  /// Whether its milestone waits for it.
  final bool required;
  final List<String> dependsOn;
  final SetupActor actor;
  final int estimateMinutes;

  Map<String, Object?> toJson() => {
    'id': id,
    'group': group.name,
    'milestone': milestone.name,
    'route': route,
    'evidence': evidence,
    'feature': feature?.dbKey,
    'required': required,
    'depends_on': dependsOn,
    'actor': actor.name,
    'estimate_minutes': estimateMinutes,
  };
}

/// The catalogue, in guide order. Read by the generator and the contract
/// lint until the setup hub (#2869) lists it.
@visibleForTesting
const List<SetupStep> setupSteps = [
  // ── Open: a member can book ─────────────────────────────────────────
  SetupStep(
    'basics',
    group: SetupGroup.open,
    milestone: SetupMilestone.bookable,
    route: '/workspace-settings',
    evidence: 'basics',
    estimateMinutes: 3,
  ),
  SetupStep(
    'hours',
    group: SetupGroup.open,
    milestone: SetupMilestone.bookable,
    route: '/availability',
    evidence: 'hours',
    dependsOn: ['basics'],
  ),
  SetupStep(
    'places',
    group: SetupGroup.open,
    milestone: SetupMilestone.bookable,
    route: '/editor',
    evidence: 'places',
    dependsOn: ['basics'],
    estimateMinutes: 10,
  ),
  SetupStep(
    'member_rights',
    group: SetupGroup.open,
    milestone: SetupMilestone.bookable,
    route: '/roles',
    evidence: 'member_rights',
    estimateMinutes: 1,
  ),
  SetupStep(
    'invite',
    group: SetupGroup.open,
    milestone: SetupMilestone.bookable,
    route: '/workspace-code',
    evidence: 'invite',
    required: false,
    dependsOn: ['member_rights'],
    estimateMinutes: 3,
  ),
  // ── Run: money and operations ───────────────────────────────────────
  SetupStep(
    'pricing',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/billing',
    evidence: 'pricing',
    feature: WorkspaceFeature.moneyTab,
    estimateMinutes: 10,
  ),
  SetupStep(
    'services',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/services',
    evidence: 'services',
    feature: WorkspaceFeature.services,
    required: false,
  ),
  SetupStep(
    'payment_methods',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/payment-methods',
    evidence: 'payment_methods',
    feature: WorkspaceFeature.moneyTab,
    dependsOn: ['pricing'],
  ),
  SetupStep(
    'online_payments',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/payment-config',
    evidence: 'online_payments',
    feature: WorkspaceFeature.onlinePayments,
    dependsOn: ['payment_methods'],
    actor: SetupActor.operator,
  ),
  SetupStep(
    'approvals',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/validation',
    evidence: 'approvals',
    dependsOn: ['invite'],
  ),
  SetupStep(
    'new_members',
    group: SetupGroup.run,
    milestone: SetupMilestone.live,
    route: '/workspace-settings',
    evidence: 'manual',
    required: false,
    estimateMinutes: 3,
  ),
  SetupStep(
    'kiosk',
    group: SetupGroup.run,
    milestone: SetupMilestone.live,
    route: '/nfc-config',
    evidence: 'kiosk',
    feature: WorkspaceFeature.kioskMode,
    required: false,
  ),
  SetupStep(
    'purchases',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/money/purchases',
    evidence: 'purchases',
    feature: WorkspaceFeature.purchases,
    required: false,
  ),
  SetupStep(
    'lease',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/money/purchases',
    evidence: 'lease',
    feature: WorkspaceFeature.premisesLease,
    required: false,
  ),
  SetupStep(
    'assets',
    group: SetupGroup.run,
    milestone: SetupMilestone.money,
    route: '/money/purchases',
    evidence: 'assets',
    feature: WorkspaceFeature.assetRegister,
    required: false,
  ),
  SetupStep(
    'look',
    group: SetupGroup.run,
    milestone: SetupMilestone.live,
    route: '/settings/colours',
    evidence: 'look',
    feature: WorkspaceFeature.workspaceBranding,
    required: false,
  ),
  SetupStep(
    'public_page',
    group: SetupGroup.run,
    milestone: SetupMilestone.live,
    route: '/settings/public-page',
    evidence: 'public_page',
    feature: WorkspaceFeature.publicListings,
    required: false,
  ),
  // ── Grow: invoices, tax, accounting ─────────────────────────────────
  SetupStep(
    'legal_identity',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/legal-identity',
    evidence: 'legal_identity',
    feature: WorkspaceFeature.invoicing,
  ),
  SetupStep(
    'vat',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/vat',
    evidence: 'vat',
    feature: WorkspaceFeature.vatManagement,
    dependsOn: ['legal_identity'],
  ),
  SetupStep(
    'numbering',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/settings/number-sequences',
    evidence: 'numbering',
    feature: WorkspaceFeature.numberSequences,
    dependsOn: ['legal_identity'],
    estimateMinutes: 3,
  ),
  SetupStep(
    'documents',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/reports',
    evidence: 'documents',
    feature: WorkspaceFeature.invoicePdfTemplate,
    required: false,
    dependsOn: ['legal_identity'],
  ),
  SetupStep(
    'einvoicing',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/einvoice-config',
    evidence: 'einvoicing',
    feature: WorkspaceFeature.einvoiceCustomerDelivery,
    dependsOn: ['legal_identity', 'numbering'],
    estimateMinutes: 15,
  ),
  SetupStep(
    'accounting',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/legal-identity',
    evidence: 'accounting',
    feature: WorkspaceFeature.accountingBook,
    dependsOn: ['vat'],
    estimateMinutes: 10,
  ),
  SetupStep(
    'reminders',
    group: SetupGroup.grow,
    milestone: SetupMilestone.invoice,
    route: '/settings/payment-terms',
    evidence: 'reminders',
    feature: WorkspaceFeature.dunning,
    required: false,
  ),
  // ── Launch: live ────────────────────────────────────────────────────
  SetupStep(
    'first_booking',
    group: SetupGroup.launch,
    milestone: SetupMilestone.live,
    route: '/reserve',
    evidence: 'first_booking',
    dependsOn: ['places', 'member_rights'],
  ),
  SetupStep(
    'recovery',
    group: SetupGroup.launch,
    milestone: SetupMilestone.live,
    route: '/workspace-settings',
    evidence: 'recovery',
    required: false,
    estimateMinutes: 2,
  ),
  SetupStep(
    'assistant',
    group: SetupGroup.launch,
    milestone: SetupMilestone.live,
    route: '/settings/assistant-setup',
    evidence: 'assistant',
    feature: WorkspaceFeature.mcpAccess,
    required: false,
    actor: SetupActor.operator,
  ),
];

/// The catalogue as the shared contract (`contracts/setup/steps.json`).
String setupStepsJson() =>
    '${const JsonEncoder.withIndent('  ').convert([for (final s in setupSteps) s.toJson()])}\n';

/// The server's copy of the catalogue (`setup_step_catalogue()`), pasted
/// unchanged into the migration that defines it.
String setupStepCatalogueSql() =>
    '''
create or replace function public.setup_step_catalogue()
returns jsonb language sql immutable set search_path = public as $_fn
  select $_json${jsonEncode([for (final s in setupSteps) s.toJson()])}$_json::jsonb;
$_fn;
revoke execute on function public.setup_step_catalogue() from public, anon;
grant execute on function public.setup_step_catalogue() to authenticated;''';

// The SQL dollar-quotes, kept out of interpolation.
const _fn = r'$fn$';
const _json = r'$json$';
