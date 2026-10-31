// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../vat/tax_reference.dart';
import '../vat/tax_reference_active.dart';

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

/// Installs the bundled copy as the snapshot the VAT functions run on (#2478).
/// Called once at start-up, before anything renders: the app then answers
/// "is this country in the EU" with no server, and the installation's own
/// rows replace it when they arrive.
///
/// #3102 (PERF-8) — about 194 KB of JSON: decoded off the UI isolate
/// (`compute`; on the web it stays on the one thread there is), while the
/// rest of start-up runs.
Future<void> installBundledTaxReference() async => ActiveTaxReference.install(
      await compute(
        _parseTaxReferenceBundle,
        await rootBundle.loadString(_taxReferenceAssetPath),
      ),
    );
