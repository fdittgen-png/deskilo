// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'link_launcher.g.dart';

/// Opens [Uri] outside the app; resolves to false when no handler took it.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// Injectable seam over `launchUrl` so widget tests can capture the exact
/// external link the app would open (#224) — the deep-link twin of the
/// share seam in core/share/share_launcher.dart.
@Riverpod(keepAlive: true)
LinkLauncher linkLauncher(Ref ref) =>
    (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
