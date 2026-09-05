// SPDX-License-Identifier: 0BSD
//
// #917 — a development workspace says so, everywhere, always.
//
// A space used for trying things out runs the same app, prints the same
// documents and numbers them the same way as one billing real people.
// The only thing that stops a rehearsal invoice being mistaken for a
// real one is that somebody remembers which space they were in. This
// strip removes the need to remember: it sits above every route — the
// shell, the kiosk, a pushed settings screen, the report designer — and
// it cannot be dismissed or switched off, because a marker you can turn
// off marks nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';

/// Wraps [child] with the development strip when the active workspace is
/// a development one. Before a workspace is loaded there is nothing to
/// say, so nothing is shown.
class DevelopmentBanner extends ConsumerWidget {
  const DevelopmentBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null || !workspace.isDevelopment) return child;
    return Column(
      children: [
        const _DevelopmentStrip(),
        Expanded(child: child),
      ],
    );
  }
}

class _DevelopmentStrip extends StatelessWidget {
  const _DevelopmentStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('development-banner'),
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_outlined,
                  size: 14, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  l10n?.developmentBanner ??
                      'Development workspace — nothing here is real',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
