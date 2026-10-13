// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — a Swiss workspace lets a package (taxed) or bare rooms (exempt,
// art. 21 Ziff. 21 MWSTG, unless the option of art. 22 is in force). The
// choice is stored with the legal identity (the server reads it in
// `workspace_taxes_land`, pgTAP 178); this file pins the stored shape and
// the fields that edit it.
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/presentation/widgets/swiss_letting_fields.dart';
import 'package:deskilo/features/money/presentation/widgets/uk_land_taxation_fields.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the letting kind round-trips; a package stores nothing', () {
    expect(const InvoiceLegal().toJson().containsKey('letting_kind'), isFalse);
    final legal = InvoiceLegal.fromJson({
      'letting_kind': 'bare',
      'option_to_tax': true,
      'option_to_tax_date': '2028-01-01',
    });
    expect(legal.lettingKind, 'bare');
    expect(InvoiceLegal.fromJson(legal.toJson()), legal);
    expect(
      legal
          .withEInvoiceAddress(
            endpointId: '',
            endpointScheme: '',
            subdivision: '',
            contactEmail: '',
            contactPhone: '',
          )
          .lettingKind,
      'bare',
    );
  });

  testWidgets('the option appears once the owner lets bare rooms', (
    tester,
  ) async {
    final form = UkLandTaxationForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: SwissLettingFields(form: form)),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('legal-identity-option-to-tax')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('legal-identity-bare-letting')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('legal-identity-option-to-tax')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-option-date')),
      '2028-01-01',
    );
    final saved = form.applyTo(const InvoiceLegal());
    expect(saved.lettingKind, 'bare');
    expect(saved.optionToTax, isTrue);
    expect(saved.optionToTaxDate, '2028-01-01');
  });
}
