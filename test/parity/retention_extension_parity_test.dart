// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- which countries' spaces may extend their record-retention
// rules with their own `retention.us_years` (only the United States), and what
// that extension does to each rule, pinned BEFORE the country moves behind the
// archive contract. The move must change none of these answers.
import 'package:deskilo/core/vat/retention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a US space may extend its retention rules by setting', () {
    for (final c in ['US', 'us', ' US ', 'Us']) {
      expect(retentionExtendsBySetting(c), isTrue, reason: c);
    }
    for (final c in [
      'DE',
      'FR',
      'GB',
      'CA',
      'IE',
      'CH',
      'AT',
      'ES',
      'IT',
      'PL',
      '',
      'ZZ',
      '*',
    ]) {
      expect(retentionExtendsBySetting(c), isFalse, reason: c);
    }
  });

  test('a US space\'s own period replaces a SHORTER rule, never a longer one; '
      'another country\'s setting changes nothing', () {
    List<(String, int, bool)> rules(String country, int usYears) => [
      for (final r in retentionRules(country, usYears: usYears))
        (r.docClass, r.years, r.bySetting),
    ];
    // no setting: nothing is by setting
    expect(
      rules('US', 0).where((r) => r.$3),
      isEmpty,
      reason: 'no extension without a period',
    );
    // a very long period replaces every rule of a US space
    final long = rules('US', 99);
    expect(long, isNotEmpty);
    expect(long.every((r) => r.$2 == 99 && r.$3), isTrue);
    // a short one replaces none
    expect(rules('US', 1).where((r) => r.$3), isEmpty);
    // the same setting on another country's space changes nothing
    for (final c in ['DE', 'GB', 'CA', 'FR']) {
      expect(rules(c, 99), rules(c, 0), reason: c);
      expect(rules(c, 99).where((r) => r.$3), isEmpty, reason: c);
    }
  });

  test('the boundary: a period equal to a US rule\'s own extends nothing, one '
      'more extends it (> not >=)', () {
    final own = {
      for (final r in retentionRules('US')) r.docClass: r.years,
    };
    expect(own, isNotEmpty);
    for (final e in own.entries) {
      final equal = retentionRules('US', usYears: e.value)
          .firstWhere((r) => r.docClass == e.key);
      expect(equal.bySetting, isFalse, reason: '${e.key}: N = ${e.value}');
      expect(equal.years, e.value);
      final more = retentionRules('US', usYears: e.value + 1)
          .firstWhere((r) => r.docClass == e.key);
      expect(more.bySetting, isTrue, reason: '${e.key}: N + 1');
      expect(more.years, e.value + 1);
    }
  });
}
