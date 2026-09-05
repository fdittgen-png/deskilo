// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../workspace/domain/workspace_feature.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../event_labels.dart';
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


  /// "2 required · All admins · Owner must always validate" — the
  /// effective rule at a glance.
  String _summary(AppLocalizations? l10n, ValidationPolicy policy) {
    // #840 — the scope decides who, and the summary used to ignore it:
    // a 'members' rule read as "All admins", which was simply untrue.
    final who = switch (policy.validatorScope) {
      'members' => l10n?.validationScopeMembers ?? 'Every member',
      'listed' => '${l10n?.validationSpecificAdmins ?? 'Specific admins'} '
          '(${policy.eligibleAdminIds.length})',
      _ => !policy.adminsMayValidate
          ? (l10n?.validationOwnerOnly ?? 'Owner only')
          : policy.eligibleAdminIds.isEmpty
              ? (l10n?.validationAllAdmins ?? 'All admins')
              : '${l10n?.validationSpecificAdmins ?? 'Specific admins'} '
                  '(${policy.eligibleAdminIds.length})',
    };
    return [
      '${l10n?.validationRequiredCount ?? 'Required validations'}: '
          '${policy.requiredCount}',
      who,
      if (policy.ownerRequired)
        l10n?.validationOwnerRequired ?? 'Owner must always validate',
      if (policy.sequential)
        l10n?.validationSequential ?? 'One after another',
      // The rule that never changes comes last, and it is always there.
      policy.ownerMaySelfValidate
          ? (l10n?.validationOwnerSelfShort ?? 'Owner may validate their own')
          : (l10n?.validationNoSelfShort ?? 'Never one\'s own'),
    ].join(' · ');
  }

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
                summary: _summary,
                onEdit: () => _edit(
                  context,
                  ref,
                  eventType: null,
                  label: l10n?.validationDefaultPolicy ?? 'Default policy',
                ),
              ),
              for (final type in _cardTypes)
                _PolicyCard(
                  label: eventTypeLabel(l10n, type),
                  effective: policies.isEmpty
                      ? ValidationPolicy.defaults(workspaceId, type.dbName)
                      : policyFor(type.dbName, policies),
                  customized:
                      policies.any((p) => p.eventType == type.dbName),
                  summary: _summary,
                  onEdit: () => _edit(
                    context,
                    ref,
                    eventType: type.dbName,
                    label: eventTypeLabel(l10n, type),
                  ),
                ),
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
    required this.summary,
    required this.onEdit,
  });

  final String label;
  final ValidationPolicy effective;
  final bool customized;
  final String Function(AppLocalizations?, ValidationPolicy) summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        title: HelpDotTitle(
          label,
          l10n?.helpHintValidationTopic ?? 'confirmations',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary(l10n, effective)),
            const SizedBox(height: 2),
            Text(
              customized
                  ? (l10n?.validationCustomized ?? 'Customized')
                  : (l10n?.validationInherited ?? 'Inherits default'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: customized
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onEdit,
      ),
    );
  }
}

