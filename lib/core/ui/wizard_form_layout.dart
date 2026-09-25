// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A form and its actions share one scroll surface when height is scarce.
/// Scaffold already removes keyboard insets; SafeArea handles system edges.
class WizardFormLayout extends StatelessWidget {
  const WizardFormLayout({super.key, required this.header, required this.footer,
    required this.child, this.maxWidth = shortFormWidth});

  static const double shortFormWidth = 560;
  static const double pinnedFooterMinHeight = 420;
  final Widget header;
  final Widget footer;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final compact = box.maxHeight < pinnedFooterMinHeight *
        MediaQuery.textScalerOf(context).scale(1);
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: AppSpacing.lgAll, child: child),
      ),
    );
    return SafeArea(top: false, bottom: false, child: compact
        ? SingleChildScrollView(child: Column(children: [header, content, footer]))
        : Column(children: [header,
            Expanded(child: SingleChildScrollView(child: content)), footer]));
  });
}
