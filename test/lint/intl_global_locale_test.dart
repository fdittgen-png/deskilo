// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3484 — the app writes no locale into intl's globals and reads none from
// them: everything that formats names its locale (the member's
// `AppFormat.locale`, or a document's). A bare `DateFormat.yMMMd()` would
// silently read intl's default, which is the system's now.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/lib_roots.dart';
import 'lint_sources.dart';

void main() {
  final files = handWrittenDartFilesIn(['lib', ...packageLibRoots()]);

  test('nothing reads or writes intl\'s global locale', () {
    final hits = scanLines(
      files,
      RegExp(r'\bIntl\.(defaultLocale|getCurrentLocale|systemLocale)\b').hasMatch,
    );
    expect(hits, isEmpty,
        reason: 'name the locale: AppFormat (appFormatOf(context)) or the '
            "document's:\n${hits.join('\n')}");
  });

  test('no date format is built without its locale', () {
    final hits = scanLines(files, RegExp(r'\bDateFormat\.\w+\(\)').hasMatch);
    expect(hits, isEmpty,
        reason: 'DateFormat.X(locale) or AppFormat.dates:\n${hits.join('\n')}');
  });
}
