// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../vat/tax_reference.dart';

part 'tax_reference_bundle_asset.g.dart';

/// Where the app ships its copy of the tax reference data (#2477): built
/// from the same seed as the migration by `tool/build_tax_reference_seed.dart`.
const _taxReferenceAssetPath = 'assets/instance/tax_reference.json';

/// The set parsed from [json] -- marked as the bundle's, never the server's.
TaxReferenceSet _parseTaxReferenceBundle(String json) => TaxReferenceSet.parse(
      jsonDecode(json),
      origin: TaxReferenceOrigin.bundle,
    );

/// How the app reads the bundled copy -- the asset, or a canned set in tests.
/// It is what a self-hosted or F-Droid build stands on when the installation
/// cannot answer: no default server is assumed.
@Riverpod(keepAlive: true)
Future<TaxReferenceSet> Function() taxReferenceBundleLoader(Ref ref) =>
    () async => _parseTaxReferenceBundle(await rootBundle.loadString(_taxReferenceAssetPath));
