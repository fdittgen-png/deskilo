// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 (of #3328) -- the money kernel is the bottom of the accounting model:
// it imports nothing of the application, Flutter or any package, and the old
// paths of what moved into it are shims that only re-export, listed here until
// the sweep PR deletes them (the list only shrinks).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_money_kernel';

/// The old paths, kept as re-exports until every importer is rewritten.
const _shims = {
  'lib/core/vat/tax_domain.dart',
  'lib/core/vat/tax_value.dart',
  'lib/core/vat/rate_component.dart',
  'lib/core/vat/sales_tax_component.dart',
  'lib/core/vat/tax_reference.dart',
  'lib/features/money/domain/accounting_interchange.dart',
  'lib/features/money/domain/accounting_export_sources.dart',
  'lib/features/money/domain/accounting_format_model.dart',
  'lib/core/data/json_reader.dart',
  'lib/core/i18n/currencies.dart',
  'lib/core/time/date_text.dart',
  'lib/features/money/domain/accounting_amount.dart',
  'lib/features/money/domain/book_period.dart',
  'lib/features/money/domain/book_profile.dart',
  'lib/features/money/domain/fiscal_year.dart',
  'lib/features/money/domain/posting.dart',
};

void main() {
  test('the kernel imports core Dart, crypto and its own files only', () {
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
        if (!uri.startsWith('dart:') && !uri.startsWith('package:crypto/') && !own) bad.add('${f.path}:${i + 1}: $uri');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'the kernel may not reach the application, Flutter or a package '
          '(not even a global like the active tax reference):\n${bad.join('\n')}',
    );
  });

  test('the kernel depends on crypto alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, ['crypto']);
  });

  test('a shim only re-exports a package', () {
    final exportRe = RegExp(
      r"^export 'package:deskilo_(money_kernel|accounting_interchange|tax_reference)/deskilo_\1\.dart';$",
    );
    for (final path in _shims) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))
          .toList();
      expect(code, hasLength(1), reason: '$path holds more than a re-export');
      expect(exportRe.hasMatch(code.single), isTrue, reason: path);
    }
  });

  test('no other file in lib only re-exports the kernel', () {
    final found = <String>{};
    for (final f in handWrittenDartFiles('lib')) {
      final code = f
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))
          .toList();
      if (code.length == 1 && RegExp(r"^export 'package:deskilo_(money_kernel|accounting_interchange|tax_reference)/").hasMatch(code.single)) {
        found.add(f.path);
      }
    }
    expect(
      found,
      _shims,
      reason: 'a new shim is a new dependency to justify; the list only shrinks',
    );
  });
}
