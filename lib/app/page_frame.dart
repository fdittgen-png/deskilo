// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3604 (desk F3) — the one place a page is given its measure: the measure
// its route declares (route_classes.dart). The app's builder calls it for the
// window off the desk, the desk's page area for the room beside the
// navigation (desk_scaffold.dart). A route still on `framed` keeps today's
// frame (app_frame.dart: 960, canvas pages 1200); a route with its own
// measure is drawn in it, and no page file wraps itself.
import 'package:flutter/widgets.dart';

import '../core/ui/adaptive/page_measure.dart';
import '../core/ui/app_frame.dart';
import 'route_classes.dart';

/// [child], the page at [path], in its measure. [inside]: framing the desk's
/// page area rather than the window.
Widget framePage(String path, Widget child, {required bool inside}) =>
    switch (measureOf(path)) {
      PageMeasure.framed => AppFrame(
        inside: inside,
        maxWidth: frameWidthFor(path),
        child: child,
      ),
      PageMeasure.reading => ReadingColumn(child: child),
      PageMeasure.form => FormColumn(child: child),
      PageMeasure.work => WorkArea(child: child),
    };
