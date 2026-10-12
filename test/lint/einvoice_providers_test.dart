// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — three places name the e-invoice connectors: the function that
// sends (connectors.ts), the screen that configures them
// (einvoice_providers.dart) and the database that stores them (the
// provider check and the secret classification of the migration). A
// field the screen does not ask for is a channel that can never be
// configured; a secret the database classifies as public is a token
// echoed back to the screen. They must agree.
import 'dart:io';

import 'package:deskilo/features/money/domain/einvoice_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// provider → its required fields, as connectors.ts's switch states them.
Map<String, List<String>> _functionFields(String source) {
  final body = source.substring(
    source.indexOf('export function requiredFields'),
    source.indexOf('export function acceptedFormats'),
  );
  final fields = <String, List<String>>{};
  final cases = RegExp(r'(case "(\w+)"|default):\s*return \[([^\]]*)\]')
      .allMatches(body);
  for (final m in cases) {
    final provider = m.group(2) ?? 'generic';
    fields[provider] = [
      for (final f in RegExp(r'"(\w+)"').allMatches(m.group(3)!)) f.group(1)!,
    ];
  }
  return fields;
}

/// The latest migration that restates einvoice_config_is_secret.
String _latestSecretClassifier() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files.reversed
      .map((f) => f.readAsStringSync())
      .firstWhere(
        (s) => s.contains('function public.einvoice_config_is_secret'),
      );
}

void main() {
  final connectors = File('supabase/functions/send-e-invoice/connectors.ts')
      .readAsStringSync();

  test('the screen asks for exactly what the function needs', () {
    expect(_functionFields(connectors), eInvoiceProviderFields);
  });

  test('the database accepts every connector the screen offers', () {
    final sql = _latestSecretClassifier();
    for (final provider in eInvoiceProviderFields.keys) {
      expect(sql, contains("'$provider'"), reason: provider);
    }
  });

  test('every secret stays a secret in the database', () {
    final sql = _latestSecretClassifier();
    final start = sql.indexOf('function public.einvoice_config_is_secret');
    final body = sql.substring(start, sql.indexOf(r'$$;', start));
    final public = {
      for (final literal in RegExp(r"'([^']*)'").allMatches(body))
        for (final word in RegExp('[a-z_]+').allMatches(literal.group(1)!))
          word.group(0)!,
    };
    for (final secret in eInvoiceSecretFields) {
      expect(public, isNot(contains(secret)), reason: secret);
    }
    for (final fields in eInvoiceProviderFields.values) {
      for (final field in fields) {
        if (eInvoiceSecretFields.contains(field)) continue;
        expect(public, contains(field), reason: '$field is not a secret');
      }
    }
  });

  test('every sandbox default the screen offers is the function\'s', () {
    for (final MapEntry(key: provider, value: defaults)
        in eInvoiceSandboxDefaults.entries) {
      for (final url in defaults.values) {
        expect(connectors, contains('"$url"'), reason: '$provider $url');
      }
    }
  });
}
