// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477/#2478 -- the seed of the tax reference store. Until #2478 it was READ
// from the Dart constants it replaced; those are gone (the rows are the only
// copy), so the seed is now the bundled copy `assets/instance/tax_reference.json`
// itself -- the app's offline data AND the source of every migration's seed
// block. A row is added to the asset (by hand or by the editor's export) and
// `--migration` writes the rows no earlier migration seeded into that
// migration's block; `test/tool/tax_reference_seed_test.dart` fails when a
// block or the asset drifts from what this file writes.
import 'dart:convert';
import 'dart:io';

/// One seed row (the table's `id` and system columns are the server's).
typedef SeedRow = ({
  String domain,
  String country,
  String key,
  String validFrom,
  Map<String, Object?> value,
  String source,
  bool confirmed,
});

const bundledSeedPath = 'assets/instance/tax_reference.json';

/// Every seed row, sorted by domain, country, key and validity.
List<SeedRow> buildTaxReferenceSeed({String path = bundledSeedPath}) {
  final raw = jsonDecode(File(path).readAsStringSync()) as List<Object?>;
  final rows = [
    for (final r in raw.cast<Map<String, Object?>>())
      (
        domain: r['domain']! as String,
        country: r['country']! as String,
        key: r['key']! as String,
        validFrom: r['valid_from']! as String,
        value: (r['value']! as Map).cast<String, Object?>(),
        source: r['source']! as String,
        confirmed: r['confirmed']! as bool,
      ),
  ]..sort((a, b) {
      final byDomain = a.domain.compareTo(b.domain);
      if (byDomain != 0) return byDomain;
      final byCountry = a.country.compareTo(b.country);
      if (byCountry != 0) return byCountry;
      final byKey = a.key.compareTo(b.key);
      return byKey != 0 ? byKey : a.validFrom.compareTo(b.validFrom);
    });
  return rows;
}

String _q(String s) => "'${s.replaceAll("'", "''")}'";

/// One row as a line of a seed block.
String seedLine(SeedRow r) =>
    '(${_q(r.domain)}, ${_q(r.country)}, ${_q(r.key)}, ${_q(r.validFrom)}, '
    '${_q(jsonEncode(r.value))}::jsonb, ${_q(r.source)}, ${r.confirmed})';

/// The `insert` of the migration's seed block, one row per line.
String taxReferenceSeedSql(List<SeedRow> rows) {
  final lines = [for (final r in rows) seedLine(r)];
  return 'insert into public.tax_reference\n'
      '  (domain, country, key, valid_from, value, source, confirmed)\n'
      'values\n${lines.join(',\n')}\n'
      'on conflict (domain, country, key, valid_from) do nothing;';
}

const seedBegin = '-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)';
const seedEnd = '-- END GENERATED SEED';

/// [migration] with its seed block replaced by the current seed.
String withTaxReferenceSeed(String migration, List<SeedRow> rows) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) {
    throw StateError('the migration has no seed block between "$seedBegin" '
        'and "$seedEnd"');
  }
  return '${migration.substring(0, start)}$seedBegin\n'
      '${taxReferenceSeedSql(rows)}\n${migration.substring(end)}';
}

/// The seed block of [migration], as written.
String? seedBlockOf(String migration) {
  final start = migration.indexOf(seedBegin);
  final end = migration.indexOf(seedEnd);
  if (start < 0 || end < start) return null;
  return migration.substring(start + seedBegin.length + 1, end - 1);
}

/// The app's offline copy: one row per line, sorted, so two pull requests
/// that add different rows merge without a conflict.
String taxReferenceBundleJson(List<SeedRow> rows) {
  final lines = [
    for (final r in rows)
      jsonEncode({
        'domain': r.domain,
        'country': r.country,
        'key': r.key,
        'valid_from': r.validFrom,
        'valid_to': null,
        'value': r.value,
        'source': r.source,
        'confirmed': r.confirmed,
      }),
  ];
  return '[\n${lines.join(',\n')}\n]\n';
}

/// The rows of [rows] that none of [earlier] migrations seeded: what a new
/// migration's block carries.
List<SeedRow> rowsNotSeededBy(List<SeedRow> rows, Iterable<String> earlier) {
  final seeded = {
    for (final migration in earlier)
      ...?seedBlockOf(migration)?.split('\n').map((l) => l.replaceAll(RegExp(r'[,;]$'), '')),
  };
  return [
    for (final r in rows)
      if (!seeded.contains(seedLine(r))) r,
  ];
}
