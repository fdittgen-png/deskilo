// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §6) — a screen opened from the setup guide carries a
// "Back to the setup guide" bar, whatever screen it is and however deep the
// owner went from there. The guide raises the flag while one of its steps
// is open and lowers it on the way back; the bar sits above the navigator,
// so no settings screen has to know it was opened from the guide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

part 'setup_return_bar.g.dart';

/// Whether a step of the setup guide is open over the guide.
@Riverpod(keepAlive: true)
class SetupReturnPending extends _$SetupReturnPending {
  @override
  bool build() => false;

  void set({required bool open}) => state = open;
}

/// [child], with the way back to the guide under it while a step is open.
class SetupReturnBar extends ConsumerWidget {
  const SetupReturnBar({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(setupReturnPendingProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final onGuide =
            router.routeInformationProvider.value.uri.path == '/setup';
        if (!pending || onGuide) return child;
        return Column(
          children: [
            Expanded(child: child),
            Material(
              key: const ValueKey('setup-return-bar'),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('setup-return'),
                      icon: const Icon(Icons.checklist_outlined),
                      label: Text(context.l10n.setupGuideReturn),
                      onPressed: () => router.go('/setup'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
