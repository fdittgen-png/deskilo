// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
import 'context_labels.dart';

/// #1824 — where a message may be forwarded: the conversations the
/// forwarder takes part in on the same server, across contexts, each
/// named by its context. The sheet says beforehand what the forward
/// will tell the original conversation.
Future<InboxEntry?> pickForwardTarget(
  BuildContext context, {
  required String source,
  required MessageContextKind fromKind,
  required String fromContextId,
}) => showModalBottomSheet<InboxEntry>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ForwardTargetSheet(
    source: source,
    fromKind: fromKind,
    fromContextId: fromContextId,
  ),
);

class ForwardTargetSheet extends ConsumerWidget {
  const ForwardTargetSheet({
    super.key,
    required this.source,
    required this.fromKind,
    required this.fromContextId,
  });

  final String source;
  final MessageContextKind fromKind;
  final String fromContextId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(unifiedInboxProvider);
    final servers = ref.watch(serverLabelsProvider).value ?? const {};
    return SafeArea(
      key: const ValueKey('forward-target-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.messengerForwardTitle ?? 'Forward to',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n?.messengerForwardExplain ??
                        'Everyone in the original conversation, the author '
                            'first, is told who forwarded it, when, and where to.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: switch (inbox) {
                AsyncData(value: final value) => () {
                  final targets = forwardTargets(
                    value.entries,
                    source: source,
                    fromKind: fromKind,
                    fromContextId: fromContextId,
                  );
                  if (targets.isEmpty) {
                    return Padding(
                      padding: AppSpacing.lgAll,
                      child: Text(
                        l10n?.messengerForwardNoTargets ?? 'No other conversation on this server to forward into.',
                        key: const ValueKey('forward-no-targets'),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in targets)
                        ListTile(
                          key: ValueKey('forward-target-${t.contextId}'),
                          leading: Icon(contextIcon(t.kind)),
                          title: Text(t.title),
                          subtitle: Text(contextSubtitle(l10n, t, servers)),
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                    ],
                  );
                }(),
                AsyncError() => Center(
                  child: TextButton(
                    key: const ValueKey('forward-target-sheet-retry'),
                    onPressed: () => ref.invalidate(unifiedInboxProvider),
                    child: Text(l10n?.commonRetry ?? 'Try again'),
                  ),
                ),
                _ => const LoadingView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
