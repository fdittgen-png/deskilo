// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web half of the capture seam (#1824). A browser cannot block a
// screenshot and offers no event when one is taken; the one thing a
// page can know is that it is no longer the thing being looked at — the
// tab went to the background, or the window lost focus. The messenger
// blurs its threads then, so a thread is not left readable behind a
// screenshot tool's own window or on a shared screen that switched away.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// True when the page stopped being looked at (hidden or unfocused),
/// false when it is again.
Stream<bool> webObscuredChanges() {
  late final StreamController<bool> controller;
  final onVisibility = ((web.Event _) {
    controller.add(web.document.hidden);
  }).toJS;
  final onBlur = ((web.Event _) => controller.add(true)).toJS;
  final onFocus = ((web.Event _) => controller.add(false)).toJS;
  controller = StreamController<bool>.broadcast(
    onListen: () {
      web.document.addEventListener('visibilitychange', onVisibility);
      web.window.addEventListener('blur', onBlur);
      web.window.addEventListener('focus', onFocus);
    },
    onCancel: () {
      web.document.removeEventListener('visibilitychange', onVisibility);
      web.window.removeEventListener('blur', onBlur);
      web.window.removeEventListener('focus', onFocus);
    },
  );
  return controller.stream;
}
