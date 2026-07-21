// SPDX-License-Identifier: 0BSD
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
