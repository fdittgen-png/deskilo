// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../workspace/domain/workspace_feature.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../event_labels.dart';
import '../validation_workflow.dart';
import '../widgets/policy_editor_sheet.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../providers/event_providers.dart';

/// Card order: the workspace default first, then the money-ish types the
/// quorum protocol was built for, then the rest.
const _cardTypes = [
  EventType.payment,
  EventType.expense,
  EventType.serviceCharge,
  EventType.quota,
  EventType.reservationDelete,
  EventType.invoiceWriteoff,
  EventType.roleChange,
  EventType.memberJoin,
  EventType.reservation,
  EventType.spaceReservation,
  EventType.invoicePayment,
  // #816 — no `adjustment` card: nothing emits that event type and
  // respond_to_event has no branch for it; a rule on it ruled nothing.
  // #739 — the price-negotiation domain existed on the server from day
  // one but never had its card here: it was only configurable through
  // the default rule. #767 closes that gap alongside its own domain.
  EventType.priceNegotiation,
  EventType.expenseSchedule,
  // #828 — a shared expense split over the members.
  EventType.expenseRepartition,
  // #833 — an early departure the member asks to stop paying for,
  // and an admin clearing somebody's usage record.
  EventType.usageCorrection,
  EventType.usageRecordDelete,
  // #881 — a member's payment conditions, changed by request.
  EventType.paymentTermsChange,
  // #982 — the six domains that had no policy.
  EventType.invoiceIssue,
  EventType.invoiceVoid,
  EventType.refund,
  EventType.memberStatusChange,
  EventType.subscriptionChange,
  EventType.matrixChange,
];

/// A pickable validator: an active non-owner admin (owners always may
/// validate, so they are never listed in the specific-admins picker).

/// Owner-only editor for the workspace's validation policies (#131, epic
/// #121, ADR 0008): how many accepts a pending event needs and who may
/// provide them — per event type, with a workspace-wide default. The
/// server (migration 0017) enforces the rules; this screen only edits
/// their source of truth.
class ValidationSettingsScreen extends ConsumerWidget {
  const ValidationSettingsScreen({super.key});



  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String? eventType,
    required String label,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final policies = ref.read(validationPoliciesProvider).value ?? const [];
    final members = ref.read(workspaceMembersProvider).value ?? const [];
    final names = ref.read(memberNamesProvider).value ?? const {};

    // Start from the stored own row when there is one, else from the
    // effective policy (default row / built-ins) so "customize" begins at
    // what currently applies.
    final own = policies.where((p) => p.eventType == eventType).firstOrNull;
    final base = own ??
        (eventType == null
            ? ValidationPolicy.defaults(workspace.id, null)
            : policyFor(eventType, policies));
    final draft = ValidationPolicy(
      id: own?.id,
      workspaceId: workspace.id,
      eventType: eventType,
      requiredCount: base.requiredCount,
      adminsMayValidate: base.adminsMayValidate,
      eligibleAdminIds: base.eligibleAdminIds,
      ownerRequired: base.ownerRequired,
      // #629 — never inherited: the exception is per-row and only ever
      // means anything on the reservation_delete row.
      autoValidateAdmin: own?.autoValidateAdmin ?? false,
      autoValidateOwner: own?.autoValidateOwner ?? false,
    );
    final admins = <AdminChoice>[
      for (final m in members)
        if (m.isAdmin && !m.isOwner && m.status == MemberStatus.active)
          (id: m.id, name: names[m.id] ?? m.id),
    ];
    final ownerCount = members
        .where((m) => m.isOwner && m.status == MemberStatus.active)
        .length;
    // #732 — every active non-owner is a candidate for a LISTED rule.
    final people = <AdminChoice>[
      for (final m in members)
        if (!m.isOwner && m.status == MemberStatus.active)
          (id: m.id, name: names[m.id] ?? m.id),
    ];
    final features = ref.read(enabledFeaturesSyncProvider);
    final scopesOn = features.contains(WorkspaceFeature.validationScopes);
    final chainOn = features.contains(WorkspaceFeature.validationChain);

    final result = await showModalBottomSheet<ValidationPolicy>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PolicyEditorSheet(
        title: label,
        initial: draft,
        admins: admins,
        people: people,
        ownerCount: ownerCount,
        scopesOn: scopesOn,
        chainOn: chainOn,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).upsertValidationPolicy(result);
    } catch (e, st) {
      debugPrint('upsert validation policy failed: $e\n$st');
      TraceLogger.instance.error('events', 'upsert validation policy failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref.invalidate(validationPoliciesProvider);
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.validationSaved ?? 'Validation rule saved.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final policiesAsync = ref.watch(validationPoliciesProvider);
    // Warm the caches _edit reads synchronously.
    ref
      ..watch(workspaceMembersProvider)
      ..watch(memberNamesProvider);
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.validationTitle ?? 'Validation rules'),
      ),
      body: switch (policiesAsync) {
        AsyncData(value: final policies) => ListView(
            children: [
              // #606 — contextual how-to; gated inside the widget.
              const HelpHint(HelpHintId.validation),
              // #840 — the invariant every rule below sits on, said once
              // and in plain words, because a rule nobody can read is a
              // rule nobody trusts.
              Card(
                key: const Key('validation-no-self-banner'),
                margin: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
                child: ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(l10n?.validationNoSelfTitle ??
                      'Nobody validates their own'),
                  subtitle: Text(l10n?.validationNoSelfDesc ??
                      'Whoever creates an event never validates it. It waits '
                          'for someone else, or expires undecided.'),
                ),
              ),
              _PolicyCard(
                label: l10n?.validationDefaultPolicy ?? 'Default policy',
                effective: policies
                        .where((p) => p.eventType == null)
                        .firstOrNull ??
                    ValidationPolicy.defaults(workspaceId, null),
                customized: policies.any((p) => p.eventType == null),
                onEdit: () => _edit(
                  context,
                  ref,
                  eventType: null,
                  label: l10n?.validationDefaultPolicy ?? 'Default policy',
                ),
              ),
              // #1221 — grouped by the PROCESS a rule interrupts. The
              // screen used to be twenty-four cards in one hand-ordered
              // column, so finding the rule that was slowing something
              // down meant already knowing which event type that thing
              // emitted.
              for (final workflow in ValidationWorkflow.values) ...[
                _WorkflowHeading(workflow: workflow),
                for (final type in _cardTypes)
                  if (workflowOf(type) == workflow)
                    _PolicyCard(
                      label: eventTypeLabel(l10n, type),
                      effective: policies.isEmpty
                          ? ValidationPolicy.defaults(workspaceId, type.dbName)
                          : policyFor(type.dbName, policies),
                      customized:
                          policies.any((p) => p.eventType == type.dbName),
                      onEdit: () => _edit(
                        context,
                        ref,
                        eventType: type.dbName,
                        label: eventTypeLabel(l10n, type),
                      ),
                    ),
              ],
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.label,
    required this.effective,
    required this.customized,
    required this.onEdit,
  });

  final String label;
  final ValidationPolicy effective;
  final bool customized;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = validationSteps(l10n, effective);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onEdit,
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: HelpDotTitle(
                      label,
                      l10n?.helpHintValidationTopic ?? 'confirmations',
                      anchor: HelpAnchor.validationOverview,
                    ),
                  ),
                  // Whether this rule is its own or the default's is
                  // the difference between "I set that" and "that is
                  // just what happens", so both states are named.
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Text(
                      customized
                          ? (l10n?.validationCustomized ?? 'Customized')
                          : (l10n?.validationInherited ?? 'Inherits default'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: customized
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // #1221 — the rule AS THE PROCESS. It used to read
              // "2 required · All admins · Owner must always validate":
              // three true facts in a row, none of which says what
              // happens, in what order, or what is waiting meanwhile.
              _ProcessStrip(steps: steps),
              if (effective.minAmountCents > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n?.validationThresholdNote ??
                      'Smaller amounts apply straight away.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Who asks → who decides → what then, drawn as the three steps they
/// are (#1221).
class _ProcessStrip extends StatelessWidget {
  const _ProcessStrip({required this.steps});

  final ValidationSteps steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, String text, {bool strong = false}) => Expanded(
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: strong
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: strong
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: strong ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        );
    Widget arrow() => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.outlineVariant,
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        step(Icons.edit_note_outlined, steps.asked),
        arrow(),
        // The middle step is the one the owner edits, so it is the one
        // drawn in full weight.
        step(Icons.how_to_reg_outlined, steps.decide, strong: true),
        arrow(),
        step(Icons.check_circle_outline, steps.then),
      ],
    );
  }
}

/// #1221 — the heading of one workflow, with what is at stake while a
/// rule in it is waiting.
class _WorkflowHeading extends StatelessWidget {
  const _WorkflowHeading({required this.workflow});

  final ValidationWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('validation-workflow-${workflow.name}'),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(workflowIcon(workflow),
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workflowName(l10n, workflow).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  workflowStake(l10n, workflow),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

