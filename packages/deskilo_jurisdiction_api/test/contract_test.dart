// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 -- the contract states what a jurisdiction add-on and the host rely
// on: an artifact carries the SHA-256 of its own copy of the bytes and cannot
// be edited through the list it was built from, a descriptor travels as
// provenance with the contract version, and a validation result is ok or a
// list of stable codes with no user-facing text.
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:test/test.dart';

void main() {
  test('an artifact carries the digest of its bytes and cannot be edited '
      'through the list it was built from', () {
    final source = utf8.encode('hello');
    final artifact = GeneratedArtifact(
      bytes: source,
      mediaType: 'text/plain',
      fileName: 'a.txt',
      provenance: const {'module_id': 'x'},
    );
    expect(
      artifact.sha256,
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
    );
    source[0] = 0;
    expect(utf8.decode(artifact.bytes), 'hello');
    expect(() => artifact.provenance['module_id'] = 'y', throwsUnsupportedError);
  });

  test('the descriptor travels as provenance, with the contract version', () {
    const d = CapabilityDescriptor(
      moduleId: 'x.vat_filing',
      implementationVersion: '1',
      contractVersion: jurisdictionContractVersion,
      formatVersion: '2026',
      capabilityId: 'vat_filing.XX',
    );
    expect(d.toProvenance(), {
      'module_id': 'x.vat_filing',
      'implementation_version': '1',
      'contract_version': jurisdictionContractVersion,
      'format_version': '2026',
      'capability_id': 'vat_filing.XX',
    });
  });

  test('a validation result is ok or lists stable codes', () {
    expect(const ValidationResult.ok().isOk, isTrue);
    const refused = ValidationResult.refused([
      ValidationIssue('period'),
      ValidationIssue('taxNumber', field: 'facts.taxNumber'),
    ]);
    expect(refused.isOk, isFalse);
    expect(refused.codes, ['period', 'taxNumber']);
    expect(const ValidationIssue('a'), const ValidationIssue('a'));
  });
}
