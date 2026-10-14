// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2481 (C5 of #2476) -- the suggested charts of accounts and the exporters'
// account defaults come from the tax reference store (`account_map` rows).
// `golden/coa_golden.json` was captured from the Dart constants BEFORE they
// were deleted: every chart of every country under every regime, and the
// defaults of the FEC, DATEV and Sage exporters. The store reproduces it.
//
// Run with GOLDEN_UPDATE=1 only to capture a deliberate change.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/coa_preview.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = 'test/features/money/golden/coa_golden.json';

Map<String, Object?> _capture() {
  final out = <String, Object?>{};
  for (final c in [
    'FR',
    'DE',
    'AT',
    'ES',
    'IT',
    'BE',
    'LU',
    'NL',
    'PT',
    'CH',
    'GB',
    'XX',
    'fr',
    'us',
  ]) {
    for (final r in VatRegime.values) {
      final chart = coaChartFor(
        countryCode: c,
        regime: r,
        noteFor: (role) => 'note:${role.name}',
      );
      out['$c|${r.name}'] = {
        'code': chart.code,
        'name': chart.name,
        'accounts': [
          for (final a in chart.accounts)
            [a.role.name, a.number, a.label, a.note],
        ],
      };
    }
  }
  const fec = FecAccounts();
  const datev = DatevAccounts();
  const sage = SageAccounts();
  out['defaults'] = {
    'fec': [
      fec.customers,
      fec.revenue,
      fec.bank,
      fec.vat,
      fec.expenses,
      fec.vatPending,
    ],
    'datev': [
      datev.customers,
      datev.revenue,
      datev.bank,
      datev.vat,
      datev.chart,
      datev.expenses,
    ],
    'sage': [sage.debtors, sage.sales, sage.bank, sage.taxCode],
    'sageCodes': [
      SageAccounts.zeroRatedCode,
      SageAccounts.exemptCode,
      SageAccounts.reducedCode,
      SageAccounts.noTaxCode,
    ],
  };
  return out;
}

void main() {
  test('every chart and every exporter default is what the constants said', () {
    final got = _capture();
    if (Platform.environment['GOLDEN_UPDATE'] == '1') {
      File(_path).writeAsStringSync(
        '{\n'
        '${got.entries.map((e) => '${jsonEncode(e.key)}:${jsonEncode(e.value)}').join(',\n')}'
        '\n}\n',
      );
      return;
    }
    final expected =
        jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>;
    expect(got.keys.toSet(), expected.keys.toSet());
    for (final k in expected.keys) {
      expect(jsonDecode(jsonEncode(got[k])), expected[k], reason: k);
    }
  });

  group('the data decides, the code does not', () {
    TaxReferenceSet changed(
      String country,
      String key,
      AccountMapValue value,
    ) => TaxReferenceSet([
      for (final r in ActiveTaxReference.current.rows)
        if (!(r.domain == TaxDomain.accountMap &&
            r.country == country &&
            r.key == key))
          r,
      TaxReferenceRow(
        country: country,
        key: key,
        validFrom: '1900-01-01',
        value: value,
        source: 'test',
        confirmed: true,
      ),
    ]);

    test(
      'an export code edited in the store is the next export\'s default',
      () {
        final ref = changed(
          'FR',
          'coa/04-vat',
          const AccountMapValue(
            format: 'coa',
            role: 'vat',
            account: '445711',
            label: 'TVA',
          ),
        );
        expect(FecAccounts(reference: ref).vat, '445711');
        expect(
          const FecAccounts().vat,
          '445710',
          reason: 'the installed snapshot is not touched',
        );
        final sage = changed(
          'GB',
          'sage/tax_standard',
          const AccountMapValue(
            format: 'sage',
            role: 'tax_standard',
            taxCode: 'T20',
          ),
        );
        expect(SageAccounts(reference: sage).taxCode, 'T20');
      },
    );

    test(
      'an account the accountant gave wins over any row, and over a change',
      () {
        final ref = changed(
          'FR',
          'coa/04-vat',
          const AccountMapValue(format: 'coa', role: 'vat', account: '445711'),
        );
        expect(FecAccounts(vat: '445712', reference: ref).vat, '445712');
      },
    );

    test(
      'a chart follows its rows; a country with none reads the shared chart',
      () {
        final ref = changed(
          'FR',
          'coa/03-bank',
          const AccountMapValue(
            format: 'coa',
            role: 'bank',
            account: '512100',
            label: 'Banque',
          ),
        );
        final chart = coaChartFor(
          countryCode: 'FR',
          regime: VatRegime.vatRegistered,
          noteFor: (_) => '',
          reference: ref,
        );
        expect(chart.numberFor(CoaAccountRole.bank), '512100');
        expect(
          coaChartFor(
            countryCode: 'ZZ',
            regime: VatRegime.exempt,
            noteFor: (_) => '',
          ).code,
          'GEN',
        );
      },
    );

    test('a missing row is a typed failure, not a blank account', () {
      expect(
        () => const FecAccounts(reference: TaxReferenceSet([])).customers,
        throwsA(isA<TaxReferenceUnavailable>()),
      );
    });
  });
}
