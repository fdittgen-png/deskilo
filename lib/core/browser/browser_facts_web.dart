// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_facts.dart';

/// The page's own user agent, screen and window.
BrowserFacts? readBrowserFacts() {
  final window = web.window;
  final screen = window.screen;
  return BrowserFacts(
    userAgent: window.navigator.userAgent,
    doNotTrack: _doNotTrack(),
    screenWidth: screen.width,
    screenHeight: screen.height,
    scalingFactor: window.devicePixelRatio,
    colourDepth: screen.colorDepth,
    windowWidth: window.innerWidth,
    windowHeight: window.innerHeight,
  );
}

/// `navigator.doNotTrack` is outside the typed Navigator: '1' means on.
bool _doNotTrack() {
  final value = (web.window.navigator as JSObject)['doNotTrack'];
  return value.isA<JSString>() && (value as JSString).toDart == '1';
}
