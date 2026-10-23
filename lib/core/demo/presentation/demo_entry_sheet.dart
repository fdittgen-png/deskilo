// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1379 — what a visitor is told before they walk in.
//
// The sheet exists because the answer to "is this real?" has to be given
// BEFORE somebody starts clicking, not inferred afterwards from a badge.
// It says three things plainly: the data is invented, nothing reaches a
// real workspace or leaves the device, and no account is needed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import '../../ui/app_sheet.dart';
import '../demo_entry.dart';
import '../demo_link.dart';
import '../demo_session.dart';

/// The button that offers the demonstration space.
class DemoEntryButton extends ConsumerWidget {
  const DemoEntryButton({super.key});

  static const Key buttonKey = Key('demo-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The flag gates the offer (HARD RULE #502). At the sign-in screen no
    // workspace is chosen yet, so this resolves to the registry default;
    // inside a space it is that space's answer.
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.demoMode)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return TextButton.icon(
      key: buttonKey,
      icon: const Icon(Icons.play_circle_outline),
      label: Text(l10n.demoEntryAction),
      onPressed: () => _showDemoEntrySheet(context, ref, null),
    );
  }
}

/// #2400 — opens the explanation without the tap, for a link that asked
/// for the demo (`/auth?demo=1`); only where the button would be offered.
Future<void> offerDemoEntry(
  BuildContext context,
  WidgetRef ref, {
  DemoLink? link,
}) async {
  if (!ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.demoMode)) {
    return;
  }
  await _showDemoEntrySheet(context, ref, link);
}

/// Explains the demonstration space, and enters it if the visitor agrees.
Future<void> _showDemoEntrySheet(
  BuildContext context,
  WidgetRef ref,
  DemoLink? link,
) async {
  final l10n = context.l10n;
  final start = await showAppSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.demoEntryTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.demoEntryBody,
            ),
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const Key('demo-entry-start'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.demoEntryStart),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (!(start ?? false)) return;
  // #2872 — the link's viewpoint first, then its space and screen once
  // the demo scope exists (DemoWorkspace applies them).
  if (link?.persona case final persona?) {
    ref.read(demoSessionControllerProvider.notifier).viewAs(persona);
  }
  if (link != null) ref.read(pendingDemoLinkProvider.notifier).hold(link);
  ref.read(demoEntryProvider.notifier).enter();
}
