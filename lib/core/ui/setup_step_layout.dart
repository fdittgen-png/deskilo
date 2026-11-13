// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's step page: what the owner does on one side, "what your
// members will see" on the other. #3619 — below the expanded window class
// (of the room the page is given) the two panes become one column, the form first, so a phone reads the step
// top to bottom and never squeezes two panes side by side.
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_spacing.dart';
import 'adaptive/window_class.dart';

class SetupStepLayout extends StatelessWidget {
  const SetupStepLayout({
    super.key,
    required this.form,
    required this.preview,
    this.previewTitle,
  });

  final Widget form;
  final Widget preview;
  final String? previewTitle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pane = _PreviewPane(title: previewTitle, child: preview);
      if (WindowClass.ofWidth(box.maxWidth).index <
          WindowClass.expanded.index) {
        return ListView(
          key: const ValueKey('setup-step-one-column'),
          padding: AppSpacing.lgAll,
          children: [
            form,
            const SizedBox(height: AppSpacing.lg),
            pane,
          ],
        );
      }
      return Row(
        key: const ValueKey('setup-step-two-panes'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(padding: AppSpacing.lgAll, children: [form]),
          ),
          Expanded(
            child: ListView(padding: AppSpacing.lgAll, children: [pane]),
          ),
        ],
      );
    },
  );
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.child, this.title});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('setup-step-preview'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title ?? context.l10n.setupStepPreviewTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
