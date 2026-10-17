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
            'valid_to': r.validTo,
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

  test('a closed version ends the day its successor begins, and none overlap', () {
    final byValue = <String, List<SeedRow>>{};
    for (final r in rows) {
      byValue.putIfAbsent('${r.domain}|${r.country}|${r.key}', () => []).add(r);
    }
    for (final entry in byValue.entries) {
      final versions = entry.value..sort((a, b) => a.validFrom.compareTo(b.validFrom));
      for (var i = 0; i < versions.length; i++) {
        final end = versions[i].validTo;
        if (i == versions.length - 1) {
          expect(end, isNull, reason: '${entry.key}: the newest version is open');
        } else {
          expect(end, versions[i + 1].validFrom,
              reason: '${entry.key}: closed on its successor\'s first day');
        }
      }
    }
  });

  test('a planned version is a proposal until somebody confirms it (#2539)', () {
    for (final r in rows) {
      if (r.domain == 'rate' && r.country == 'CH' && r.validFrom == '2028-01-01') {
        expect(r.confirmed, isFalse, reason: 'the vote of 2026-11-29 has not happened');
        expect(r.source, contains('2026-11-29'));
      }
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

  test('each migration seeds rows of the bundle that no earlier one seeded, and together all of them', () {
    final files = _migrationsWithSeed();
    expect(files, isNotEmpty);
    final texts = [for (final f in files) f.readAsStringSync()];
    final inBundle = rows.map(seedLine).toSet();
    final seeded = <String>{};
    for (final (i, f) in files.indexed) {
      final block = seedBlockOf(texts[i])!
          .split('\n')
          .where((l) => l.startsWith('('))
          .map((l) => l.replaceAll(RegExp(r'[,;]$'), ''))
          .toList();
      for (final line in block) {
        expect(inBundle.contains(line), isTrue,
            reason: '${f.path}: a seeded row is not in the bundle: $line');
        expect(seeded.contains(line), isFalse,
            reason: '${f.path}: a row an earlier migration seeded: $line');
      }
      seeded.addAll(block);
      // The newest block is what the generator writes; an older one is
      // history and is never regenerated.
      if (i == files.length - 1 && i > 0) {
        expect(
          seedBlockOf(texts[i]),
          taxReferenceSeedSql(rowsNotSeededBy(rows, texts.take(i))),
          reason: 'dart run tool/build_tax_reference_seed.dart --migration ${f.path}',
        );
      }
    }
    expect(seeded, inBundle,
        reason: 'a row of the bundle that no migration seeds is missing on the server');
  });
}
