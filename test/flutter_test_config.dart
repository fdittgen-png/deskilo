// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2478 -- the VAT functions answer from the tax reference snapshot the app
// installs at start-up. A test starts on the same bundled copy the app ships
// (`assets/instance/tax_reference.json`), so a test that does not care about
// reference data sees exactly the data of production; one that does installs
// its own set and restores this one.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ActiveTaxReference.install(TaxReferenceSet.parse(
    jsonDecode(File('assets/instance/tax_reference.json').readAsStringSync()),
    origin: TaxReferenceOrigin.bundle,
  ));
  await testMain();
}
