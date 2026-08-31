// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Body shell of a modal form sheet: the keyboard-aware xl padding and the
/// stretched column with a titleMedium header — the scaffolding every
/// money/quota sheet used to copy-paste around its fields.
///
/// Use inside `showModalBottomSheet(isScrollControlled: true, ...)`; the
/// sheet's fields and submit button are the [children].
class SheetShell extends StatelessWidget {
  const SheetShell({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // #769 — a form taller than the sheet must SCROLL, and its last
    // button must clear the system navigation bar (edge-to-edge Android
    // draws under it): the whole shell scrolls, padded by the keyboard
    // (viewInsets) plus the system inset (viewPadding), whichever the
    // moment brings. Fixes "the submit button is cut off" on every form
    // sheet at once — all of them ride this shell.
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: bottomInset + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          ...children,
        ],
      ),
    );
  }
}
