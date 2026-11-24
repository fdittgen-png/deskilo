// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3487 — a number a member types is read by `parseDecimalInput` /
// `parseMinorInput` (lib/core/format) and nowhere else: a screen that calls
// `double.tryParse` itself reads `0,5` from a German keyboard as nothing.
// Recorded at 17 presentation sites on ad22e6f68; pinned at 0.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no screen or application file parses a typed decimal by hand', () {
    final files = handWrittenDartFiles('lib').where(
      (f) => RegExp(r'^lib/features/[^/]+/(presentation|application)/')
          .hasMatch(f.path),
    );
    final hits = scanLines(
      files,
      (line) => RegExp(r'\b(double|num)\.(try)?[pP]arse\(').hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason:
          'read typed numbers with parseDecimalInput or parseMinorInput '
          '(lib/core/format):\n${hits.join('\n')}',
    );
  });

  // #4425 -- nor by turning a comma into a dot by hand (which reads `1.234,5`
  // as nothing and sends grouped input as typed), nor by a field that lets only
  // digits and a dot be typed (a comma keyboard cannot type its decimal at all).
  test('no screen or application file reads a decimal comma by hand', () {
    final files = handWrittenDartFiles('lib').where(
      (f) => RegExp(r'^lib/features/[^/]+/(presentation|application)/')
          .hasMatch(f.path),
    );
    final hits = scanLines(files, _byHand);
    expect(
      hits,
      isEmpty,
      reason:
          'read typed numbers with exactQuantityFromInput, decimalTextFromInput '
          'or parseDecimalInput (lib/core/format):\n${hits.join('\n')}',
    );
  });

  test('the hand shapes are seen', () {
    expect(_byHand("final t = raw.trim().replaceAll(',', '.');"), isTrue);
    expect(_byHand("x.replaceAll(',','.')"), isTrue);
    expect(_byHand("inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],"), isTrue);
    expect(_byHand("inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],"), isFalse);
    expect(_byHand('final q = exactQuantityFromInput(raw, locale: locale);'), isFalse);
  });

  test('the old amount parser is gone', () {
    final hits = scanLines(
      handWrittenDartFiles('lib'),
      (line) => line.contains('parseCentsInput'),
    );
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}

/// A decimal comma read by hand: replaced by a dot, or kept out of a field.
bool _byHand(String line) =>
    RegExp(r"replaceAll\(',',\s*'\.'\)").hasMatch(line) ||
    line.contains(r"RegExp(r'[0-9.]')");
