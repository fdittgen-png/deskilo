// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- the supplier form's country is a lookup, and the save step refuses
// a code outside the catalogue with the field's own error (domain-first), while
// an empty country (the field is optional) and a catalogue code still save.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/presentation/widgets/supplier_save_step.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({String? id, SupplierSaveStep step, int saved, List<String> said})> _try(
  String country,
) async {
  var saved = 0;
  final said = <String>[];
  final step = SupplierSaveStep(
    existing: const [],
    reference: ActiveTaxReference.current,
    onSave: (draft) async {
      saved++;
      return 'new-id';
    },
  );
  final id = await step.submit(
    SupplierDraft(name: 'Atelier Nord', countryCode: country),
    lookupAppLocalizations(const Locale('en')),
    announce: said.add,
  );
  return (id: id, step: step, saved: saved, said: said);
}

void main() {
  test('a code outside the catalogue is refused with the country error', () async {
    final r = await _try('ZZ');
    expect(r.id, isNull);
    expect(r.saved, 0);
    expect(r.step.value.countryError, 'This is not a valid entry. Pick one from the list.');
    expect(r.said, contains(r.step.value.countryError));
  });

  test('a catalogue code, any case, and an empty country save', () async {
    for (final country in ['CH', 'ch', '']) {
      final r = await _try(country);
      expect(r.id, 'new-id', reason: "'$country'");
      expect(r.step.value.countryError, isNull);
    }
  });

  test('fixing the code clears the error on the next edit', () async {
    final r = await _try('ZZ');
    r.step.edited(const SupplierDraft(name: 'Atelier Nord', countryCode: 'CH'));
    expect(r.step.value.countryError, isNull);
  });
}
