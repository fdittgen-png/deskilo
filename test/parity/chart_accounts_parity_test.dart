// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the accounts a DATEV and a FEC export fall back on,
// pinned BEFORE the chart country moves onto the format's registration:
// the German chart (SKR03 default, SKR04) and the French one, per role, per
// rate and per BU-Schluessel, as the tax reference holds them. The golden is
// written by the code as it stands and compared byte for byte; rewrite only
// with `UPDATE_PARITY_GOLDENS=1`, never under CI.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/datev_revenue.dart';
import 'package:deskilo/features/money/domain/fec_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _rates = [0.0, 5.5, 7.0, 10.0, 19.0, 20.0, 21.0];

String _datev(String label, DatevAccounts a) {
  final out = StringBuffer('[$label]\n')
    ..writeln('chart=${a.chart} skr=${a.skr}')
    ..writeln('revenue=${a.revenue} bank=${a.bank} expenses=${a.expenses}')
    ..writeln('writeOff=${a.writeOff}');
  for (final p in _rates) {
    final target = a.revenueTargetAt(p);
    out.writeln(
      'rate $p: revenueAt=${a.revenueAt(p)} target=${target.account}/'
      '${target.taxKey} gap=${a.taxGapAt(p)?.runtimeType}',
    );
  }
  return out.toString();
}

String _fec(String label, FecAccounts a) =>
    '[$label]\ncustomers=${a.customers} revenue=${a.revenue} bank=${a.bank} '
    'vat=${a.vat}\nexpenses=${a.expenses} vatPending=${a.vatPending} '
    'writeOff=${a.writeOff}\n';

void main() {
  test('the chart accounts are what they were before the chart moved', () {
    final reference = ActiveTaxReference.current;
    final text = StringBuffer()
      ..write(_datev('datev default', const DatevAccounts()))
      ..write(_datev('datev SKR04', const DatevAccounts(chart: 'SKR04')))
      ..write(
        _datev('datev skr04 lower case', const DatevAccounts(chart: ' skr04 ')),
      )
      ..write(
        _datev(
          'datev given accounts',
          const DatevAccounts(revenue: '8195', bank: '1800', expenses: '4999'),
        ),
      )
      ..write(
        _datev('datev explicit reference', DatevAccounts(reference: reference)),
      );
    for (final group in ['standard', 'reduced', 'unknown', '']) {
      text.writeln(
        'tax key $group: ${datevGroupTaxKey(reference, group, country: 'DE')} '
        'revenue SKR03=${datevAutomaticRevenue(reference, 'SKR03', group, 'base', country: 'DE')} '
        'SKR04=${datevAutomaticRevenue(reference, 'SKR04', group, 'base', country: 'DE')}',
      );
    }
    text
      ..write(_fec('fec default', const FecAccounts()))
      ..write(
        _fec(
          'fec given',
          const FecAccounts(
            customers: '4110',
            revenue: '7061',
            bank: '5121',
            vat: '445712',
            expenses: '6061',
            vatPending: '445741',
            writeOff: '6541',
          ),
        ),
      )
      ..write(
        _fec('fec explicit reference', FecAccounts(reference: reference)),
      );
    expectParity(
      dir: 'test/parity/golden/chart_accounts',
      text: {'accounts.txt': text.toString()},
    );
  });
}
