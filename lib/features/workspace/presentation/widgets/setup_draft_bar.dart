// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where a setup step's draft stands, above its form: restored from the
// server (with Discard), saving, saved once the server confirmed, not
// saved (with Retry), or changed by another configurer (Reload / Keep
// mine). The words carry the state, never a colour alone, and a change of
// state is announced.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/setup_draft_autosave.dart';
import '../../domain/setup_step_draft.dart';

class SetupDraftBar extends ConsumerWidget {
  const SetupDraftBar({
    super.key,
    required this.draft,
    required this.restored,
    required this.onDiscard,
    required this.onReload,
  });

  /// The step's draft.
  final SetupDraftAutosaveProvider draft;

  /// Whether the form shows answers restored from the draft.
  final ValueListenable<bool> restored;

  final VoidCallback onDiscard;

  /// Takes the other configurer's answers ([SetupDraftConflicted.theirs]).
  final ValueChanged<SetupStepDraft?> onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(draft);
    final status = switch (state) {
      SetupDraftSaving() => l10n.setupDraftSaving,
      SetupDraftSaved() => l10n.setupDraftSaved,
      SetupDraftFailed() => l10n.setupDraftNotSaved,
      SetupDraftIdle() || SetupDraftConflicted() => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state is SetupDraftConflicted)
          _Notice(
            key: const ValueKey('setup-draft-conflict'),
            icon: Icons.sync_problem,
            text: l10n.setupDraftChanged,
            actions: [
              TextButton(
                key: const ValueKey('setup-draft-reload'),
                onPressed: () => onReload(state.theirs),
                child: Text(l10n.setupDraftReload),
              ),
              TextButton(
                key: const ValueKey('setup-draft-keep-mine'),
                onPressed: () => ref.read(draft.notifier).keepMine(),
                child: Text(l10n.setupDraftKeepMine),
              ),
            ],
          )
        else
          ValueListenableBuilder<bool>(
            valueListenable: restored,
            builder: (context, shown, _) => !shown
                ? const SizedBox.shrink()
                : _Notice(
                    key: const ValueKey('setup-draft-restored'),
                    icon: Icons.restore,
                    text: l10n.setupDraftRestored,
                    actions: [
                      TextButton(
                        key: const ValueKey('setup-draft-discard'),
                        onPressed: onDiscard,
                        child: Text(l10n.setupDraftDiscard),
                      ),
                    ],
                  ),
          ),
        if (status != null)
          Semantics(
            liveRegion: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  status,
                  key: const ValueKey('setup-draft-status'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state is SetupDraftFailed)
                  TextButton(
                    key: const ValueKey('setup-draft-retry'),
                    onPressed: () => ref.read(draft.notifier).retry(),
                    child: Text(l10n.commonRetry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.text,
    required this.actions,
  });

  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.mdAll,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            Wrap(alignment: WrapAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}
