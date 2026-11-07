// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 (of #3328) -- the VAT declaration package is the declaration model: it
// imports core Dart, the money kernel, the tax-reference package, xml, meta and
// itself, and it NEVER names the installed snapshot. Every question about the
// tax reference takes the set as a parameter; the application's wrappers at the
// old paths are the only code that reads `ActiveTaxReference` for it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_vat_declaration';

void main() {
  test('the package imports only what a declaration model may', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final m = importRe.firstMatch(line);
        if (m == null) continue;
        final uri = m.group(1)!;
        // a relative import must stay inside the package's lib/
        final own =
            !uri.contains(':') &&
            Uri.parse(f.path).resolve(uri).path.startsWith('$_root/lib/');
        final ok =
            uri.startsWith('dart:') ||
            uri.startsWith('package:deskilo_money_kernel/') ||
            uri.startsWith('package:deskilo_tax_reference/') ||
            uri.startsWith('package:deskilo_vat_declaration/') ||
            uri.startsWith('package:xml/') ||
            uri.startsWith('package:meta/') ||
            own;
        if (!ok) bad.add('${f.path}:${i + 1}: $uri');
      }
    }
    expect(
      bad,
      isEmpty,
      reason: 'the declaration model reaches nothing else:\n${bad.join('\n')}',
    );
  });

  test(
    'the package depends on the kernel, the tax reference, meta and xml',
    () {
      final text = File('$_root/pubspec.yaml').readAsStringSync();
      final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
          .firstMatch(text)!
          .group(1)!
          .split('\n')
          .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
          .map((l) => l.trim().split(':').first)
          .toList();
      expect(deps, [
        'deskilo_money_kernel',
        'deskilo_tax_reference',
        'meta',
        'xml',
      ]);
    },
  );

  test('no source of the package names the installed snapshot', () {
    final named = [
      for (final f in filesWithExtension(
        '$_root/lib',
        '.dart',
        recursive: true,
      ))
        if (f.readAsStringSync().contains('ActiveTaxReference')) f.path,
    ];
    expect(named, isEmpty, reason: 'the global stays in the application');
  });
}
