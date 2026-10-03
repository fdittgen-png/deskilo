// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — "Guided tasks", where help is asked for: the guides that ship
// with the app, each started on the live app in the current scope. A
// guide made from a recording starts from its draft in the workbench.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../guide/builtin_guides.dart';
import '../../guide/guide_session.dart';

/// The Help screen's entry; shown behind the `taskRecorder` flag.
class GuidedTasksButton extends ConsumerWidget {
  const GuidedTasksButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('help-guided-tasks'),
      tooltip: l10n?.helpGuidedTasks ?? 'Guided tasks',
      icon: const Icon(Icons.assistant_navigation),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _GuidedTasksSheet(),
      ),
    );
  }
}

class _GuidedTasksSheet extends ConsumerWidget {
  const _GuidedTasksSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppSpacing.gutterH,
              child: Text(
                l10n?.helpGuidedTasks ?? 'Guided tasks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final g in BuiltinGuide.values)
              ListTile(
                key: ValueKey('guided-task-${g.name}'),
                leading: const Icon(Icons.assistant_navigation),
                title: Text(builtinGuideTitle(l10n, g)),
                trailing: Text(l10n?.guideStart ?? 'Start the guide'),
                onTap: () {
                  final started = ref
                      .read(guideSessionProvider.notifier)
                      .start(builtinGuide(l10n, g));
                  final navigator = Navigator.of(context);
                  if (!started) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.guideStartRefused ??
                              'This guide cannot start here: sign in and '
                                  'turn the task recorder on in this '
                                  'workspace.',
                        ),
                      ),
                    );
                    return;
                  }
                  // Back to the app, where the guide is followed.
                  navigator.popUntil((route) => route.isFirst);
                },
              ),
          ],
        ),
      ),
    );
  }
}
