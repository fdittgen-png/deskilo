// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The approvals step's two pictures. The flow: a member's request, the
// people who decide and how many of them must accept, and what follows.
// The member's view: what a member reads once a request that needs
// approval is sent.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/approvals_preset.dart';

class SetupApprovalsFlow extends StatelessWidget {
  const SetupApprovalsFlow({
    super.key,
    required this.preset,
    required this.required,
  });

  final ApprovalsPreset preset;

  /// How many approvals a request needs.
  final int required;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('setup-approvals-flow'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stage(
          key: const ValueKey('setup-approvals-flow-request'),
          icon: Icons.person_outline,
          title: l10n.setupApprovalsFlowRequest,
          body: l10n.setupApprovalsFlowRequestBody,
        ),
        const _Arrow(),
        _Stage(
          key: const ValueKey('setup-approvals-flow-validators'),
          icon: Icons.groups_outlined,
          title: l10n.setupApprovalsFlowValidators(required, preset.people),
          body: l10n.setupApprovalsFlowWho(preset.owners, preset.admins),
        ),
        const _Arrow(),
        _Stage(
          key: const ValueKey('setup-approvals-flow-outcome'),
          icon: Icons.task_alt_outlined,
          title: l10n.setupApprovalsFlowOutcome,
          body: l10n.setupApprovalsFlowOutcomeBody(required),
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Icon(Icons.arrow_downward),
  );
}

/// What a member reads once a request is sent: the confirmation, then
/// the request waiting for its approvals.
class SetupApprovalsMemberView extends StatelessWidget {
  const SetupApprovalsMemberView({super.key, required this.required});

  /// How many approvals the request waits for.
  final int required;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('setup-approvals-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.inverseSurface,
          shape: const StadiumBorder(),
          child: Padding(
            padding: AppSpacing.mdAll,
            child: Text(
              l10n.validationSentForApproval,
              key: const ValueKey('setup-approvals-preview-sent'),
              style: TextStyle(color: theme.colorScheme.onInverseSurface),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.hourglass_top_outlined),
            title: Text(l10n.setupApprovalsPreviewRequest),
            subtitle: Text(
              l10n.setupApprovalsPreviewWaiting(required),
              key: const ValueKey('setup-approvals-preview-waiting'),
            ),
          ),
        ),
      ],
    );
  }
}
