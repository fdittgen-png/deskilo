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

import '../../../app/demo_visit.dart';
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
      onPressed: () => _showDemoEntrySheet(context, ref, null, null),
    );
  }
}

/// #2400 — opens the explanation without the tap, for a link that asked
/// for the demo (`/demo`, `/auth?demo=1`) or a setup example; only where the
/// button would be offered. [beforeEnter] runs once the visitor agreed and
/// the visit is about to start, so a screen keeps its unsubmitted choices
/// only for a visit that really begins (#3235). Answers whether it did.
Future<bool> offerDemoEntry(
  BuildContext context,
  WidgetRef ref, {
  DemoLink? link,
  VoidCallback? beforeEnter,
}) async {
  if (!ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.demoMode)) {
    return false;
  }
  return _showDemoEntrySheet(context, ref, link, beforeEnter);
}

/// Explains the demonstration space, and enters it if the visitor agrees.
///
/// A signed-in person keeps their login: the visit records who they are
/// and where they were ([DemoVisit]), and the sheet says so. The identity
/// is read again after the sheet, so a late "start" after the account or
/// the workspace changed captures nothing and enters nothing.
Future<bool> _showDemoEntrySheet(
  BuildContext context,
  WidgetRef ref,
  DemoLink? link,
  VoidCallback? beforeEnter,
) async {
  // Already inside the demo, or a visit is open: no second one, and the
  // first return target stands.
  if (ref.read(demoEntryProvider)) return false;
  final l10n = context.l10n;
  final visit = ref.read(demoVisitProvider.notifier);
  final before = await _identityOrNull(visit);
  if (!context.mounted) return false;
  final route = before == null ? null : visit.currentRoute();
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
              before == null ? l10n.demoEntryBody : l10n.demoEntryBodySignedIn,
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
  if (!(start ?? false) || !context.mounted) return false;
  if (ref.read(demoEntryProvider)) return false;
  if (await _identityOrNull(visit) != before) return false;
  if (!context.mounted) return false;
  if (before != null &&
      !visit.begin(DemoOrigin(identity: before, route: route))) {
    return false;
  }
  try {
    // The fixture is built here, before anything is committed: a demo
    // that cannot start leaves the real workspace exactly as it was.
    ref.read(demoSessionControllerProvider);
    // #2872 — the link's viewpoint first, then its space and screen once
    // the demo scope exists (DemoWorkspace applies them).
    if (link?.persona case final persona?) {
      ref.read(demoSessionControllerProvider.notifier).viewAs(persona);
    }
  } on Object {
    visit.cancel();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.demoEntryFailed)),
    );
    return false;
  }
  beforeEnter?.call();
  if (link != null) ref.read(pendingDemoLinkProvider.notifier).hold(link);
  ref.read(demoEntryProvider.notifier).enter();
  return true;
}

/// Who is signed in; null when nobody is, or the session cannot be read —
/// then the visit is the public one and nothing is captured.
Future<DemoIdentity?> _identityOrNull(DemoVisit visit) async {
  try {
    return await visit.identity();
  } on Object {
    return null;
  }
}
