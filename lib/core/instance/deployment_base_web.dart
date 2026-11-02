// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:web/web.dart' as web;

/// Require the Flutter build's base href; do not infer it from a routed URL.
Uri? deploymentBaseUri() {
  if (web.document.querySelector('base[href]') == null) {
    throw StateError('The web deployment base is unavailable');
  }
  return Uri.parse(web.document.baseURI);
}
