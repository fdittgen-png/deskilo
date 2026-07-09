// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'share_launcher.g.dart';

/// Hands [ShareParams] to the platform share sheet.
typedef ShareLauncher = Future<void> Function(ShareParams params);

/// Injectable seam over `SharePlus.instance.share` so widget tests can
/// capture what the app would hand to the system share sheet (#133).
@Riverpod(keepAlive: true)
ShareLauncher shareLauncher(Ref ref) =>
    (params) async => SharePlus.instance.share(params);
