// SPDX-License-Identifier: 0BSD
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'trace/trace_logger.dart';

part 'app_info.g.dart';

/// The installed app version as "x.y.z+build" (#560) — shown in the
/// About section. '' when the platform channel is unavailable (tests,
/// exotic embeddings): the tile then simply shows no subtitle.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (e, st) {
    TraceLogger.instance
        .warn('app', 'package info unavailable', error: e, stackTrace: st);
    return '';
  }
}
