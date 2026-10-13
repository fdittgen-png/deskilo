// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/vat/tax_reference.dart';

/// What the form of a new version can get wrong, found before anything is sent.
enum TaxVersionProblem { country, key, date, source, percent }

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _country = RegExp(r'^(\*|[A-Z]{2})$');

/// #2477 -- creating a new version of a tax reference value: the checks a
/// form can make without the server (the server checks the shape again),
/// then the write. A change is a new version from a date, never an edit.
class TaxReferenceCommands {
  const TaxReferenceCommands(this._admin);

  final TaxReferenceAdmin _admin;

  /// The problems of a version before it is sent; empty = sendable.
  Set<TaxVersionProblem> validate({
    required String country,
    required String key,
    required String validFrom,
    required String source,
  }) => {
    if (!_country.hasMatch(country.trim().toUpperCase())) TaxVersionProblem.country,
    if (key.trim().isEmpty) TaxVersionProblem.key,
    if (!_isoDate.hasMatch(validFrom.trim())) TaxVersionProblem.date,
    if (source.trim().isEmpty) TaxVersionProblem.source,
  };

  /// Throws whatever the repository throws; the caller reports it.
  Future<TaxReferenceRow> saveVersion({
    required TaxDomain domain,
    required String country,
    required String key,
    required TaxValue value,
    required String source,
    required bool confirmed,
    required String validFrom,
  }) => _admin.setVersion(
    domain: domain,
    country: country.trim().toUpperCase(),
    key: key.trim(),
    value: value,
    source: source.trim(),
    confirmed: confirmed,
    validFrom: validFrom.trim(),
  );
}
