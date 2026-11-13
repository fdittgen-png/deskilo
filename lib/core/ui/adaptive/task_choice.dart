// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the body of a short task opened with [showTask]: a title, what it
// asks, and its buttons at the end. It is the words of a dialog without the
// dialog's own frame, because the task chooses the frame (a sheet on a
// phone, a dialog at the desk) and keeps the same body across a resize.
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
    child: SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          content,
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
        ],
      ),
    ),
  );
}
