// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4028 — the Demo's copy of the server's fence (0779,
// `configuration_source_fence`): a configuration that states another
// currency than the business's leaves its priced entities out and the
// business keeps its validation threshold; one that states another
// country leaves its tax rates out. The Demo has no server, so its
// in-memory import applies the same rule and answers the same refusals.

import 'package:deskilo/features/workspace/domain/configuration_refusal.dart';

/// The priced entities (those that require `vat` in `deployable_entities`)
/// and what each carries: its tables and its business-level keys.
const Map<String, ({List<String> tables, List<String> keys})> _priced = {
  'tariffs': (
    tables: ['fee_bands'],
    keys: ['subscription_levels', 'billing_rules'],
  ),
  'services': (tables: ['services'], keys: []),
  'packages': (tables: ['packages'], keys: []),
  'accessories': (tables: ['accessories'], keys: []),
  'credit_products': (tables: ['credit_products'], keys: []),
};
const _vat = (tables: ['vat_rates'], keys: ['subscription_vat_rate']);

bool _holds(Object? v) =>
    v != null &&
    v != '' &&
    !(v is List && v.isEmpty) &&
    !(v is Map && v.isEmpty);

/// [configuration] as a business counting in [currency] in [country]
/// takes it, and what it left out. A configuration that states neither
/// is taken whole.
({Map<String, Object?> configuration, List<ConfigurationRefusal> refused})
fenceDemoConfiguration(
  Map<String, Object?> configuration, {
  required String currency,
  required String country,
}) {
  final ws = Map<String, Object?>.of(
    (configuration['workspace'] as Map?)?.cast<String, Object?>() ?? const {},
  );
  final tables = Map<String, Object?>.of(
    (configuration['tables'] as Map?)?.cast<String, Object?>() ?? const {},
  );
  String? stated(String key) {
    final v = '${ws[key] ?? ''}'.trim().toUpperCase();
    return v.isEmpty ? null : v;
  }

  final sourceCurrency = stated('currency_code');
  final sourceCountry = stated('country_code');
  final otherCurrency =
      sourceCurrency != null && sourceCurrency != currency.toUpperCase();
  final otherCountry =
      sourceCountry != null && sourceCountry != country.toUpperCase();
  final refused = <ConfigurationRefusal>[];

  bool leaveOut(({List<String> tables, List<String> keys}) entity) {
    var held = false;
    for (final t in entity.tables) {
      held = _holds(tables.remove(t)) || held;
    }
    for (final k in entity.keys) {
      held = _holds(ws.remove(k)) || held;
    }
    return held;
  }

  if (otherCurrency) {
    for (final MapEntry(:key, :value) in _priced.entries) {
      if (leaveOut(value)) {
        refused.add(
          ConfigurationRefusal(
            entity: key,
            code: ConfigurationRefusalCode.currency,
            source: sourceCurrency,
            target: currency.toUpperCase(),
          ),
        );
      }
    }
  }
  if (otherCountry && leaveOut(_vat)) {
    refused.add(
      ConfigurationRefusal(
        entity: 'vat',
        code: ConfigurationRefusalCode.country,
        source: sourceCountry,
        target: country.toUpperCase(),
      ),
    );
  }
  final policies = tables['validation_policies'];
  if (otherCurrency &&
      policies is List &&
      policies.any((p) => p is Map && p.containsKey('min_amount_cents'))) {
    tables['validation_policies'] = [
      for (final p in policies)
        if (p is Map)
          (Map<String, Object?>.of(p.cast<String, Object?>())
            ..remove('min_amount_cents'))
        else
          p,
    ];
    refused.add(
      ConfigurationRefusal(
        entity: 'validation_rules',
        code: ConfigurationRefusalCode.currency,
        source: sourceCurrency,
        target: currency.toUpperCase(),
      ),
    );
  }
  ws
    ..remove('currency_code')
    ..remove('country_code');
  return (
    configuration: {...configuration, 'workspace': ws, 'tables': tables},
    refused: refused,
  );
}
