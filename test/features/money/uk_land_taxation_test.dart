// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2359 — the United Kingdom treats land as exempt unless the owner opted
// to tax the building. The choice is stored with the legal identity (the
// server reads it in `workspace_taxes_land`, pgTAP 175); this file pins the
// stored shape and the settings fields that edit it.
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/presentation/widgets/uk_land_taxation_fields.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the choice round-trips, and an untouched identity stores nothing', () {
    expect(const InvoiceLegal().toJson().containsKey('option_to_tax'), isFalse);
    final legal = InvoiceLegal.fromJson({
      'option_to_tax': true,
      'option_to_tax_date': '2020-01-01',
      'option_to_tax_reference': 'HMRC/123',
      'facilities_package': false,
    });
    expect(legal.optionToTax, isTrue);
    expect(legal.optionToTaxDate, '2020-01-01');
    expect(legal.toJson()['option_to_tax_reference'], 'HMRC/123');
    expect(InvoiceLegal.fromJson(legal.toJson()), legal);
    // The e-invoicing edit keeps it.
    expect(
      legal
          .withEInvoiceAddress(
            endpointId: 'x',
            endpointScheme: 'y',
            subdivision: '',
            contactEmail: '',
            contactPhone: '',
          )
          .optionToTax,
      isTrue,
    );
    // Without the option, its date and reference are not kept.
    final package = const InvoiceLegal().withLandTaxation(
      optionToTax: false,
      optionToTaxDate: '2020-01-01',
      optionToTaxReference: 'HMRC/123',
      facilitiesPackage: true,
    );
    expect(package.toJson()['option_to_tax_date'], '');
    expect(package.toJson()['facilities_package'], isTrue);
  });

  testWidgets('the date and the reference appear once the owner opted', (
    tester,
  ) async {
    final form = UkLandTaxationForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: UkLandTaxationFields(form: form)),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('legal-identity-option-date')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('legal-identity-option-to-tax')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-option-date')),
      '2021-04-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-option-reference')),
      'HMRC/9',
    );
    final saved = form.applyTo(const InvoiceLegal());
    expect(saved.optionToTax, isTrue);
    expect(saved.optionToTaxDate, '2021-04-01');
    expect(saved.optionToTaxReference, 'HMRC/9');
    await tester.tap(
      find.byKey(const ValueKey('legal-identity-facilities-package')),
    );
    await tester.pump();
    expect(form.applyTo(const InvoiceLegal()).facilitiesPackage, isTrue);
  });
}
