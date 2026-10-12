// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/mcp_policy_editor.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';
import 'widgets/mcp_disclosure_preview.dart';
import 'widgets/mcp_usage_cards.dart';

/// #1801 — the self-hosted Swagger UI (#1799), served with the web app.
@visibleForTesting
const kMcpApiReferenceUrl = 'https://fdittgen-png.github.io/deskilo/api/';

/// #1626 — the owner decides which assistant services this workspace
/// offers. Exposing a service is not allowing every member: each person
/// still needs this database's approval, their own role, and their own
/// consent (0276), which the screen says rather than implies.
///
/// The workspace is captured when the screen opens; switching workspace
/// while it is open disables Save instead of retargeting it. #1625 — so
/// is the installation and account: the policy is read and saved for the
/// context captured first, never for whatever becomes active later.
class McpPolicyScreen extends ConsumerStatefulWidget {
  const McpPolicyScreen({super.key});

  @override
  ConsumerState<McpPolicyScreen> createState() => _McpPolicyScreenState();
}

class _McpPolicyScreenState extends ConsumerState<McpPolicyScreen> {
  String? _workspaceId;
  VerifiedMcpTarget? _target;
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
    final scope = draft.context;
    if (result != null && scope != null) {
      ref.invalidate(mcpPolicyProvider(scope));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = ref.watch(currentWorkspaceProvider).value?.id;
    final workspaceId = _workspaceId ??= active;
    final current = ref.watch(activeMcpTargetProvider);
    final target = _target ??= current.value;
    final switched =
        (active != null && active != workspaceId) ||
        (current.value != null && current.value != target);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcpPolicyTitle)),
      body: workspaceId == null
          ? const SizedBox.shrink()
          : target == null && current.isLoading
          ? const LoadingView()
          : (target == null
                    ? AsyncValue<McpPolicy>.error(
                        current.error ?? const McpTargetUnverified(''),
                        current.stackTrace ?? StackTrace.empty,
                      )
                    : ref.watch(
                        mcpPolicyProvider(target.workspace(workspaceId)),
                      ))
                .when(
                  loading: () => const LoadingView(),
                  error: (e, _) => Padding(
                    padding: AppSpacing.gutterAll,
                    child: InlineBanner(
                      key: const ValueKey('mcp-policy-unavailable'),
                      icon: Icons.cloud_off_outlined,
                      text:
                          l10n.mcpPolicyUnavailable,
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
    AppLocalizations l10n,
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
            l10n.mcpPolicySwitched,
            Icons.swap_horiz,
            InlineBannerSeverity.error,
          ),
        Text(
          l10n.mcpPolicyExplain,
        ),
        const SizedBox(height: AppSpacing.md),
        McpWorkspaceUsageCard(workspaceId: policy.workspaceId),
        // #1801 — the reference of what an assistant can call, and how.
        if (policy.featureEnabled)
          ListTile(
            key: const ValueKey('mcp-api-reference'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.api_outlined),
            title: Text(l10n.mcpApiReference),
            subtitle: Text(
              l10n.mcpApiReferenceHint,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => ref.read(linkLauncherProvider)(
              Uri.parse(kMcpApiReferenceUrl),
            ),
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
          onChanged: _busy || (!policy.featureEnabled && !draft.enabled)
              ? null
              : (v) => setState(() => draft.enabled = v),
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
            ButtonSegment(
              value: 'own',
              label: Text(l10n.mcpPolicyCeilingOwn),
            ),
            ButtonSegment(
              value: 'workspace',
              label: Text(l10n.mcpPolicyCeilingWorkspace),
            ),
          ],
          selected: {draft.targetCeiling},
          onSelectionChanged: _busy
              ? null
              : (v) => setState(() => draft.targetCeiling = v.first),
        ),
        for (final group in McpOperationGroup.values)
          ..._group(l10n, policy, draft, group),
        ..._disclosure(l10n, policy, draft),
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
          onPressed: _busy || switched ? null : _save,
          child: Text(l10n.mcpPolicySave),
        ),
      ],
    );
  }

  List<Widget> _group(
    AppLocalizations l10n,
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
      McpOperationGroup.own => l10n.mcpGroupOwn,
      McpOperationGroup.financial =>
        l10n.mcpGroupFinancial,
      McpOperationGroup.membership =>
        l10n.mcpGroupMembership,
      McpOperationGroup.validations =>
        l10n.mcpGroupValidations,
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

  /// #1809 — the optional fields, only within the installation maximum,
  /// and what they change in a fictional answer.
  List<Widget> _disclosure(
    AppLocalizations l10n,
    McpPolicy policy,
    McpPolicyDraft draft,
  ) => [
    const SizedBox(height: AppSpacing.md),
    Text(
      l10n.mcpDisclosureTitle,
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: AppSpacing.sm),
    Text(
      l10n.mcpDisclosurePolicyExplain,
    ),
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
        onChanged: _busy
            ? null
            : (on) => setState(
                () => (on ?? false)
                    ? draft.optionalFields.add(field)
                    : draft.optionalFields.remove(field),
              ),
      ),
    const SizedBox(height: AppSpacing.sm),
    McpDisclosurePreview(fields: draft.optionalFields),
  ];

  Widget _outcomeBanner(
    AppLocalizations l10n,
    String outcome,
  ) => switch (outcome) {
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
