// SPDX-License-Identifier: 0BSD
//
// #1375 / #1376 — the widget that IS the Demo environment.
//
// It mounts the Demo scope as its OWN root `ProviderContainer`, not as a
// nested `ProviderScope`. That is not a style choice: an override in a
// nested scope reaches a provider read directly below it and does NOT
// reach a provider that depends on the overridden one, because the
// dependent is hosted by the root container, where nothing was
// overridden. `myWorkspacesProvider` proved it — inside a nested scope it
// answered from the live container and returned nothing. A separate root
// container has no such seam: everything read below is hosted in it, so
// every provider in the tree resolves to the fixture.
//
// The container is rebuilt whenever [DemoSession.scopeKey] changes — a
// reset (#1375) or a persona switch (#1376) — which is what disposes
// every screen that read the old fixture or the old identity. The session
// controller stays in the OUTER container: one inside would be disposed
// by the very reset it was asked to perform.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../demo_entry.dart';
import '../demo_persona.dart';
import '../demo_scope.dart';
import '../demo_session.dart';

/// Wraps [child] in the Demo environment.
class DemoWorkspace extends ConsumerStatefulWidget {
  const DemoWorkspace({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DemoWorkspace> createState() => _DemoWorkspaceState();
}

class _DemoWorkspaceState extends ConsumerState<DemoWorkspace> {
  ProviderContainer? _container;
  String? _key;

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  ProviderContainer _containerFor(DemoSession session) {
    final existing = _container;
    if (_key == session.scopeKey && existing != null) return existing;
    existing?.dispose();
    _key = session.scopeKey;
    return _container =
        ProviderContainer(overrides: demoOverrides(session.fixture));
  }

  /// Leaves the demonstration space, and forgets the session with it: the
  /// next visitor starts from the canonical dataset, as after a restart.
  void _leave() {
    ref.read(demoEntryProvider.notifier).leave();
    ref.invalidate(demoSessionControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(demoSessionControllerProvider);
    final controller = ref.read(demoSessionControllerProvider.notifier);
    return UncontrolledProviderScope(
      container: _containerFor(session),
      child: DemoEnvironment(
        persona: session.persona,
        onReset: controller.reset,
        onViewAs: controller.viewAs,
        onLeave: _leave,
        child: widget.child,
      ),
    );
  }
}

/// What a widget inside the Demo environment can find out about it.
///
/// It is an [InheritedWidget] rather than a provider on purpose: the
/// session lives in the OUTER container, and a provider read from inside
/// the Demo container would be a second, unrelated copy whose reset did
/// nothing. Its absence is also the answer to "am I in Demo": live mode
/// has no ancestor to find.
class DemoEnvironment extends InheritedWidget {
  const DemoEnvironment({
    required this.persona,
    required this.onReset,
    required this.onViewAs,
    required this.onLeave,
    required super.child,
    super.key,
  });

  final DemoPersona persona;
  final VoidCallback onReset;
  final ValueChanged<DemoPersona> onViewAs;
  final VoidCallback onLeave;

  /// The environment, or null in live mode.
  static DemoEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoEnvironment>();

  @override
  bool updateShouldNotify(DemoEnvironment old) => old.persona != persona;
}

/// The compact control every Demo screen carries: what this space is, who
/// the visitor is looking through, and how to leave or put it back.
///
/// It is one bar above the app rather than a banner each screen has to
/// remember, so the ordinary screens stay the ordinary screens. It is
/// mounted from the app's own `builder`, INSIDE the MaterialApp, because
/// a bar above it would have no theme and no translations.
class DemoControls extends StatelessWidget {
  const DemoControls({required this.child, super.key});

  static const Key resetKey = Key('demo-reset');
  static const Key viewAsKey = Key('demo-view-as');
  static const Key leaveKey = Key('demo-leave');

  final Widget child;

  /// The persona's own name, in the reader's language.
  static String personaLabel(AppLocalizations? l10n, DemoPersona persona) =>
      switch (persona) {
        DemoPersona.member => l10n?.demoPersonaMember ?? 'A member',
        DemoPersona.admin => l10n?.demoPersonaAdmin ?? 'An administrator',
        DemoPersona.owner => l10n?.demoPersonaOwner ?? 'The owner',
      };

  @override
  Widget build(BuildContext context) {
    final env = DemoEnvironment.maybeOf(context);
    if (env == null) return child;
    final persona = env.persona;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
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
              // Wrap, not Row: at 360 dp the badge, the persona and the
              // reset button do not fit on one line.
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
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
                  PopupMenuButton<DemoPersona>(
                    key: viewAsKey,
                    tooltip: l10n?.demoSessionViewAs ?? 'View as',
                    onSelected: env.onViewAs,
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
                        Text(personaLabel(l10n, persona)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: resetKey,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n?.demoSessionReset ?? 'Reset the demo'),
                    onPressed: () => _reset(context, env.onReset, l10n),
                  ),
                  TextButton.icon(
                    key: leaveKey,
                    icon: const Icon(Icons.logout),
                    label: Text(l10n?.demoSessionLeave ?? 'Leave the demo'),
                    onPressed: env.onLeave,
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

  void _reset(BuildContext context, VoidCallback onReset,
      AppLocalizations? l10n) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    onReset();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.demoSessionResetDone ?? 'The demo is back as it started.',
        ),
      ),
    );
  }
}
