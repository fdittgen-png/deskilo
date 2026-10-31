// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the records of a space are kept, as far as the app may say it: the
// country its installation's operator declared (`records.hosting_country`,
// a platform setting the operator sets from the hosting contract) and, for
// a Canadian business, the CRA authorisation it holds to keep its records
// outside Canada (`records.cra_authorisation_reference`, a workspace
// setting). The app never infers a location from a region it was built
// with, a language or a URL: nothing declared is said as nothing declared.
// #2375: a German business keeps its electronic books in Germany or another
// EU member state (§ 146 Abs. 2a AO), elsewhere only with the tax office's
// permission (Abs. 2b); membership is the tax reference store's.
// Pure Dart.
import 'package:meta/meta.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';
import '../../../core/vat/place_of_supply.dart' show isEuCountry;
import '../../../core/vat/tax_reference.dart';

/// The platform setting the operator declares the hosting country in.
const String _hostingCountryKey = 'records.hosting_country';

/// The workspace setting a Canadian space states its CRA authorisation in.
const String _craReferenceKey = 'records.cra_authorisation_reference';

/// The country whose law (ETA s.286, ITA s.230) asks for the records to be
/// kept within it unless the CRA permits otherwise.
const String _canada = 'CA';

/// The country whose fiscal code (§ 146 Abs. 2a AO) asks for the books to
/// be kept within the EU unless the tax office permits otherwise.
const String _germany = 'DE';

/// An ISO 3166-1 alpha-2 code, as the operator types it.
final RegExp _countryCode = RegExp(r'^[A-Z]{2}$');

@immutable
class RecordsLocation {
  const RecordsLocation({
    required this.issuerCountry,
    required this.hostingCountry,
    required this.craReference,
    this.hostingInEu = false,
  });

  /// The location of a space of [issuerCountry] as [settings] state it. A
  /// registry that predates the keys (an older server) declares nothing.
  factory RecordsLocation.fromSettings(
    SettingsSet? settings, {
    required String issuerCountry,
    TaxReferenceSet? reference,
  }) {
    String read(String key, String fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<String>(key)
        : fallback;
    final declared = read(
      _hostingCountryKey,
      SettingDefaults.recordsHostingCountry,
    ).trim().toUpperCase();
    final hosting = _countryCode.hasMatch(declared) ? declared : null;
    return RecordsLocation(
      issuerCountry: issuerCountry.trim().toUpperCase(),
      hostingCountry: hosting,
      hostingInEu:
          hosting != null && isEuCountry(hosting, reference: reference),
      craReference: read(
        _craReferenceKey,
        SettingDefaults.recordsCraAuthorisationReference,
      ).trim(),
    );
  }

  /// The space's own country.
  final String issuerCountry;

  /// The country the operator declared, or null when it declared none (or
  /// typed something that is not a country code).
  final String? hostingCountry;

  /// The CRA authorisation reference the space recorded, empty when none.
  final String craReference;

  /// Whether the declared country is an EU member state.
  final bool hostingInEu;

  /// A Canadian business whose records are not declared to be in Canada:
  /// they may be kept elsewhere only with the CRA's authorisation.
  bool get craNotice => issuerCountry == _canada && hostingCountry != _canada;

  /// #2375 — a German business whose books are not declared in the EU:
  /// kept elsewhere, they need the tax office's permission.
  bool get aoNotice => issuerCountry == _germany && !hostingInEu;

  /// The lines an archive's README states, in English.
  List<String> get archiveLines => [
    switch (hostingCountry) {
      final c? =>
        'Records location: hosted in $c, as the operator of this '
            'installation declares it.',
      null =>
        'Records location: not declared by the operator of this '
            'installation; this archive states no location.',
    },
    if (craNotice) ...[
      if (hostingCountry == null)
        'Nothing declares these records kept in Canada (ETA s.286, '
            'ITA s.230).'
      else
        'These records are kept outside Canada (ETA s.286, ITA s.230).',
      if (craReference.isEmpty)
        'CRA authorisation reference: none recorded.'
      else
        'CRA authorisation reference: $craReference.',
    ],
    if (aoNotice)
      if (hostingCountry == null)
        'Nothing declares these books kept in Germany or another EU '
            'member state (§ 146 Abs. 2a AO).'
      else
        'These books are kept outside the EU: this needs the tax '
            "office's permission (§ 146 Abs. 2b AO).",
  ];
}
