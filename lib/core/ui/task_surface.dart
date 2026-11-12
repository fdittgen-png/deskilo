// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (K3, task surfaces) -- the first helper of the task surface, kept
// for its callers: a short task, opened through [showTask]
// (adaptive/task_surface.dart), which chooses the container from the window
// class and keeps the task one route across a resize.
import 'package:flutter/widgets.dart';

import 'adaptive/task_surface.dart';

/// Opens [builder] as a short task: a sheet on a phone, a dialog of bounded
/// width on a wider window. Resolves with what the body pops.
Future<T?> showTaskSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showTask<T>(context, size: TaskSize.short, builder: builder);
