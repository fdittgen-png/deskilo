// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 (3b) -- the space's own region follows the rule of every address
// editor: stored as its code, refused when its country has no such region or
// needs one, and an identity stored before keeps saving until its region is
// edited.
import 'package:deskilo/features/money/presentation/widgets/einvoice_identity_fields.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test(
    'a region the country lacks is refused, one it has is stored as its code',
    () {
      final form = EInvoiceIdentityForm()..load(const InvoiceLegal());
      addTearDown(form.dispose);
      form.subdivision.text = 'ZZ';
      expect(form.regionAccepted('US', l10n), isFalse);
      expect(
        form.regionError.value,
        'This country has no region with this code.',
      );
      form.subdivision.text = ' ny ';
      expect(form.regionAccepted('US', l10n), isTrue);
      expect(form.regionError.value, isNull);
      expect(form.applyTo(const InvoiceLegal()).subdivision, 'NY');
    },
  );

  test(
    'an identity stored without its state keeps saving until it is edited',
    () {
      final form = EInvoiceIdentityForm()..load(const InvoiceLegal());
      addTearDown(form.dispose);
      expect(form.regionAccepted('US', l10n), isTrue);
    },
  );
}
