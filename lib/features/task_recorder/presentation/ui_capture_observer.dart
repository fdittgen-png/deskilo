// SPDX-License-Identifier: AGPL-3.0-or-later
// Command tokens and the navigator's window-event adapter.
part of 'ui_capture.dart';

/// A guarded command a guide saw: the guide to tell its result, and the
/// recording's own token when one was live.
class _GuidedCommand {
  const _GuidedCommand(this.guide, this.token, this.guideToken);
  final GuideEventSink guide;
  final OperationToken? token;
  final Object? guideToken;
}

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
