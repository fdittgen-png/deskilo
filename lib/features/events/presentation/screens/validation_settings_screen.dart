// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
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
  EventType.roleChange,
  EventType.memberJoin,
  EventType.reservation,
  EventType.adjustment,
];

/// A pickable validator: an active non-owner admin (owners always may
/// validate, so they are never listed in the specific-admins picker).
typedef _AdminChoice = ({String id, String name});

/// Owner-only editor for the workspace's validation policies (#131, epic
/// #121, ADR 0008): how many accepts a pending event needs and who may
/// provide them — per event type, with a workspace-wide default. The
/// server (migration 0017) enforces the rules; this screen only edits
/// their source of truth.
class ValidationSettingsScreen extends ConsumerWidget {
  const ValidationSettingsScreen({super.key});

  String _typeLabel(AppLocalizations? l10n, EventType type) {
    return switch (type) {
      EventType.reservation => l10n?.eventTypeReservation ?? 'Reservation',
      EventType.payment => l10n?.eventTypePayment ?? 'Payment',
      EventType.expense => l10n?.eventTypeExpense ?? 'Expense',
      EventType.adjustment => l10n?.eventTypeAdjustment ?? 'Adjustment',
      EventType.serviceCharge => l10n?.eventTypeServiceCharge ?? 'Service',
      EventType.quota => l10n?.eventTypeQuota ?? 'Extra half-days',
      EventType.roleChange => l10n?.eventTypeRoleChange ?? 'Role change',
      EventType.memberJoin => l10n?.eventTypeMemberJoin ?? 'New member',
    };
  }

  /// "2 required · All admins · Owner must always validate" — the
  /// effective rule at a glance.
  String _summary(AppLocalizations? l10n, ValidationPolicy policy) {
    final who = !policy.adminsMayValidate
        ? (l10n?.validationOwnerOnly ?? 'Owner only')
        : policy.eligibleAdminIds.isEmpty
            ? (l10n?.validationAllAdmins ?? 'All admins')
            : '${l10n?.validationSpecificAdmins ?? 'Specific admins'} '
                '(${policy.eligibleAdminIds.length})';
    return [
      '${l10n?.validationRequiredCount ?? 'Required validations'}: '
          '${policy.requiredCount}',
      who,
      if (policy.ownerRequired)
        l10n?.validationOwnerRequired ?? 'Owner must always validate',
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
    );
    final admins = <_AdminChoice>[
      for (final m in members)
        if (m.isAdmin && !m.isOwner && m.status == MemberStatus.active)
          (id: m.id, name: names[m.id] ?? m.id),
    ];
    final ownerCount = members
        .where((m) => m.isOwner && m.status == MemberStatus.active)
        .length;

    final result = await showModalBottomSheet<ValidationPolicy>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PolicyEditorSheet(
        title: label,
        initial: draft,
        admins: admins,
        ownerCount: ownerCount,
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
                  label: _typeLabel(l10n, type),
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
                    label: _typeLabel(l10n, type),
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
        title: Text(label),
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

/// Edits one policy row. Pops the edited [ValidationPolicy] on save, null
/// on cancel. Save is blocked (with a message) when the required count can
/// never be reached by the eligible pool — owners + eligible admins, plus
/// one for the subject's own accept on admin-initiated events.
class _PolicyEditorSheet extends StatefulWidget {
  const _PolicyEditorSheet({
    required this.title,
    required this.initial,
    required this.admins,
    required this.ownerCount,
  });

  final String title;
  final ValidationPolicy initial;
  final List<_AdminChoice> admins;
  final int ownerCount;

  @override
  State<_PolicyEditorSheet> createState() => _PolicyEditorSheetState();
}

class _PolicyEditorSheetState extends State<_PolicyEditorSheet> {
  static const _maxRequired = 10;

  late int _requiredCount = widget.initial.requiredCount.clamp(1, _maxRequired);
  late bool _adminsMayValidate = widget.initial.adminsMayValidate;
  late bool _ownerRequired = widget.initial.ownerRequired;

  /// Empty = all admins. Stored ids of members no longer pickable are
  /// dropped so the pool math below never counts ghosts.
  late final Set<String> _selectedAdminIds = {
    for (final id in widget.initial.eligibleAdminIds)
      if (widget.admins.any((a) => a.id == id)) id,
  };

  bool _notEnough = false;

  /// Distinct members who could contribute an accept under the current
  /// switches (mirrors respond_to_event eligibility, migration 0017).
  int get _poolSize =>
      widget.ownerCount +
      (!_adminsMayValidate
          ? 0
          : _selectedAdminIds.isEmpty
              ? widget.admins.length
              : _selectedAdminIds.length);

  void _save() {
    // +1: on admin-initiated events the subject's accept counts too.
    if (_requiredCount > _poolSize + 1) {
      setState(() => _notEnough = true);
      return;
    }
    Navigator.of(context).pop(
      widget.initial.copyWith(
        requiredCount: _requiredCount,
        adminsMayValidate: _adminsMayValidate,
        eligibleAdminIds:
            _adminsMayValidate ? (_selectedAdminIds.toList()..sort()) : const [],
        ownerRequired: _ownerRequired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n?.validationRequiredCount ?? 'Required validations',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _requiredCount > 1
                          ? () => setState(() {
                                _requiredCount--;
                                _notEnough = false;
                              })
                          : null,
                    ),
                    Text(
                      '$_requiredCount',
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _requiredCount < _maxRequired
                          ? () => setState(() {
                                _requiredCount++;
                                _notEnough = false;
                              })
                          : null,
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n?.validationAdminsMay ?? 'Admins may validate',
                ),
                subtitle: _adminsMayValidate
                    ? null
                    : Text(l10n?.validationOwnerOnly ?? 'Owner only'),
                value: _adminsMayValidate,
                onChanged: (value) => setState(() {
                  _adminsMayValidate = value;
                  _notEnough = false;
                }),
              ),
              if (_adminsMayValidate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: Text(l10n?.validationAllAdmins ?? 'All admins'),
                        selected: _selectedAdminIds.isEmpty,
                        onSelected: (_) => setState(() {
                          _selectedAdminIds.clear();
                          _notEnough = false;
                        }),
                      ),
                      for (final admin in widget.admins)
                        FilterChip(
                          label: Text(admin.name),
                          selected: _selectedAdminIds.contains(admin.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _selectedAdminIds.add(admin.id)
                                : _selectedAdminIds.remove(admin.id);
                            _notEnough = false;
                          }),
                        ),
                    ],
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n?.validationOwnerRequired ??
                      'Owner must always validate',
                ),
                value: _ownerRequired,
                onChanged: (value) =>
                    setState(() => _ownerRequired = value),
              ),
              if (_notEnough)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n?.validationNotEnough ??
                        'Not enough eligible validators.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n?.commonCancel ?? 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n?.commonSave ?? 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
