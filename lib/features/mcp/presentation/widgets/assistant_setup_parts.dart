// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/instance_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/assistant_setup.dart';
import '../../providers/assistant_setup_providers.dart';
import '../assistant_setup_labels.dart';
import '../connect_assistant_screen.dart';
import '../mcp_operation_labels.dart';

class AssistantSetupStepCard extends StatelessWidget {
  const AssistantSetupStepCard({
    super.key,
    required this.item,
    required this.actions,
    this.extra,
  });

  final AssistantSetupItem item;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final done = item.state == AssistantSetupState.done;
    return Card(
      key: ValueKey('assistant-setup-${item.step.name}-${item.state.name}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  assistantSetupStateIcon(item.state),
                  color: done ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    assistantSetupStepTitle(l10n, item.step),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(assistantSetupStepReason(l10n, item.step)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${assistantSetupStateLabel(l10n, item.state)} · '
              '${assistantSetupActorLabel(l10n, item.actor)}',
              style: theme.textTheme.bodySmall,
            ),
            if (extra != null && !done) ...[
              const SizedBox(height: AppSpacing.sm),
              extra!,
            ],
            if (actions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: actions,
              ),
          ],
        ),
      ),
    );
  }
}

/// The connector URL to copy and the three steps in the assistant.
class AssistantConnectorInstructions extends ConsumerWidget {
  const AssistantConnectorInstructions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final url = ref.watch(mcpConnectorUrlProvider);
    if (url == null) {
      return Text(
        key: const ValueKey('assistant-setup-no-connector'),
        l10n.assistantSetupNoConnector,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          key: const ValueKey('assistant-setup-connector-url'),
          '$url',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('assistant-setup-copy-url'),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.assistantSetupCopyUrl),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '$url'));
              if (context.mounted) {
                AppSnack.success(context, l10n.assistantSetupCopied);
              }
            },
          ),
        ),
        Text(l10n.assistantSetupConnectHowTo),
        // #2145 — the steps per assistant, one-click links and a test.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.mcpAccess))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('assistant-setup-open-guide'),
              onPressed: () => context.push(connectAssistantRoute),
              child: Text(l10n.mcpConnectOpenGuide),
            ),
          ),
      ],
    );
  }
}

/// #1829 — who answers for this installation, by name only: the
/// installation step waits on them. Their addresses stay on the Instance
/// card; nothing private is shown to explain a blocker.
class AssistantInstanceContact extends ConsumerWidget {
  const AssistantInstanceContact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final who = ref.watch(instanceResponsiblesProvider).value;
    if (who == null) return const SizedBox.shrink();
    if (who.isOperator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const ValueKey('assistant-setup-instance-you'),
            l10n.assistantSetupInstanceYou,
          ),
          // #2145 — the place where that is done, one tap away.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('assistant-setup-open-installation'),
              onPressed: () => context.push('/installation/assistants'),
              child: Text(l10n.mcpConnectOpenInstallation),
            ),
          ),
        ],
      );
    }
    final names = [
      for (final p in [...who.owners, ...who.delegates])
        if (p.name.isNotEmpty) p.name,
    ];
    if (names.isEmpty) {
      return Text(
        key: const ValueKey('assistant-setup-instance-nobody'),
        l10n.assistantSetupInstanceNobody,
      );
    }
    return Text(
      key: const ValueKey('assistant-setup-instance-names'),
      l10n.assistantSetupInstanceNames(names.join(', ')),
    );
  }
}

/// What "Use the recommended set" would change, before anything is sent.
class AssistantPreviewDialog extends StatelessWidget {
  const AssistantPreviewDialog({
    super.key,
    required this.added,
    required this.removed,
    required this.narrows,
    required this.unchanged,
  });

  final Set<String> added;
  final Set<String> removed;
  final bool narrows;
  final bool unchanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    List<Widget> section(String key, String title, Set<String> ops) => [
      if (ops.isNotEmpty) ...[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final op in ops.toList()..sort())
          Text(
            key: ValueKey('assistant-setup-preview-$key-$op'),
            '• ${mcpOperationLabel(l10n, op)}',
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
    return AlertDialog(
      key: const ValueKey('assistant-setup-preview'),
      title: Text(l10n.assistantSetupPreviewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unchanged)
              Text(
                key: const ValueKey('assistant-setup-preview-unchanged'),
                l10n.assistantSetupPreviewNone,
              )
            else ...[
              ...section('add', l10n.assistantSetupPreviewAdds, added),
              ...section('remove', l10n.assistantSetupPreviewRemoves, removed),
              if (narrows)
                Text(
                  key: const ValueKey('assistant-setup-preview-own'),
                  l10n.assistantSetupPreviewOwn,
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.assistantSetupPreviewNote),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('assistant-setup-preview-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        if (!unchanged)
          FilledButton(
            key: const ValueKey('assistant-setup-preview-apply'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.assistantSetupApply),
          ),
      ],
    );
  }
}
