// SPDX-License-Identifier: 0BSD
//
// #875 — an ABSENT placeholder must be empty, not nil.
//
// Liquid resolves an unknown name to nil, and `nil != ""` is TRUE. So
// `{% if iban != "" %}IBAN : {{ iban }}{% endif %}` — a guard that is
// written correctly — printed "IBAN :" with nothing after it on a real
// invoice, because that build's data map had no `iban` at all. The
// design was right, the engine drew the wrong conclusion, and the
// document went out with three bare labels on it.
//
// The seeding also has to respect TYPE: '' is truthy in Liquid, so a
// flag seeded as '' would make `{% if proforma %}` fire on every
// invoice.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:flutter_test/flutter_test.dart';

List<ReportBlock> _body(String source, [Map<String, Object?> data = const {}]) =>
    renderReportBands(bands: ReportBands(body: source), data: data)!.body;

void main() {
  test('a guarded band with the placeholder ABSENT prints nothing', () {
    // The exact shape that shipped a bare "IBAN :" to a member.
    expect(
      _body('{% if iban != "" %}IBAN : {{ iban }}{% endif %}'),
      isEmpty,
      reason: 'an absent placeholder still satisfies != ""',
    );
    for (final key in ['bic', 'bank_name', 'account_holder', 'escompte']) {
      expect(_body('{% if $key != "" %}$key : {{ $key }}{% endif %}'),
          isEmpty,
          reason: key);
    }
  });

  test('a supplied placeholder still prints', () {
    final blocks = _body(
      '{% if iban != "" %}IBAN : {{ iban }}{% endif %}',
      {'iban': 'FR76 1027'},
    );
    expect(blocks, hasLength(1));
    expect((blocks.single as ReportText).text, 'IBAN : FR76 1027');
  });

  test('flags are seeded FALSE, because the empty string is truthy here',
      () {
    // Seeded as '' this renders the proforma branch on every document.
    expect((_body('{% if proforma %}PROFORMA{% else %}FACTURE{% endif %}')
            .single as ReportText)
        .text, 'FACTURE');
    for (final flag in ['voided', 'copy', 'has_vat', 'credit_note']) {
      expect(_body('{% if $flag %}yes{% endif %}'), isEmpty, reason: flag);
    }
  });

  test('lists are seeded empty, so a loop over an absent list is a no-op',
      () {
    expect(_body('{% for line in lines %}{{ line.label }}\n{% endfor %}'),
        isEmpty);
  });

  test('every declared placeholder has a default of the right shape', () {
    final defaults = InvoicePdfTemplate.placeholderDefaults;
    expect(defaults.keys.toSet(),
        InvoicePdfTemplate.placeholders.toSet(),
        reason: 'a placeholder without a default is one that can be nil');
    for (final entry in defaults.entries) {
      expect(entry.value, anyOf(isA<String>(), isA<bool>(), isA<List>()),
          reason: entry.key);
    }
  });

  test('the caller always wins over the seed', () {
    expect(
      (_body('{{ workspace }}', {'workspace': 'COWORKONTI'}).single
              as ReportText)
          .text,
      'COWORKONTI',
    );
  });
}
