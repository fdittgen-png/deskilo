// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 — what a widget can find out about the Demo, and its control bar.
//
// Apart from `demo_workspace.dart` on purpose: the screens of the live app
// ask "am I in the Demo" and the app's builder mounts the bar, so this file
// belongs to the first download, while the workspace that builds the
// session (with the fixture and its seed data) is a deferred library.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../i18n/app_format.dart';
import '../../i18n/format_controller.dart';
import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import '../../time/clock.dart';
import '../demo_persona.dart';

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
    this.returnsToWorkspace = false,
    super.key,
  });

  final DemoPersona persona;
  final VoidCallback onReset;
  final ValueChanged<DemoPersona> onViewAs;
  final VoidCallback onLeave;

  /// #3235 — the visit started from a signed-in person's workspace, and
  /// leaving takes them back to it.
  final bool returnsToWorkspace;

  /// The environment, or null in live mode.
  static DemoEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoEnvironment>();

  @override
  bool updateShouldNotify(DemoEnvironment old) =>
      old.persona != persona || old.returnsToWorkspace != returnsToWorkspace;
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

  /// The next persona in the ring — owner, member, administrator, the
  /// kiosk tablet, round again — so one control covers all four.
  static DemoPersona _next(DemoPersona persona) =>
      DemoPersona.values[(persona.index + 1) % DemoPersona.values.length];

  /// The persona's own name, in the reader's language.
  static String personaLabel(AppLocalizations l10n, DemoPersona persona) {
    final words = l10n;
    return switch (persona) {
      DemoPersona.member => words.demoPersonaMember,
      DemoPersona.admin => words.demoPersonaAdmin,
      DemoPersona.kiosk => words.demoPersonaKiosk,
      DemoPersona.owner => words.demoPersonaOwner,
    };
  }

  @override
  Widget build(BuildContext context) {
    final env = DemoEnvironment.maybeOf(context);
    if (env == null) return child;
    final persona = env.persona;
    final l10n = context.l10n;
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
                    label: l10n.demoSessionBadgeHint,
                    // #3601 — the demo lives on one fixed day: the bar says which.
                    child: Consumer(
                      builder: (context, ref, _) => Text(
                        l10n.demoSessionBadgeDate(
                          ref
                              .watch(appFormatProvider)
                              .dates(DateShape.date)
                              .format(ref.watch(clockProvider).now()),
                        ),
                        key: const ValueKey('demo-bar-date'),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
                  // A cycling button, not a menu: this bar renders in
                  // the app's own `builder`, ABOVE the Navigator, so it
                  // has no Overlay to put a popup or a tooltip in. Four
                  // personas make one tap each the compact answer.
                  TextButton.icon(
                    key: viewAsKey,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    // The active persona is on screen at all times, so
                    // "why can I not see that button" always has an
                    // answer in view.
                    label: Text(personaLabel(l10n, persona)),
                    onPressed: () => viewAs(context, env, _next(persona)),
                  ),
                  TextButton.icon(
                    key: resetKey,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.demoSessionReset),
                    onPressed: () => resetWithNotice(context, env),
                  ),
                  TextButton.icon(
                    key: leaveKey,
                    icon: const Icon(Icons.logout),
                    label: Text(
                      env.returnsToWorkspace
                          ? l10n.demoSessionReturn
                          : l10n.demoSessionLeave,
                    ),
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

  /// Looks through [persona]. What was said to the previous one goes first
  /// (#3286): a message, or its action, of the old viewpoint never shows in
  /// the new one.
  static void viewAs(
    BuildContext context,
    DemoEnvironment env,
    DemoPersona persona,
  ) {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    env.onViewAs(persona);
  }

  /// Puts the demo back as it started, and says so. The messages of the
  /// session that ends go first (#3286); the notice of the reset stays.
  static void resetWithNotice(BuildContext context, DemoEnvironment env) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    env.onReset();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.demoSessionResetDone)));
  }
}
