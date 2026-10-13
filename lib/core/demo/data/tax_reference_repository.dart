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
  Future<TaxReferenceRow> setVersion(TaxVersionDraft draft) async {
    if (draft.source.trim().isEmpty) {
      throw ArgumentError('a source is required');
    }
    final i = rows.lastIndexWhere((r) =>
        r.domain == draft.domain && r.country == draft.country && r.key == draft.key);
    if (i >= 0) {
      final last = rows[i];
      if (draft.validFrom.compareTo(last.validFrom) <= 0) {
        throw ArgumentError('a new version must start after ${last.validFrom}');
      }
      rows[i] = last.closedOn(draft.validFrom);
    }
    final created = TaxReferenceRow(
      id: 'tax-${rows.length + 1}',
      country: draft.country,
      key: draft.key,
      validFrom: draft.validFrom,
      value: draft.value,
      source: draft.source.trim(),
      confirmed: draft.confirmed,
    );
    rows.add(created);
    return created;
  }
}
