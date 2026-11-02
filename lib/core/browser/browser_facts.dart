// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — what only a browser knows about itself (HMRC's fraud-prevention
// headers of connection method WEB_APP_VIA_SERVER: user agent, screen, window,
// Do Not Track). A web build reads them from the page; every other build gets
// the stub, which answers null, so nothing is ever guessed.
export 'browser_facts_stub.dart'
    if (dart.library.js_interop) 'browser_facts_web.dart';

/// The page's own facts.
class BrowserFacts {
  const BrowserFacts({
    required this.userAgent,
    required this.doNotTrack,
    required this.screenWidth,
    required this.screenHeight,
    required this.scalingFactor,
    required this.colourDepth,
    required this.windowWidth,
    required this.windowHeight,
  });

  final String userAgent;
  final bool doNotTrack;
  final int screenWidth;
  final int screenHeight;
  final double scalingFactor;
  final int colourDepth;
  final int windowWidth;
  final int windowHeight;
}
