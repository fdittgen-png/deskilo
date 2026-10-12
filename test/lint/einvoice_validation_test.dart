// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the app claims "passes the official validator" for exactly the
// formats in einvoice_validation.dart. That claim holds only while three
// lists agree: the claim, the samples the test writes, and the samples
// the CI script validates. A format added to the claim without a sample,
// or a sample the script never runs, would make the claim a decoration.
import 'dart:io';

import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/einvoice_samples.dart';

void main() {
  final script = File('tool/einvoice/validate.sh').readAsStringSync();
  final samples = File('test/features/money/einvoice_samples_test.dart')
      .readAsStringSync();
  final workflow = File('.github/workflows/einvoice-validate.yml')
      .readAsStringSync();

  test('every format names its validator and its sample', () {
    for (final format in EInvoiceFormat.values) {
      expect(eInvoiceValidators[format], isNotNull, reason: format.name);
      expect(eInvoiceSampleFiles[format], isNotNull, reason: format.name);
    }
  });

  test('every sample is written by the samples test and validated in CI', () {
    for (final file in eInvoiceSampleFiles.values) {
      expect(samples, contains("'$file'"), reason: '$file is never built');
      expect(script, contains(file), reason: '$file is never validated');
    }
  });

  test('the workflow runs the samples test and the script', () {
    expect(
      workflow,
      contains('test/features/money/einvoice_samples_test.dart'),
    );
    expect(workflow, contains('tool/einvoice/validate.sh'));
  });

  test('every validator the app names is the version the script pins', () {
    for (final pin in [
      'validator-1.6.3',
      'Mustang-CLI-2.26.0',
      'v2026-08-31',
      'release-3.0.21',
      'VFPR12_v1.2.3',
      '13775',
    ]) {
      expect(script, contains(pin), reason: pin);
    }
    expect(eInvoiceValidators.values.join(' '), contains('KoSIT 1.6.3'));
    expect(eInvoiceValidators.values.join(' '), contains('Mustang 2.26.0'));
  });
}
