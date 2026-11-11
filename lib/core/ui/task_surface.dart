// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (K3, task surfaces) -- where a task opens. ONE function, two postures:
// on a phone a sheet from the bottom (`showAppSheet`); at the desk (from the
// width where the shell keeps its permanent sidebar,
// `isWideNavigationWidth`) the same body in a centred dialog of bounded width
// ([KitMetrics.taskDialogMaxWidth]). The body is the same widget in both: a
// screen that opens a task calls this, and never decides by width itself.
import 'package:flutter/material.dart';

import '../navigation/navigation_style.dart';
import 'app_sheet.dart';
import 'kit/kit_metrics.dart';

/// Opens [builder] as a task: a sheet on a phone, a centred dialog at the
/// desk. Resolves with what the body pops.
Future<T?> showTaskSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (!isWideNavigationWidth(MediaQuery.sizeOf(context).width)) {
    return showAppSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: KitMetrics.taskDialogMaxWidth,
        ),
        child: builder(context),
      ),
    ),
  );
}
