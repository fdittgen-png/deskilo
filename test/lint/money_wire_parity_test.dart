// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — the Edge money boundary (`supabase/functions/_shared/money.ts`)
// is the TypeScript side of `accounting_amount.dart`. Two languages, one
// rule: the reviewed currency tables, the exact range and the wire form's
// keys are pinned to the Dart source, so the two cannot drift apart within
// a release the way the #1137 webhooks once did.
import 'dart:io';

import 'package:deskilo/core/i18n/currencies.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:flutter_test/flutter_test.dart';

final _ts = File('supabase/functions/_shared/money.ts').readAsStringSync();

/// The codes inside `const NAME = new Set([...])`.
Set<String> _tsSet(String name) {
  final m = RegExp(
    '$name = new Set\\(\\[([^\\]]*)\\]\\)',
    dotAll: true,
  ).firstMatch(_ts);
  expect(m, isNotNull, reason: '$name is defined in money.ts');
  return RegExp(r'"([A-Z]{3})"')
      .allMatches(m!.group(1)!)
      .map((x) => x.group(1)!)
      .toSet();
}

void main() {
  test('the TypeScript currency tables are the Dart ones', () {
    expect(_tsSet('ZERO_DECIMAL'), Currencies.zeroDecimal);
    expect(_tsSet('THREE_DECIMAL'), Currencies.threeDecimal);
    final twoDecimal = Currencies.selectable
        .where((c) => Currencies.minorDigits(c) == 2)
        .toSet();
    expect(_tsSet('TWO_DECIMAL'), twoDecimal);
    // Every reviewed currency, and only those, has a TypeScript exponent.
    expect({
      ..._tsSet('ZERO_DECIMAL'),
      ..._tsSet('THREE_DECIMAL'),
      ..._tsSet('TWO_DECIMAL'),
    }, supportedCurrencies);
  });

  test('the exact range is the same number on both sides', () {
    expect(_ts, contains('MAX_SAFE_MINOR = ${maxSafeMinor}n'));
  });

  test('the wire form carries the same keys, minor units as a string', () {
    final wire = AccountingAmount('EUR', 114975).toJson();
    expect(wire.keys.toSet(), {'currency', 'exponent', 'minor'});
    expect(wire['minor'], isA<String>());
    final iface = RegExp(
      r'interface AccountingAmountWire \{([^}]*)\}',
      dotAll: true,
    ).firstMatch(_ts);
    expect(iface, isNotNull);
    final fields = RegExp(r'(\w+): (\w+);')
        .allMatches(iface!.group(1)!)
        .map((m) => '${m.group(1)}:${m.group(2)}')
        .toSet();
    expect(fields, {'currency:string', 'exponent:number', 'minor:string'});
  });

  test('no float reaches an amount in money.ts', () {
    final code = _ts
        .split('\n')
        .where(
          (l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('*'),
        )
        .join('\n');
    for (final forbidden in [
      'parseFloat',
      'Number(major',
      'toFixed',
      '* 100',
      '/ 10 **',
    ]) {
      expect(code, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(code, contains('BigInt('));
  });
}
