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
    expect(
      () => artifact.bytes[0] = 0,
      throwsUnsupportedError,
      reason: 'the bytes the digest was computed from are read-only',
    );
    expect(
      () => artifact.provenance['module_id'] = 'y',
      throwsUnsupportedError,
    );
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
    final refused = ValidationResult.refused([
      ValidationIssue('period'),
      ValidationIssue('taxNumber', field: 'facts.taxNumber'),
    ]);
    expect(refused.isOk, isFalse);
    expect(refused.codes, ['period', 'taxNumber']);
    expect(const ValidationIssue('a'), const ValidationIssue('a'));
    expect(
      () => refused.issues.add(const ValidationIssue('x')),
      throwsUnsupportedError,
    );
  });

  test('a context cannot be edited through the lists it was built from', () {
    final components = [
      const FilingComponent(
        scheme: 'GST',
        authority: 'CRA',
        percent: 5,
        baseCents: 100,
        taxCents: 5,
      ),
    ];
    final line = FilingLine(
      percent: 5,
      netCents: 100,
      vatCents: 5,
      grossCents: 105,
      invoiceCount: 1,
      components: components,
    );
    final lines = [line];
    final context = FilingContext(
      periodStart: DateTime.utc(2026),
      periodEnd: DateTime.utc(2026, 1, 31),
      currency: 'CAD',
      lines: lines,
      generatedAt: DateTime.utc(2026, 2),
      party: const FilingParty(
        countryCode: 'CA',
        name: 'n',
        street: 's',
        postalCode: 'p',
        city: 'c',
        vatId: 'v',
        legalId: 'l',
      ),
    );
    lines.clear();
    components.clear();
    expect(context.lines, hasLength(1));
    expect(context.lines.single.components, hasLength(1));
    expect(() => context.lines.add(line), throwsUnsupportedError);
    expect(
      () => context.lines.single.components.clear(),
      throwsUnsupportedError,
    );
  });

  test('the boxes of a context are read-only too', () {
    final boxes = [
      const FilingBox(code: '08', label: 'x', netCents: 1, vatCents: 2),
    ];
    final context = FilingContext(
      periodStart: DateTime.utc(2026),
      periodEnd: DateTime.utc(2026, 1, 31),
      currency: 'EUR',
      lines: const [],
      boxes: boxes,
      generatedAt: DateTime.utc(2026, 2),
      party: const FilingParty(
        countryCode: 'FR',
        name: 'n',
        street: 's',
        postalCode: 'p',
        city: 'c',
        vatId: 'v',
        legalId: 'l',
      ),
    );
    boxes.clear();
    expect(context.boxes, hasLength(1));
    expect(() => context.boxes.clear(), throwsUnsupportedError);
  });

  test('the extra boxes of a context are read-only too', () {
    final extra = {
      'FPZ-500': [
        const FilingBox(code: '203', label: 'x', netCents: 1, vatCents: 2),
      ],
    };
    final context = FilingContext(
      periodStart: DateTime.utc(2026),
      periodEnd: DateTime.utc(2026, 1, 31),
      currency: 'CAD',
      lines: const [],
      extraBoxes: extra,
      generatedAt: DateTime.utc(2026, 2),
      party: const FilingParty(
        countryCode: 'CA',
        name: 'n',
        street: 's',
        postalCode: 'p',
        city: 'c',
        vatId: 'v',
        legalId: 'l',
      ),
    );
    extra['FPZ-500']!.clear();
    extra.clear();
    expect(context.extraBoxes['FPZ-500'], hasLength(1));
    expect(() => context.extraBoxes['x'] = [], throwsUnsupportedError);
    expect(
      () => context.extraBoxes['FPZ-500']!.clear(),
      throwsUnsupportedError,
    );
  });

  test('the contract is version 3 and the document context is read-only', () {
    expect(jurisdictionContractVersion, '3');
    final context = InvoiceDocumentContext(
      number: 'N-1',
      issuedAt: DateTime.utc(2026, 1, 2),
      currency: 'EUR',
      currencyExponent: 2,
      creditNote: false,
      seller: const DocumentParty(country: 'IT'),
      buyer: const DocumentParty(country: 'IT'),
      lines: [
        const DocumentLine(text: 'x', quantity: 1, grossMinor: 122, vatPercent: 22),
      ],
      vatBreakdown: [
        const DocumentVatTotal(percent: 22, category: 'S', netMinor: 100, vatMinor: 22),
      ],
      payableMinor: 122,
    );
    expect(
      () => context.lines.add(context.lines.first),
      throwsUnsupportedError,
    );
    expect(
      () => context.vatBreakdown.clear(),
      throwsUnsupportedError,
    );
  });
}
