// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../vat/tax_reference.dart';
import 'fixture_clock.dart';

/// #2477 — the tax reference store in memory, with the server's versioning
/// rule: a new version closes the one in force on its first day, a version
/// cannot start on or before the current one, and a value needs a source.
class FakeTaxReferenceRepository implements TaxReferenceStore {
  FakeTaxReferenceRepository([Iterable<TaxReferenceRow> seed = const []])
      : rows = [...seed];

  /// The day "in force" is judged on (the demo's session day).
  String today = kTestNow.toIso8601String().substring(0, 10);

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

  @override
  Future<TaxReferenceRow> confirm(String id, {String? source}) async {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw ArgumentError('unknown version');
    if (rows[i].confirmed) throw StateError('the version is already confirmed');
    return rows[i] = rows[i].confirmedWith(source);
  }

  @override
  Future<void> withdraw(String id, String reason) async {
    if (reason.trim().isEmpty) throw ArgumentError('a reason is required');
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw ArgumentError('unknown version');
    final row = rows[i];
    if (row.confirmed || row.validFrom.compareTo(today) <= 0) {
      throw StateError('a version in force or confirmed is only superseded');
    }
    rows.removeAt(i);
    final prev = rows.lastIndexWhere((r) =>
        r.domain == row.domain &&
        r.country == row.country &&
        r.key == row.key &&
        r.validFrom.compareTo(row.validFrom) < 0 &&
        r.validTo == row.validFrom);
    if (prev < 0) return;
    final later = [
      for (final r in rows)
        if (r.domain == row.domain &&
            r.country == row.country &&
            r.key == row.key &&
            r.validFrom.compareTo(row.validFrom) > 0)
          r.validFrom,
    ]..sort();
    rows[prev] = rows[prev].reopenedUntil(later.isEmpty ? null : later.first);
  }
}
