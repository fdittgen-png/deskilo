// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the body of a short task opened with [showTask]: a title, what it
// asks, and its buttons at the end. It is the words of a dialog without the
// dialog's own frame, because the task chooses the frame (a sheet on a
// phone, a dialog at the desk) and keeps the same body across a resize.
// The buttons stay in sight under a long content (#3615).
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// A short task's body: [title] over [content], [actions] at the end.
class TaskChoice extends StatelessWidget {
  const TaskChoice({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // The buttons stay in sight under a long content, which scrolls.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  content,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ),
        ],
      ),
    ),
  );
}
