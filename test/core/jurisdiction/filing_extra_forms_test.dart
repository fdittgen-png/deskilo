// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the forms filed beside the main return are declared by the add-on
// (`extraForms`) and filled by the host; no country code decides it in the
// host. Only the Canadian add-on declares one (the Quebec FPZ-500); a form the
// host cannot fill is a programming error, not a quiet gap.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/filing_context_builder.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

final _declaration = VatDeclaration(
  id: 'd1',
  workspaceId: 'w1',
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 9, 30),
  status: 'prepared',
  lines: const <VatDeclarationLine>[],
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'CAD',
  invoiceCount: 0,
  createdAt: DateTime(2026, 10),
);

VatFilingParty _party(String country) => VatFilingParty(
  countryCode: country,
  name: 'Espace',
  street: '',
  postalCode: '',
  city: '',
  vatId: '',
  legalId: '',
);

void main() {
  test('only the Canadian add-on declares a form beside the main return', () {
    final declared = {
      for (final c in installedVatFilings)
        c.descriptor.capabilityId: c.extraForms,
    }..removeWhere((_, forms) => forms.isEmpty);
    expect(declared, {
      'vat_filing.CA': {'FPZ-500'},
    });
  });

  test('a declared form is filled by the host and travels in the context', () {
    final context = filingContextOf(
      declaration: _declaration,
      party: _party('XX'),
      now: DateTime.utc(2026, 10, 2),
      facts: const VatFilingFacts(),
      reference: ActiveTaxReference.current,
      extraForms: const {'FPZ-500'},
    );
    expect(context.extraBoxes.keys, ['FPZ-500']);
  });

  test('no declared form, no extra boxes — whatever the country', () {
    final context = filingContextOf(
      declaration: _declaration,
      party: _party('CA'),
      now: DateTime.utc(2026, 10, 2),
      facts: const VatFilingFacts(),
      reference: ActiveTaxReference.current,
    );
    expect(context.extraBoxes, isEmpty);
  });

  test('a form the host cannot fill is a programming error', () {
    expect(
      () => filingContextOf(
        declaration: _declaration,
        party: _party('XX'),
        now: DateTime.utc(2026, 10, 2),
        facts: const VatFilingFacts(),
        reference: ActiveTaxReference.current,
        extraForms: const {'NOPE-1'},
      ),
      throwsStateError,
    );
  });
}
