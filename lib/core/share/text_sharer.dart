// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'text_sharer.g.dart';

/// Hands [text] to the platform share sheet.
typedef TextSharer = Future<void> Function(String text);

/// Injectable seam over `share_plus` text sharing so widget tests can
/// capture the exact message the app would share — the text twin of
/// [linkLauncherProvider] and [fileSaverProvider].
@Riverpod(keepAlive: true)
TextSharer textSharer(Ref ref) =>
    (text) => SharePlus.instance.share(ShareParams(text: text));
