// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:web/web.dart' as web;

/// Require the Flutter build's base href; do not infer it from a routed URL.
Uri? deploymentBaseUri() {
  final href = web.document.querySelector('base[href]')?.getAttribute('href');
  final parsed = href == null ? null : Uri.tryParse(href);
  final rootPath = href != null && href.startsWith('/') && !href.startsWith('//');
  final absoluteWeb = parsed != null &&
      (parsed.scheme == 'https' || parsed.scheme == 'http') &&
      parsed.host.isNotEmpty && parsed.userInfo.isEmpty;
  if (parsed == null || (!rootPath && !absoluteWeb)) {
    throw StateError('Web deployment base is missing or invalid; configure the build base href and reload.');
  }
  return Uri.parse(web.document.baseURI);
}
