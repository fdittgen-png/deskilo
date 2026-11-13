// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A generated provider file carries, for each provider, the SHA-1 of its
// declaration as the analyzer prints it (annotation included, doc comment
// not). The code-generation gate in CI compares whole files and needs the
// generator; this test compares the hashes in a second, so a generated
// block that was written, copied or left behind by hand fails before a
// push — a provider changed without regenerating, too.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _hashLine = RegExp(
  r"String _\$(\w+)Hash\(\)\s*=>\s*r?'([0-9a-f]{40})';",
);
final _className = RegExp(r'\bclass\s+(\w+)');

bool _isProvider(AnnotatedNode node) => node.metadata.any(
  (a) => a.name.name == 'riverpod' || a.name.name == 'Riverpod',
);

/// The name the generator derives a provider's hash function from.
String? _nameOf(Declaration d) => switch (d) {
  FunctionDeclaration() => d.name.lexeme,
  ClassDeclaration() => switch (_className.firstMatch(d.toSource())?[1]) {
    final String n => n[0].toLowerCase() + n.substring(1),
    null => null,
  },
  _ => null,
};

void main() {
  test('a generated provider hash is the one its declaration gives', () {
    final wrong = <String>[];
    var providers = 0;
    for (final root in ['lib', 'packages']) {
      for (final file in filesWithExtension(root, '.g.dart', recursive: true)) {
        final hashes = {
          for (final m in _hashLine.allMatches(file.readAsStringSync()))
            m[1]!: m[2]!,
        };
        if (hashes.isEmpty) continue;
        final source = File(
          '${file.path.substring(0, file.path.length - '.g.dart'.length)}.dart',
        );
        if (!source.existsSync()) continue;
        final unit = parseString(
          content: source.readAsStringSync(),
          throwIfDiagnostics: false,
        ).unit;
        for (final d in unit.declarations) {
          if (!_isProvider(d)) continue;
          final name = _nameOf(d);
          if (name == null) continue;
          providers++;
          final expected = sha1.convert(utf8.encode(d.toSource())).toString();
          if (hashes[name] != expected) {
            wrong.add('${source.path}: $name');
          }
        }
      }
    }
    // The scan found the providers: a renamed annotation or a moved folder
    // must not turn this test into one that checks nothing.
    expect(providers, greaterThan(0), reason: 'no provider was read');
    expect(
      wrong,
      isEmpty,
      reason:
          'these providers changed, or their generated block was written '
          'by hand: run build_runner, or say so in the hand-over so the '
          'hash is set',
    );
  });
}
