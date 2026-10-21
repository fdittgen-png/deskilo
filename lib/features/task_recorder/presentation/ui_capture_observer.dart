// SPDX-License-Identifier: AGPL-3.0-or-later
// The navigator's window-event adapter.
import 'package:flutter/widgets.dart';

import 'ui_capture.dart';

/// #2142 — reports windows pushed and popped on the navigator it watches
/// to the live capture; does nothing while none is live.
class RecorderWindowObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) UiCapture.current?.windowChanged(opened: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) UiCapture.current?.windowChanged(opened: false);
  }
}
