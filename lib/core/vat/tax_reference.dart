// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 (C1 of #2476) — tax reference data: the VAT values a country's law
// decides (a rate, an exemption text, a VAT id pattern, the EU member set)
// are rows with a source and a validity, not constants. This file is the
// pure side: the typed rows, the resolution by date and the two interfaces
// the rest of the app depends on. The Supabase implementation lives beside
// the repositories (`features/money/data`), never in `core/`. The values
// themselves are in `tax_value.dart`.
import '../cache/cache_scope.dart';
import '../data/json_reader.dart';
import 'tax_value.dart';

export 'tax_value.dart';

/// One version of one value: valid from [validFrom] (inclusive) to
/// [validTo] (exclusive, null while open), with the [source] that backs it
/// and whether somebody [confirmed] it against that source.
class TaxReferenceRow {
  const TaxReferenceRow({
    this.id = '',
    required this.country,
    required this.key,
    required this.validFrom,
    this.validTo,
    required this.value,
    required this.source,
    required this.confirmed,
  });

  factory TaxReferenceRow.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'tax_reference');
    final domain = TaxDomain.fromWire(r.string('domain'));
    return TaxReferenceRow(
      id: r.stringOr('id'),
      country: r.string('country'),
      key: r.string('key'),
      validFrom: r.string('valid_from'),
      validTo: r.stringOrNull('valid_to'),
      value: TaxValue.parse(domain, r.objectOrNull('value') ?? JsonReader.orEmpty(null, context: 'tax_reference.value')),
      source: r.string('source'),
      confirmed: r.boolOr('confirmed', false),
    );
  }

  final String id;
  final String country;
  final String key;
  final String validFrom;
  final String? validTo;
  final TaxValue value;
  final String source;
  final bool confirmed;

  TaxDomain get domain => value.domain;

  /// Whether this version is in force on [isoDate] (`YYYY-MM-DD`).
  bool isInForceOn(String isoDate) =>
      validFrom.compareTo(isoDate) <= 0 &&
      (validTo == null || validTo!.compareTo(isoDate) > 0);

  /// This version, ended on [day] (the first day of its successor).
  TaxReferenceRow closedOn(String day) => TaxReferenceRow(
        id: id,
        country: country,
        key: key,
        validFrom: validFrom,
        validTo: day,
        value: value,
        source: source,
        confirmed: confirmed,
      );

  Map<String, Object?> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'domain': domain.wire,
        'country': country,
        'key': key,
        'valid_from': validFrom,
        'valid_to': validTo,
        'value': value.toJson(),
        'source': source,
        'confirmed': confirmed,
      };
}

/// Where a set came from — a screen says so when it is not live.
enum TaxReferenceOrigin { server, cache, bundle }

/// An immutable snapshot of reference rows. A domain calculation takes one
/// as a PARAMETER (resolved for a date with [on]) and never looks anything
/// up itself, so the same document gives the same answer tomorrow and an
/// issued document keeps the values it was issued with.
class TaxReferenceSet {
  const TaxReferenceSet(this.rows, {this.origin = TaxReferenceOrigin.server});

  factory TaxReferenceSet.parse(Object? raw,
      {TaxReferenceOrigin origin = TaxReferenceOrigin.server}) {
    if (raw is! List) {
      throw JsonShapeException('tax_reference', '', 'list', '${raw.runtimeType}');
    }
    return TaxReferenceSet([for (final row in raw) TaxReferenceRow.fromJson(row)],
        origin: origin);
  }

  final List<TaxReferenceRow> rows;
  final TaxReferenceOrigin origin;

  bool get isEmpty => rows.isEmpty;

  /// The version of each value in force on [isoDate]. Versions of one
  /// value never overlap (the store refuses it), so this is exact.
  TaxReferenceSet on(String isoDate) => TaxReferenceSet(
        [
          for (final row in rows)
            if (row.isInForceOn(isoDate)) row,
        ],
        origin: origin,
      );

  /// The rows of [domain], optionally of one [country] (its own rows and
  /// the `*` rows every country shares).
  Iterable<TaxReferenceRow> where(TaxDomain domain, {String? country}) sync* {
    final c = country?.trim().toUpperCase();
    for (final row in rows) {
      if (row.domain != domain) continue;
      if (c != null && row.country != c && row.country != taxReferenceAnyCountry) {
        continue;
      }
      yield row;
    }
  }

  /// Every version of one value, newest first.
  List<TaxReferenceRow> history(TaxDomain domain, String country, String key) =>
      [
        for (final row in rows)
          if (row.domain == domain && row.country == country && row.key == key) row,
      ]..sort((a, b) => b.validFrom.compareTo(a.validFrom));

  /// The row for [key] in [country], falling back to the `*` row. Resolve
  /// with [on] first; this does not look at dates.
  TaxReferenceRow? lookup(TaxDomain domain, String country, String key) {
    final c = country.trim().toUpperCase();
    TaxReferenceRow? shared;
    for (final row in rows) {
      if (row.domain != domain || row.key != key) continue;
      if (row.country == c) return row;
      if (row.country == taxReferenceAnyCountry) shared = row;
    }
    return shared;
  }

  /// The data version: it changes whenever a row is added, closed or
  /// edited, and a cache entry names it so a stale one is recognisable.
  String get revision => cacheDigest('tax-reference-revision', [
        for (final row in [...rows]..sort(_byIdentity))
          '${row.domain.wire}|${row.country}|${row.key}|${row.validFrom}|'
              '${row.validTo ?? ''}|${row.confirmed}|${row.source}|'
              '${row.value.toJson()}',
      ], 16);

  static int _byIdentity(TaxReferenceRow a, TaxReferenceRow b) {
    final byDomain = a.domain.wire.compareTo(b.domain.wire);
    if (byDomain != 0) return byDomain;
    final byCountry = a.country.compareTo(b.country);
    if (byCountry != 0) return byCountry;
    final byKey = a.key.compareTo(b.key);
    return byKey != 0 ? byKey : a.validFrom.compareTo(b.validFrom);
  }

  List<Map<String, Object?>> toJson() => [for (final row in rows) row.toJson()];
}

/// The installation could not give reference data and no copy stands in
/// (neither this person's cache nor the bundle that ships with the app).
class TaxReferenceUnavailable implements Exception {
  const TaxReferenceUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => 'TaxReferenceUnavailable: $cause';
}

/// Reading reference data. Implementations live beside the repositories.
abstract class TaxReferenceSource {
  /// Every version of the rows of [domain] / [country] (all of them when
  /// null), history included — resolve a date with [TaxReferenceSet.on].
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country});
}

/// Writing reference data: the platform administrator's side.
abstract class TaxReferenceAdmin {
  /// Creates a new version of a value from [TaxVersionDraft.validFrom] on;
  /// the version in force is closed on that day, never edited.
  Future<TaxReferenceRow> setVersion(TaxVersionDraft draft);
}

/// What the platform owner proposes: one value from a day on, with the
/// source that backs it.
class TaxVersionDraft {
  const TaxVersionDraft({
    required this.domain,
    required this.country,
    required this.key,
    required this.value,
    required this.source,
    required this.confirmed,
    required this.validFrom,
  });

  final TaxDomain domain;
  final String country;
  final String key;
  final TaxValue value;
  final String source;
  final bool confirmed;
  final String validFrom;
}

/// Both sides, for the one object a platform's editor needs.
abstract interface class TaxReferenceStore
    implements TaxReferenceSource, TaxReferenceAdmin {}

/// A [TaxReferenceSource] that falls back to [bundled] — the copy that
/// ships in the app's instance bundle — when [primary] cannot answer, so a
/// self-hosted or F-Droid build works with no default server. Anything that
/// is not an outage of the installation is not swallowed: a malformed answer
/// from a server is a defect, not a reason to show a copy.
class BundledFallbackTaxReferenceSource implements TaxReferenceSource {
  BundledFallbackTaxReferenceSource(this.primary, this.bundled);

  final TaxReferenceSource primary;
  final Future<TaxReferenceSet> Function() bundled;

  @override
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country}) async {
    try {
      return await primary.load(domain: domain, country: country);
    } on JsonShapeException {
      rethrow;
    } on Object catch (e, st) {
      // trace-exempt: the outage is answered from the bundled copy and, when
      // there is none, rethrown as a typed failure carrying the cause.
      try {
        final copy = await bundled();
        return TaxReferenceSet([
          for (final row in copy.rows)
            if ((domain == null || row.domain == domain) &&
                (country == null ||
                    row.country == country.trim().toUpperCase() ||
                    row.country == taxReferenceAnyCountry))
              row,
        ], origin: TaxReferenceOrigin.bundle);
      } on Object {
        // trace-exempt: rethrown as TaxReferenceUnavailable with the cause.
        Error.throwWithStackTrace(TaxReferenceUnavailable(e), st);
      }
    }
  }
}
