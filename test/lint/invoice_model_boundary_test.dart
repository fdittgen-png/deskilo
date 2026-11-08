// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 (of #3328) -- the invoice model package imports core Dart, the money
// kernel, the tax-reference package, the VAT declaration package, the
// jurisdiction standards, freezed_annotation, meta and itself, and it NEVER
// names the installed snapshot or the workspace clock. Every tax-reference
// question takes the set, and the tax-point engine takes the day-of function;
// the one wrapper file in the application (lib/core/vat/invoice_model_wrappers)
// is the only code that passes the globals.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_invoice_model';

void main() {
  test('the package imports only what an invoice model may', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final m = importRe.firstMatch(line);
        if (m == null) continue;
        final uri = m.group(1)!;
        final own =
            !uri.contains(':') &&
            Uri.parse(f.path).resolve(uri).path.startsWith('$_root/lib/');
        final ok =
            uri.startsWith('dart:') ||
            uri.startsWith('package:deskilo_money_kernel/') ||
            uri.startsWith('package:deskilo_tax_reference/') ||
            uri.startsWith('package:deskilo_vat_declaration/') ||
            uri.startsWith('package:deskilo_jurisdiction_standards/') ||
            uri.startsWith('package:deskilo_invoice_model/') ||
            uri.startsWith('package:freezed_annotation/') ||
            uri.startsWith('package:meta/') ||
            uri.startsWith('package:xml/') ||
            own;
        if (!ok) bad.add('${f.path}:${i + 1}: $uri');
      }
    }
    expect(bad, isEmpty, reason: 'the invoice model reaches nothing else:\n${bad.join('\n')}');
  });

  test('the package depends on its five packages, meta and xml', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, [
      'deskilo_jurisdiction_standards',
      'deskilo_money_kernel',
      'deskilo_tax_reference',
      'deskilo_vat_declaration',
      'freezed_annotation',
      'meta',
      'xml',
    ]);
  });

  test('no source of the package names the installed snapshot or the workspace clock', () {
    final named = [
      for (final f in filesWithExtension('$_root/lib', '.dart', recursive: true))
        if (RegExp(r'ActiveTaxReference|WorkspaceTime')
            .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(named, isEmpty, reason: 'the globals stay in the application');
  });

  test('the application reads the globals for the model in ONE file', () {
    final readers = [
      for (final f in filesWithExtension('lib/features/money/domain', '.dart'))
        if (f.readAsStringSync().contains('invoice_model_wrappers')) f.path,
    ];
    expect(readers, isNotEmpty);
    expect(File('lib/core/vat/invoice_model_wrappers.dart').existsSync(), isTrue);
  });
}
