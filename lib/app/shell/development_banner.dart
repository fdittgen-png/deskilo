// SPDX-License-Identifier: AGPL-3.0-or-later
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
import '../../core/demo/presentation/demo_workspace.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_colors.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../../core/theme/app_typography.dart';

/// Keeps the active workspace's environment visible. Demo has its own
/// persistent strip; Me and the unloaded state have no workspace context.
class DevelopmentBanner extends ConsumerWidget {
  const DevelopmentBanner({super.key, this.hidden = false, required this.child});

  /// #1823 — the Me layer is the person's, not the space's: no strip there.
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final show = !hidden && workspace != null && DemoEnvironment.maybeOf(context) == null;
    // Always the same Column, the body last: the strip coming and going
    // (a space entered, Me reached) never rebuilds the navigator below.
    return Column(
      children: [
        if (show) _DevelopmentStrip(development: workspace.isDevelopment),
        Expanded(key: const ValueKey('layer-body'), child: child),
      ],
    );
  }
}

class _DevelopmentStrip extends StatelessWidget {
  const _DevelopmentStrip({required this.development});
  final bool development;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // #917 — orange, the same orange the workspace switcher paints on a
    // development space, so the two agree at a glance.
    final ink = development ? AppEnvironmentColors.developmentOf(
        Theme.of(context).brightness) : AppEnvironmentColors.productionOf(
        Theme.of(context).brightness);
    return Material(
      key: ValueKey(development ? 'development-banner' : 'production-banner'),
      color: ink,
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
              Icon(development ? Icons.construction_outlined : Icons.workspaces_outline,
                  size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  development ? (l10n ?? AppLocalizationsEn()).uxTestSpaceHint
                      : '${(l10n ?? AppLocalizationsEn()).uxRealWorkspace} · ${(l10n ?? AppLocalizationsEn()).uxRealSpaceHint}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.emphasised
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
