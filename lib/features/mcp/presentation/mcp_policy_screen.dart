// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/mcp_policy_editor.dart';
import '../domain/mcp_admin.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';

/// #1626 — the owner decides which assistant services this workspace
/// offers. Exposing a service is not allowing every member: each person
/// still needs this database's approval, their own role, and their own
/// consent (0276), which the screen says rather than implies.
///
/// The workspace is captured when the screen opens; switching workspace
/// while it is open disables Save instead of retargeting it.
class McpPolicyScreen extends ConsumerStatefulWidget {
  const McpPolicyScreen({super.key});

  @override
  ConsumerState<McpPolicyScreen> createState() => _McpPolicyScreenState();
}

class _McpPolicyScreenState extends ConsumerState<McpPolicyScreen> {
  String? _workspaceId;
  McpPolicyDraft? _draft;
  McpPolicy? _base;
  bool _busy = false;
  String? _outcome;

  @override
  void initState() {
    super.initState();
    _workspaceId = ref.read(currentWorkspaceProvider).value?.id;
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    setState(() => _busy = true);
    PolicySaveResult? result;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'policy save failed',
      action: () async =>
          result = await ref.read(mcpPolicyEditorProvider).save(draft),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = result?.status.name;
      // A save that happened, or a conflict to review: start again from
      // what the server holds now. A transient failure keeps the draft.
      if (result != null) {
        _draft = null;
        _base = null;
      }
    });
    if (result != null) ref.invalidate(mcpPolicyProvider(draft.workspaceId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(currentWorkspaceProvider).value?.id;
    final workspaceId = _workspaceId ??= active;
    final switched = active != null && active != workspaceId;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.mcpPolicyTitle ?? 'Assistant access')),
      body: workspaceId == null
          ? const SizedBox.shrink()
          : ref
                .watch(mcpPolicyProvider(workspaceId))
                .when(
                  loading: () => const LoadingView(),
                  error: (e, _) => Padding(
                    padding: AppSpacing.gutterAll,
                    child: InlineBanner(
                      key: const ValueKey('mcp-policy-unavailable'),
                      icon: Icons.cloud_off_outlined,
                      severity: InlineBannerSeverity.error,
                      text:
                          l10n?.mcpPolicyUnavailable ??
                          'The assistant settings could not be loaded. Try again later.',
                    ),
                  ),
                  data: (policy) {
                    final draft = _draft ??= McpPolicyDraft.from(
                      _base = policy,
                    );
                    return _form(context, l10n, policy, draft, switched);
                  },
                ),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations? l10n,
    McpPolicy policy,
    McpPolicyDraft draft,
    bool switched,
  ) {
    final added = draft.added(_base ?? policy);
    return ListView(
      padding: AppSpacing.gutterAll,
      children: [
        if (_outcome != null) _outcomeBanner(l10n, _outcome!),
        if (switched)
          _note(
            'mcp-policy-switched',
            l10n?.mcpPolicySwitched ??
                'You switched workspace. Reopen this page to edit the other workspace.',
            Icons.swap_horiz,
            InlineBannerSeverity.error,
          ),
        Text(
          l10n?.mcpPolicyExplain ??
              'Choose what assistants may do in this workspace. A member still needs this '
                  'database\'s approval, the matching role, and must choose this workspace '
                  'when connecting their assistant.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (!policy.featureEnabled)
          _note(
            'mcp-policy-feature-off',
            l10n?.mcpPolicyFeatureOff ??
                'Assistants are switched off for this workspace in its features. You can still '
                    'narrow or switch off the services below.',
            Icons.toggle_off_outlined,
            InlineBannerSeverity.info,
          ),
        SwitchListTile(
          key: const ValueKey('mcp-policy-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n?.mcpPolicyEnabled ?? 'Offer assistant services'),
          value: draft.enabled,
          onChanged: _busy || (!policy.featureEnabled && !draft.enabled)
              ? null
              : (v) => setState(() => draft.enabled = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n?.mcpPolicyCeiling ?? 'Records an assistant may act on',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          key: const ValueKey('mcp-policy-ceiling'),
          segments: [
            ButtonSegment(
              value: 'own',
              label: Text(l10n?.mcpPolicyCeilingOwn ?? 'Own records only'),
            ),
            ButtonSegment(
              value: 'workspace',
              label: Text(l10n?.mcpPolicyCeilingWorkspace ?? 'Workspace-wide'),
            ),
          ],
          selected: {draft.targetCeiling},
          onSelectionChanged: _busy
              ? null
              : (v) => setState(() => draft.targetCeiling = v.first),
        ),
        for (final group in McpOperationGroup.values)
          ..._group(l10n, policy, draft, group),
        if (added.isNotEmpty && policy.revision > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _note(
            'mcp-policy-broadening',
            l10n?.mcpPolicyBroadening ??
                'Assistants already connected do not get the added services: each person '
                    'must add them when they connect again.',
            Icons.info_outline,
            InlineBannerSeverity.info,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('mcp-policy-save'),
          onPressed: _busy || switched ? null : _save,
          child: Text(l10n?.mcpPolicySave ?? 'Save'),
        ),
      ],
    );
  }

  List<Widget> _group(
    AppLocalizations? l10n,
    McpPolicy policy,
    McpPolicyDraft draft,
    McpOperationGroup group,
  ) {
    final ops = [
      for (final op in policy.available)
        if (mcpOperationGroup(op) == group) op,
    ];
    if (ops.isEmpty) return const [];
    final title = switch (group) {
      McpOperationGroup.own => l10n?.mcpGroupOwn ?? 'Own bookings and account',
      McpOperationGroup.financial =>
        l10n?.mcpGroupFinancial ?? 'Financial requests',
      McpOperationGroup.membership =>
        l10n?.mcpGroupMembership ?? 'Membership requests',
      McpOperationGroup.validations =>
        l10n?.mcpGroupValidations ?? 'Validations',
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
          onChanged: _busy
              ? null
              : (on) => setState(
                  () => (on ?? false)
                      ? draft.operations.add(op)
                      : draft.operations.remove(op),
                ),
        ),
    ];
  }

  Widget _outcomeBanner(
    AppLocalizations? l10n,
    String outcome,
  ) => switch (outcome) {
    'saved' || 'replayed' => _note(
      'mcp-policy-saved',
      l10n?.mcpPolicySaved ?? 'Saved.',
      Icons.check_circle_outline,
      InlineBannerSeverity.info,
    ),
    'stale' => _note(
      'mcp-policy-stale',
      l10n?.mcpPolicyStale ??
          'Someone changed these settings meanwhile. Review the current settings and save again.',
      Icons.sync_problem_outlined,
      InlineBannerSeverity.error,
    ),
    _ => _note(
      'mcp-policy-conflict',
      l10n?.mcpPolicyConflict ??
          'This save was refused. Review the current settings and save again.',
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
