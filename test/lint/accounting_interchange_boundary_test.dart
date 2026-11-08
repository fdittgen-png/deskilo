// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 (of #3328) -- the accounting interchange package is the contract the
// export formats are written against, and the formats that live in it import
// the money kernel, the shared standards (the CSV cell writer) and crypto (a
// digest), and nothing else: not the application, Flutter, Supabase, Riverpod,
// a platform library, the tax reference, or another package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_accounting_interchange';

void main() {
  test('the package imports core Dart, the kernel, the standards, crypto and '
      'its own files', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final m = importRe.firstMatch(line);
        if (m == null) continue;
        final uri = m.group(1)!;
        final own = !uri.contains(':') && !uri.contains('..');
        final ok =
            uri.startsWith('dart:') ||
            uri.startsWith('package:deskilo_money_kernel/') ||
            uri.startsWith('package:deskilo_jurisdiction_standards/') ||
            uri.startsWith('package:crypto/') ||
            uri.startsWith('package:deskilo_tax_reference/') ||
            uri.startsWith('package:deskilo_vat_declaration/') ||
            uri.startsWith('package:deskilo_invoice_model/') ||
            uri.startsWith('package:meta/') ||
            uri.startsWith('package:deskilo_accounting_interchange/') ||
            own;
        if (!ok) bad.add('${f.path}:${i + 1}: $uri');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'a format may import the kernel and this contract only:\n'
          '${bad.join('\n')}',
    );
  });

  test('the package depends on the kernel, the standards and crypto alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, [
      'crypto',
      'deskilo_invoice_model',
      'deskilo_jurisdiction_standards',
      'deskilo_money_kernel',
      'deskilo_tax_reference',
      'deskilo_vat_declaration',
      'meta',
    ]);
  });
}
