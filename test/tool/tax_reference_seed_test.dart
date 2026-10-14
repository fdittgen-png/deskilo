// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477/#2478 -- the seed of the tax reference store. The Dart constants it
// was once READ from are gone (the rows are the only copy, and
// `vat_reference_golden_test.dart` pins what they answer against a golden
// captured before the move), so this file pins the plumbing: the bundled
// copy is what the generator writes, every migration's seed block is the
// rows no earlier migration seeded, and together the blocks hold exactly the
// rows the app ships.
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/tax_reference/seed.dart';

List<File> _migrationsWithSeed() => Directory('supabase/migrations')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.sql') && f.readAsStringSync().contains(seedBegin))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  final rows = buildTaxReferenceSeed();

  test('the bundled copy is what the generator writes', () {
    expect(
      File(bundledSeedPath).readAsStringSync(),
      taxReferenceBundleJson(rows),
      reason: 'dart run tool/build_tax_reference_seed.dart',
    );
  });

  test('the bundled copy parses into typed rows, every one with a source', () {
    final set = TaxReferenceSet.parse(
      rows.map((r) => {
            'domain': r.domain,
            'country': r.country,
            'key': r.key,
            'valid_from': r.validFrom,
            'valid_to': null,
            'value': r.value,
            'source': r.source,
            'confirmed': r.confirmed,
          }).toList(),
    );
    expect(set.rows, hasLength(rows.length));
    for (final r in set.rows) {
      expect(r.source.trim(), isNotEmpty, reason: '${r.country} ${r.key}');
    }
  });

  test('an unverified value is not marked confirmed', () {
    for (final r in rows) {
      if (const {'exemption_text', 'vat_id_pattern', 'catalogue_note', 'group_example'}
          .contains(r.domain)) {
        expect(r.confirmed, isFalse, reason: '${r.domain} ${r.country} ${r.key}');
      }
    }
  });

  test('each migration seeds the rows no earlier one seeded, and together all of them', () {
    final files = _migrationsWithSeed();
    expect(files, isNotEmpty);
    final texts = [for (final f in files) f.readAsStringSync()];
    final seeded = <String>{};
    for (final (i, f) in files.indexed) {
      final expected = rowsNotSeededBy(rows, texts.take(i));
      if (i == 0) {
        // The first block is history: it holds the rows of its day, which
        // the bundle still holds unchanged.
        final block = seedBlockOf(texts[i])!;
        for (final line in block.split('\n').where((l) => l.startsWith('('))) {
          expect(
            rows.map(seedLine).contains(line.replaceAll(RegExp(r'[,;]$'), '')),
            isTrue,
            reason: '${f.path}: a seeded row is not in the bundle: $line',
          );
        }
      } else {
        expect(
          seedBlockOf(texts[i]),
          taxReferenceSeedSql(expected),
          reason: 'dart run tool/build_tax_reference_seed.dart --migration ${f.path}',
        );
      }
      seeded.addAll(
        seedBlockOf(texts[i])!
            .split('\n')
            .where((l) => l.startsWith('('))
            .map((l) => l.replaceAll(RegExp(r'[,;]$'), '')),
      );
    }
    expect(seeded, rows.map(seedLine).toSet(),
        reason: 'a row of the bundle that no migration seeds is missing on the server');
  });
}
