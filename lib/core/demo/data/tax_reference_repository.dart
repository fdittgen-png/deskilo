// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../vat/tax_reference.dart';

/// #2477 — the tax reference store in memory, with the server's versioning
/// rule: a new version closes the one in force on its first day, a version
/// cannot start on or before the current one, and a value needs a source.
class FakeTaxReferenceRepository implements TaxReferenceStore {
  FakeTaxReferenceRepository([Iterable<TaxReferenceRow> seed = const []])
      : rows = [...seed];

  final List<TaxReferenceRow> rows;

  /// Makes [load] fail, to exercise the bundle fallback.
  Object? failWith;

  @override
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country}) async {
    final failure = failWith;
    if (failure != null) {
      throw failure is Exception ? failure : Exception('$failure');
    }
    return TaxReferenceSet([
      for (final r in rows)
        if ((domain == null || r.domain == domain) &&
            (country == null || r.country == country.toUpperCase()))
          r,
    ]);
  }

  @override
  Future<TaxReferenceRow> setVersion({
    required TaxDomain domain,
    required String country,
    required String key,
    required TaxValue value,
    required String source,
    required bool confirmed,
    required String validFrom,
  }) async {
    if (source.trim().isEmpty) {
      throw ArgumentError('a source is required');
    }
    final i = rows.lastIndexWhere(
        (r) => r.domain == domain && r.country == country && r.key == key);
    if (i >= 0) {
      final last = rows[i];
      if (validFrom.compareTo(last.validFrom) <= 0) {
        throw ArgumentError('a new version must start after ${last.validFrom}');
      }
      rows[i] = TaxReferenceRow(
        id: last.id,
        country: last.country,
        key: last.key,
        validFrom: last.validFrom,
        validTo: validFrom,
        value: last.value,
        source: last.source,
        confirmed: last.confirmed,
      );
    }
    final created = TaxReferenceRow(
      id: 'tax-${rows.length + 1}',
      country: country,
      key: key,
      validFrom: validFrom,
      value: value,
      source: source.trim(),
      confirmed: confirmed,
    );
    rows.add(created);
    return created;
  }
}
