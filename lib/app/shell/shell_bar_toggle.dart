// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/ui/mouse_presence.dart';
import 'shell_bar_visibility.dart';
import 'shell_center_button.dart';

/// #3611 — the visible control that hides and shows the bottom bar.
///
/// The bar hid by a swipe, a double tap or a long press on the centre
/// button: nothing a mouse or the keyboard could find. While a mouse is
/// connected this small button sits at the bar's right end, takes focus,
/// answers Enter and Space and names what it will do. A phone in the hand
/// never shows it, so the touch posture is unchanged.
class ShellBarToggle extends ConsumerWidget {
  const ShellBarToggle({super.key});

  /// The button's side: the app's icon-button size, so the theme's
  /// minimum never grows it past the box it sits in.
  static const double size = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MousePresence(
      builder: (context, mouse, _) {
        if (!mouse) return const SizedBox.shrink();
        final l10n = context.l10n;
        final hidden = ref.watch(shellBarHiddenProvider).value ?? false;
        final label = hidden
            ? l10n.shellBarShowAction
            : l10n.shellBarHideAction;
        return IconButton(
          key: const ValueKey(ShellCenterButton.barToggleKey),
          tooltip: label,
          iconSize: 20,
          constraints: const BoxConstraints.tightFor(width: size, height: size),
          padding: EdgeInsets.zero,
          icon: Icon(hidden ? Icons.expand_less : Icons.expand_more),
          onPressed: () async {
            await ref
                .read(shellBarHiddenProvider.notifier)
                .set(hidden: !hidden);
            await ref.read(shellSwipeCoachSeenProvider.notifier).markSeen();
            if (!context.mounted) return;
            unawaited(
              SemanticsService.sendAnnouncement(
                View.of(context),
                hidden
                    ? l10n.shellBarShownAnnounce
                    : l10n.shellBarHiddenAnnounce,
                Directionality.of(context),
              ),
            );
          },
        );
      },
    );
  }
}
