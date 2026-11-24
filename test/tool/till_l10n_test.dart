// SPDX-License-Identifier: AGPL-3.0-or-later
// A missing or unsupported translation must fail before a firmware image builds.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_till_l10n.dart';

void main() {
  late Directory temporary;
  setUp(() => temporary = Directory.systemTemp.createTempSync('till-l10n-'));
  tearDown(() => temporary.deleteSync(recursive: true));

  void seed(String value) {
    for (final locale in tillLocales) {
      File('${temporary.path}/test_$locale.arb')
          .writeAsStringSync(jsonEncode({'example': value}));
    }
  }

  test('generated resources match all five canonical translations', () {
    final keys = (jsonDecode(
      File('firmware/till/l10n_keys.json').readAsStringSync(),
    ) as List<Object?>).cast<String>();
    expect(
      buildTillHeader(Directory('lib/l10n/_fragments'), keys),
      File('firmware/till/generated/till_strings.h').readAsStringSync(),
    );
  });

  test('quotes, accents and currency survive deterministic generation', () {
    seed('é ß ñ à € "OK" \\path');
    final result = buildTillHeader(temporary, ['example']);
    expect(result, contains(r'é ß ñ à € \"OK\"'));
    expect(result, contains(r'\\path'));
    expect(result, buildTillHeader(temporary, ['example']));
  });

  test(
    'missing locale and duplicate origin fail without an English fallback',
    () {
      seed('Ready');
      File('${temporary.path}/test_it.arb').deleteSync();
      expect(
        () => buildTillHeader(temporary, ['example']),
        throwsFormatException,
      );
      seed('Ready');
      File('${temporary.path}/duplicate_en.arb')
          .writeAsStringSync(jsonEncode({'example': 'Other'}));
      expect(
        () => buildTillHeader(temporary, ['example']),
        throwsFormatException,
      );
    },
  );

  test(
    'ICU, control bytes, oversized strings and duplicate keys are refused',
    () {
      for (final bad in [
        '{count} items',
        'a\u0000b',
        'a\u007fb',
        '\ud800',
        '\udfff',
        List<String>.filled(257, 'x').join(),
        List<String>.filled(129, 'é').join(),
      ]) {
        seed(bad);
        expect(
          () => buildTillHeader(temporary, ['example']),
          throwsFormatException,
        );
      }
      seed('Ready');
      expect(
        () => buildTillHeader(temporary, ['example', 'example']),
        throwsFormatException,
      );
    },
  );
}
