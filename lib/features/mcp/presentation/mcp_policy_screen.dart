// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/mcp_policy_form_provider.dart';
import '../providers/mcp_providers.dart';
import 'widgets/mcp_policy_form_view.dart';

export 'widgets/mcp_policy_form_view.dart' show kMcpApiReferenceUrl;

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

  @override
  void initState() {
    super.initState();
    _workspaceId = ref.read(currentWorkspaceProvider).value?.id;
  }

  Future<void> _save(McpPolicy policy) async {
    final form = ref.read(mcpPolicyFormProvider.notifier);
    final draft = form.beginSave(policy);
    if (draft == null) return;
    PolicySaveResult? result;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'policy save failed',
      action: () async =>
          result = await ref.read(mcpPolicyEditorProvider).save(draft),
    );
    if (!mounted) return;
    form.endSave(result);
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
                  data: (policy) => McpPolicyFormView(
                    policy: policy,
                    switched: switched,
                    onSave: () => _save(policy),
                  ),
                ),
    );
  }
}
