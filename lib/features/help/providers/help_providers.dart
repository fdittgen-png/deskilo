// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../presentation/screens/help_screen.dart';

part 'help_providers.g.dart';

/// The compiled help markdown for [languageCode] (see tool/build_help.dart).
/// A seam so widget tests can inject small content instead of decoding the
/// full bundled guide with its screenshots.
@riverpod
Future<String> helpContent(Ref ref, String languageCode) =>
    rootBundle.loadString(helpAssetFor(languageCode));

/// #1016 — anchor -> heading text for [languageCode], compiled from the
/// guide's `<!-- anchor: … -->` comments.
///
/// Never throws: a bundle without the asset (a widget test injecting its
/// own guide) answers an empty map, and the screen falls back to the
/// substring jump that predates anchors.
@riverpod
Future<Map<String, String>> helpAnchors(Ref ref, String languageCode) async {
  try {
    final raw = await rootBundle.loadString(helpAnchorAssetFor(languageCode));
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {for (final e in decoded.entries) e.key: '${e.value}'};
  } catch (e, st) {
    // trace-exempt: a missing anchor map is the documented fallback path,
    // not a failure — the screen still opens, at the nearest heading.
    assert(() {
      // ignore: avoid_print
      print('help anchors unavailable for $languageCode: $e\n$st');
      return true;
    }());
    return const {};
  }
}
