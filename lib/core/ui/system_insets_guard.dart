// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// #1008 — the system navigation bar never covers an app button.
///
/// One safe area at the root, bottom only: every screen, sheet, dialog
/// and snack below it stops above the bar, and the band the bar sits
/// on is painted in the scaffold's background so it reads as the app's
/// own edge. The top is left to the app bars, which already handle the
/// status bar; the keyboard inset is untouched.
class SystemInsetsGuard extends StatelessWidget {
  const SystemInsetsGuard({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
