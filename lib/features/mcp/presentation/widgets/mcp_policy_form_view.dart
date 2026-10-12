// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/mcp_policy_editor.dart';
import '../../domain/mcp_admin.dart';
import '../../providers/mcp_policy_form_provider.dart';
import '../mcp_operation_labels.dart';
import 'mcp_disclosure_preview.dart';
import 'mcp_usage_cards.dart';

/// #1801 — the self-hosted Swagger UI (#1799), served with the web app.
@visibleForTesting
const kMcpApiReferenceUrl = 'https://fdittgen-png.github.io/deskilo/api/';

/// The policy form: the draft lives in [mcpPolicyFormProvider], every
/// toggle goes through it; [onSave] saves the draft.
class McpPolicyFormView extends ConsumerWidget {
  const McpPolicyFormView({
    super.key,
    required this.policy,
    required this.switched,
    required this.onSave,
  });

  final McpPolicy policy;
  final bool switched;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final form = ref.watch(mcpPolicyFormProvider);
    final notifier = ref.read(mcpPolicyFormProvider.notifier);
    final draft = form.draft ?? notifier.draftFor(policy);
    final busy = form.busy;
    final outcome = form.outcome;
    void edit(void Function(McpPolicyDraft d) change) =>
        notifier.edit(policy, change);
    final added = draft.added(form.base ?? policy);
    return ListView(
      padding: AppSpacing.gutterAll,
      children: [
        if (outcome != null) _outcomeBanner(l10n, outcome),
        if (switched)
          _note(
            'mcp-policy-switched',
            l10n.mcpPolicySwitched,
            Icons.swap_horiz,
            InlineBannerSeverity.error,
          ),
        Text(l10n.mcpPolicyExplain),
        const SizedBox(height: AppSpacing.md),
        McpWorkspaceUsageCard(workspaceId: policy.workspaceId),
        // #1801 — the reference of what an assistant can call, and how.
        if (policy.featureEnabled)
          ListTile(
            key: const ValueKey('mcp-api-reference'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.api_outlined),
            title: Text(l10n.mcpApiReference),
            subtitle: Text(l10n.mcpApiReferenceHint),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                ref.read(linkLauncherProvider)(Uri.parse(kMcpApiReferenceUrl)),
          ),
        if (!policy.featureEnabled)
          _note(
            'mcp-policy-feature-off',
            l10n.mcpPolicyFeatureOff,
            Icons.toggle_off_outlined,
            InlineBannerSeverity.info,
          ),
        SwitchListTile(
          key: const ValueKey('mcp-policy-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.mcpPolicyEnabled),
          value: draft.enabled,
          onChanged: busy || (!policy.featureEnabled && !draft.enabled)
              ? null
              : (v) => edit((d) => d.enabled = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.mcpPolicyCeiling,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          key: const ValueKey('mcp-policy-ceiling'),
          segments: [
            ButtonSegment(value: 'own', label: Text(l10n.mcpPolicyCeilingOwn)),
            ButtonSegment(
              value: 'workspace',
              label: Text(l10n.mcpPolicyCeilingWorkspace),
            ),
          ],
          selected: {draft.targetCeiling},
          onSelectionChanged: busy
              ? null
              : (v) => edit((d) => d.targetCeiling = v.first),
        ),
        for (final group in mcpOperationGroups)
          ..._group(context, l10n, draft, group, busy, edit),
        ..._disclosure(context, l10n, draft, busy, edit),
        if (added.isNotEmpty && policy.revision > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _note(
            'mcp-policy-broadening',
            l10n.mcpPolicyBroadening,
            Icons.info_outline,
            InlineBannerSeverity.info,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('mcp-policy-save'),
          onPressed: busy || switched ? null : onSave,
          child: Text(l10n.mcpPolicySave),
        ),
      ],
    );
  }

  List<Widget> _group(
    BuildContext context,
    AppLocalizations l10n,
    McpPolicyDraft draft,
    String group,
    bool busy,
    void Function(void Function(McpPolicyDraft d) change) edit,
  ) {
    final ops = [
      for (final op in policy.available)
        if (mcpOperationGroup(op) == group) op,
    ];
    if (ops.isEmpty) return const [];
    final title = switch (group) {
      McpOperationGroups.own => l10n.mcpGroupOwn,
      McpOperationGroups.financial => l10n.mcpGroupFinancial,
      McpOperationGroups.membership => l10n.mcpGroupMembership,
      McpOperationGroups.validations => l10n.mcpGroupValidations,
      _ => l10n.mcpGroupOther,
    };
    return [
      const SizedBox(height: AppSpacing.md),
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      for (final op in ops)
        CheckboxListTile(
          key: ValueKey('mcp-policy-op-$op'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: draft.operations.contains(op),
          title: Text(mcpOperationLabel(l10n, op)),
          onChanged: busy
              ? null
              : (on) => edit(
                  (d) => (on ?? false)
                      ? d.operations.add(op)
                      : d.operations.remove(op),
                ),
        ),
    ];
  }

  /// #1809 — the optional fields, only within the installation maximum,
  /// and what they change in a fictional answer.
  List<Widget> _disclosure(
    BuildContext context,
    AppLocalizations l10n,
    McpPolicyDraft draft,
    bool busy,
    void Function(void Function(McpPolicyDraft d) change) edit,
  ) => [
    const SizedBox(height: AppSpacing.md),
    Text(
      l10n.mcpDisclosureTitle,
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: AppSpacing.sm),
    Text(l10n.mcpDisclosurePolicyExplain),
    if (policy.availableOptionalFields.isEmpty)
      _note(
        'mcp-policy-fields-none',
        l10n.mcpDisclosureNoneAllowed,
        Icons.lock_outline,
        InlineBannerSeverity.info,
      ),
    for (final field in policy.availableOptionalFields)
      CheckboxListTile(
        key: ValueKey('mcp-policy-field-$field'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: draft.optionalFields.contains(field),
        title: Text(mcpOptionalFieldLabel(l10n, field)),
        onChanged: busy
            ? null
            : (on) => edit(
                (d) => (on ?? false)
                    ? d.optionalFields.add(field)
                    : d.optionalFields.remove(field),
              ),
      ),
    const SizedBox(height: AppSpacing.sm),
    McpDisclosurePreview(fields: draft.optionalFields),
  ];

  Widget _outcomeBanner(AppLocalizations l10n, String outcome) =>
      switch (outcome) {
        'saved' || 'replayed' => _note(
          'mcp-policy-saved',
          l10n.mcpPolicySaved,
          Icons.check_circle_outline,
          InlineBannerSeverity.info,
        ),
        'stale' => _note(
          'mcp-policy-stale',
          l10n.mcpPolicyStale,
          Icons.sync_problem_outlined,
          InlineBannerSeverity.error,
        ),
        _ => _note(
          'mcp-policy-conflict',
          l10n.mcpPolicyConflict,
          Icons.error_outline,
          InlineBannerSeverity.error,
        ),
      };

  Widget _note(
    String key,
    String text,
    IconData icon,
    InlineBannerSeverity severity,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: InlineBanner(
      key: ValueKey(key),
      icon: icon,
      severity: severity,
      text: text,
    ),
  );
}
