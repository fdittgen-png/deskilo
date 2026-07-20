// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../trace/trace_logger.dart';

part 'link_launcher.g.dart';

/// Opens [Uri] outside the app; resolves to false when no handler took it.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// Injectable seam over `launchUrl` so widget tests can capture the exact
/// external link the app would open (#224) — the deep-link twin of the
/// share seam. Launch failures are traced HERE, once, instead of every
/// call site wrapping its own try/catch (formerly duplicated by the
/// PayPal link and the online-payment approval launch).
@Riverpod(keepAlive: true)
LinkLauncher linkLauncher(Ref ref) => (uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e, st) {
        debugPrint('link launch failed ($uri): $e\n$st');
        TraceLogger.instance
            .error('links', 'link launch failed', error: e, stackTrace: st);
        return false;
      }
    };
