// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web lint: no integer literal the web build cannot hold.
//
// Compiled to JavaScript, an integer is a double: a literal above 2^53 is a
// compile error ("can't be represented exactly in JavaScript"), which only
// the web build finds, half an hour after the push. A 64-bit hash written by
// hand did exactly that. A digest belongs to `package:crypto`, which is the
// same on every platform.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/lib_roots.dart';
import 'lint_sources.dart';

/// Hexadecimal literals of 14 digits or more (56 bits) and decimal literals
/// of 17 digits or more are beyond what a double holds exactly.
final _wide = RegExp(r'\b(0[xX][0-9a-fA-F_]{14,}|[0-9][0-9_]{16,})\b');

/// The wide literals of [source], comments and strings left out line by line.
List<String> wideLiterals(String source) => [
      for (final line in source.split('\n'))
        if (!line.trimLeft().startsWith('//'))
          for (final m in _wide.allMatches(_withoutStrings(line)))
            if (_isWide(m.group(0)!)) m.group(0)!,
    ];

String _withoutStrings(String line) => line
    .replaceAll(RegExp(r"'(\\.|[^'\\])*'"), "''")
    .replaceAll(RegExp(r'"(\\.|[^"\\])*"'), '""');

bool _isWide(String literal) {
  final digits = literal.replaceAll('_', '');
  final value = BigInt.tryParse(digits) ??
      BigInt.tryParse(digits.substring(2), radix: 16);
  return value != null && value > BigInt.from(9007199254740992);
}

void main() {
  test('a planted wide literal is found; a safe one, a comment and a string '
      'are not', () {
    expect(wideLiterals('var a = 0xcbf29ce484222325;'), hasLength(1));
    expect(wideLiterals('var a = 12345678901234567890;'), hasLength(1));
    expect(wideLiterals('var a = 0x100000001b3;'), isEmpty);
    expect(wideLiterals('var a = 9007199254740992;'), isEmpty);
    expect(wideLiterals('// 0xcbf29ce484222325'), isEmpty);
    expect(wideLiterals("var a = '210000000003139471430009017';"), isEmpty);
  });

  test('no integer literal in the app or its packages is beyond what the '
      'web build holds', () {
    final found = <String>[];
    for (final file in handWrittenDartFilesIn(['lib', ...packageLibRoots()])) {
      final wide = wideLiterals(file.readAsStringSync());
      if (wide.isNotEmpty) found.add('${file.path}: ${wide.join(', ')}');
    }
    expect(found, isEmpty,
        reason: 'use package:crypto for a digest, or BigInt for arithmetic');
  });
}
