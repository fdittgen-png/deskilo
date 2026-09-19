// SPDX-License-Identifier: 0BSD
//
// #1375 — the widget that IS the Demo environment.
//
// It mounts a `ProviderScope` carrying `demoOverrides`, keyed on the
// session's generation. A reset therefore replaces the whole subtree:
// every provider under it is disposed with the fixture it read, and no
// screen has to be told to refresh. The session controller itself lives
// above this widget, so the reset does not dispose its own owner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../demo_persona.dart';
import '../demo_scope.dart';
import '../demo_session.dart';

/// Wraps [child] in the Demo environment.
class DemoWorkspace extends ConsumerWidget {
  const DemoWorkspace({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(demoSessionControllerProvider);
    return ProviderScope(
      // The key is the fence made visible: a new generation is a new
      // subtree, so nothing that read the old fixture survives.
      key: ValueKey(session.scopeKey),
      overrides: demoOverrides(session.fixture),
      child: DemoControls(child: child),
    );
  }
}

/// The compact control every Demo screen carries: what this space is,
/// and how to put it back.
///
/// It is one bar above the app rather than a banner each screen has to
/// remember, so the ordinary screens stay the ordinary screens.
class DemoControls extends ConsumerWidget {
  const DemoControls({required this.child, super.key});

  static const Key resetKey = Key('demo-reset');
  static const Key viewAsKey = Key('demo-view-as');

  /// The persona's own name, in the reader's language.
  static String personaLabel(AppLocalizations? l10n, DemoPersona persona) =>
      switch (persona) {
        DemoPersona.member => l10n?.demoPersonaMember ?? 'A member',
        DemoPersona.admin => l10n?.demoPersonaAdmin ?? 'An administrator',
        DemoPersona.owner => l10n?.demoPersonaOwner ?? 'The owner',
      };

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reset = l10n?.demoSessionReset ?? 'Reset the demo';
    return Column(
      children: [
        Material(
          color: scheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Semantics(
                    label: l10n?.demoSessionBadgeHint ??
                        'You are exploring a demonstration space. Nothing '
                            'here leaves this device.',
                    child: Text(
                      l10n?.demoSessionBadge ?? 'Demo',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<DemoPersona>(
                    key: viewAsKey,
                    tooltip: l10n?.demoSessionViewAs ?? 'View as',
                    onSelected: (p) => ref
                        .read(demoSessionControllerProvider.notifier)
                        .viewAs(p),
                    itemBuilder: (context) => [
                      for (final p in DemoPersona.values)
                        PopupMenuItem(
                          value: p,
                          child: Text(personaLabel(l10n, p)),
                        ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        // The active persona is on screen at all times, so
                        // "why can I not see that button" always has an
                        // answer in view.
                        Text(personaLabel(
                          l10n,
                          ref.watch(demoSessionControllerProvider).persona,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    key: resetKey,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(reset),
                    onPressed: () => _reset(context, ref, l10n),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  void _reset(BuildContext context, WidgetRef ref, AppLocalizations? l10n) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Read, never watch: this callback outlives the build, and the
    // controller lives in the parent container by design.
    ref.read(demoSessionControllerProvider.notifier).reset();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.demoSessionResetDone ?? 'The demo is back as it started.',
        ),
      ),
    );
  }
}
