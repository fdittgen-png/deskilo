// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the records of a space are kept, as far as the app may say it: the
// country its installation's operator declared (`records.hosting_country`,
// a platform setting the operator sets from the hosting contract) and, for
// a Canadian business, the CRA authorisation it holds to keep its records
// outside Canada (`records.cra_authorisation_reference`, a workspace
// setting). The app never infers a location from a region it was built
// with, a language or a URL: nothing declared is said as nothing declared.
// Pure Dart.
import 'package:meta/meta.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';

/// The platform setting the operator declares the hosting country in.
const String _hostingCountryKey = 'records.hosting_country';

/// The workspace setting a Canadian space states its CRA authorisation in.
const String _craReferenceKey = 'records.cra_authorisation_reference';

/// The country whose law (ETA s.286, ITA s.230) asks for the records to be
/// kept within it unless the CRA permits otherwise.
const String _canada = 'CA';

/// An ISO 3166-1 alpha-2 code, as the operator types it.
final RegExp _countryCode = RegExp(r'^[A-Z]{2}$');

@immutable
class RecordsLocation {
  const RecordsLocation({
    required this.issuerCountry,
    required this.hostingCountry,
    required this.craReference,
  });

  /// The location of a space of [issuerCountry] as [settings] state it. A
  /// registry that predates the keys (an older server) declares nothing.
  factory RecordsLocation.fromSettings(
    SettingsSet? settings, {
    required String issuerCountry,
  }) {
    String read(String key, String fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<String>(key)
        : fallback;
    final declared = read(
      _hostingCountryKey,
      SettingDefaults.recordsHostingCountry,
    ).trim().toUpperCase();
    return RecordsLocation(
      issuerCountry: issuerCountry.trim().toUpperCase(),
      hostingCountry: _countryCode.hasMatch(declared) ? declared : null,
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

  /// A Canadian business whose records are not declared to be in Canada:
  /// they may be kept elsewhere only with the CRA's authorisation.
  bool get craNotice => issuerCountry == _canada && hostingCountry != _canada;

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
  ];
}
