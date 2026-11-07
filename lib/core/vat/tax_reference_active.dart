// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2478 (C2 of #2476) -- the reference snapshot the VAT functions run on and
// the questions they ask of it. A domain function takes a [TaxReferenceSet]
// as an optional PARAMETER; when it is left out, the snapshot the app
// installed at start-up (the bundled copy, then the installation's own rows)
// answers. Nothing here knows a country, a rate or a text: it only resolves
// what the rows say.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

// The pure questions moved with the set (#3401); importers of this file keep
// reading them here until the sweep (#3403).
export 'package:deskilo_tax_reference/deskilo_tax_reference.dart'
    show TaxReferenceQueries;

/// The snapshot the app runs on. Installed once at start-up from the bundled
/// copy and replaced when the installation answers; a test installs its own.
abstract final class ActiveTaxReference {
  static TaxReferenceSet? _set;

  /// The installed snapshot; asking before one is installed is a typed
  /// failure, never an empty answer that reads as "no country is in the EU".
  static TaxReferenceSet get current =>
      _set ??
      (throw const TaxReferenceUnavailable('no tax reference data installed'));

  static bool get isInstalled => _set != null;

  static void install(TaxReferenceSet set) => _set = set;
}
