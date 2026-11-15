// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4028 — the refusals an import or a template apply answers, read from the
// server's words, and the Demo's copy of the server's fence.
import 'package:deskilo/core/demo/data/demo_configuration_fence.dart';
import 'package:deskilo/features/workspace/domain/configuration_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the refused list is read from the answer; an unknown code is not a reason',
    () {
      final all = ConfigurationRefusal.listFrom({
        'refused': [
          {
            'entity': 'tariffs',
            'code': 'currency',
            'source': 'EUR',
            'target': 'GBP',
          },
          {
            'entity': 'services',
            'code': 'currency',
            'source': 'EUR',
            'target': 'GBP',
          },
          {'entity': 'vat', 'code': 'country', 'source': 'FR', 'target': 'GB'},
          {'entity': 'x', 'code': 'weather'},
        ],
      });
      expect(all.map((r) => r.entity), ['tariffs', 'services', 'vat']);
      expect(ConfigurationRefusal.perReason(all).map((r) => r.code), [
        ConfigurationRefusalCode.currency,
        ConfigurationRefusalCode.country,
      ]);
      expect(
        ConfigurationRefusal.listFrom({'workspace': <String, Object?>{}}),
        isEmpty,
      );
      expect(ConfigurationRefusal.listFrom(null), isEmpty);
    },
  );

  group('the Demo fences as the server does', () {
    final file = <String, Object?>{
      'workspace': {
        'currency_code': 'EUR',
        'country_code': 'FR',
        'booking_rules': {'granularity': 'half_day'},
      },
      'tables': {
        'fee_bands': [
          {'fee_cents': 500},
        ],
        'services': <Object?>[],
        'vat_rates': [
          {'label': 'TVA 20 %'},
        ],
        'validation_policies': [
          {'event_type': 'lease_change', 'min_amount_cents': 50000},
        ],
      },
    };

    test(
      'another currency and country: prices, threshold and rates stay out',
      () {
        final r = fenceDemoConfiguration(file, currency: 'GBP', country: 'GB');
        expect(r.refused.map((x) => x.entity), [
          'tariffs',
          'vat',
          'validation_rules',
        ], reason: 'an empty table is not named');
        final tables = r.configuration['tables']! as Map;
        expect(tables.containsKey('fee_bands'), isFalse);
        expect(tables.containsKey('vat_rates'), isFalse);
        expect((tables['validation_policies']! as List).single, {
          'event_type': 'lease_change',
        });
        final ws = r.configuration['workspace']! as Map;
        expect(ws['booking_rules'], {
          'granularity': 'half_day',
        }, reason: 'the rest is applied');
        expect(
          ws.containsKey('currency_code'),
          isFalse,
          reason: 'a fact, never written',
        );
      },
    );

    test('the same currency in another country: only the rates', () {
      final r = fenceDemoConfiguration(file, currency: 'EUR', country: 'IT');
      expect(r.refused.map((x) => x.entity), ['vat']);
      expect(
        (r.configuration['tables']! as Map).containsKey('fee_bands'),
        isTrue,
      );
    });

    test('a file that states neither is taken whole', () {
      final r = fenceDemoConfiguration(
        {'tables': file['tables']},
        currency: 'GBP',
        country: 'GB',
      );
      expect(r.refused, isEmpty);
      expect(
        (r.configuration['tables']! as Map).containsKey('fee_bands'),
        isTrue,
      );
    });
  });
}
