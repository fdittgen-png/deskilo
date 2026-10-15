// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in template_contract_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';

import 'configuration_classification.dart' show deployableEntityKeys;

/// What a template is checked against. Built from the real registries in
/// [TemplateContractRules.live]; the red proofs pass their own.
class TemplateContractRules {
  const TemplateContractRules({
    required this.features,
    required this.requires,
    required this.entities,
    required this.lexiconPlaceholders,
  });

  final Set<String> features;

  /// Feature name → its parent's name.
  final Map<String, String> requires;
  final Set<String> entities;

  /// Allowed lexicon key → the `{tokens}` an override must keep.
  final Map<String, List<String>> lexiconPlaceholders;

  factory TemplateContractRules.live() => TemplateContractRules(
    features: {for (final f in WorkspaceFeature.values) f.name},
    requires: {
      for (final e in featureManifest.entries)
        if (e.value.requires != null) e.key.name: e.value.requires!.name,
    },
    entities: deployableEntityKeys(),
    lexiconPlaceholders: {
      for (final e in lexiconAllowList.entries) e.key: e.value.placeholders,
    },
  );
}

/// Entities the publication allow-list denies (0229); a builtin is
/// published by definition.
const denied = {
  'sites',
  'payment_instructions',
  'invitations',
  'document_links',
  'document_design',
};

/// Workspace keys the identity entity strips (0229).
const strippedIdentityKeys = {
  'address',
  'street',
  'postal_code',
  'city',
  'vat_id',
  'legal_id',
  'tax_exemption_reason',
  'vat_account',
  'invoice_legal',
  'whatsapp_group',
};

/// Every way [template] breaks the contract, each naming the template and
/// the offending value.
List<String> checkTemplate(
  Map<String, dynamic> template,
  TemplateContractRules rules,
) {
  final key = '${template['key']}';
  final out = <String>[];
  void fail(String what) => out.add('$key: $what');

  if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(key)) {
    fail('key "$key" is not lower-case letters, digits and underscores');
  }

  final entities = [for (final e in template['entities'] as List? ?? []) '$e'];
  for (final e in entities) {
    if (!rules.entities.contains(e)) fail('entity "$e" is not deployable');
    if (denied.contains(e)) fail('entity "$e" is never published');
  }

  final config = (template['configuration'] as Map?) ?? const {};
  final ws = Map<String, dynamic>.from(config['workspace'] as Map? ?? {});
  final tables = Map<String, dynamic>.from(config['tables'] as Map? ?? {});
  if (ws.containsKey('payment_instructions')) {
    fail('carries payment_instructions');
  }
  for (final k in strippedIdentityKeys) {
    if (ws.containsKey(k)) fail('carries the source\'s own "$k"');
  }
  for (final t in denied) {
    if (tables.containsKey(t)) fail('carries table "$t"');
  }

  // ── holidays marker (0234): resolved per target, never dates ──
  final holidays = config['holidays'];
  if (holidays != null) {
    final years = holidays is Map ? holidays['years'] : null;
    final country = holidays is Map ? holidays['country'] : null;
    if (years is! int || years < 1 || years > 3) {
      fail('holidays marker years $years is not 1..3');
    }
    if (country != null && !RegExp(r'^[A-Z]{2}$').hasMatch('$country')) {
      fail('holidays marker country "$country" is not an ISO code');
    }
    if (!entities.contains('closure_days')) {
      fail('holidays marker without the closure_days entity is never applied');
    }
  }

  // ── features ──
  final flags = ws['feature_flags'];
  if (flags is Map) {
    final on = <String>{};
    for (final e in flags.entries) {
      final name = '${e.key}';
      if (!rules.features.contains(name)) {
        fail('feature "$name" does not exist');
      } else if (e.value == true) {
        on.add(name);
      }
    }
    for (final f in rules.features) {
      if (!flags.containsKey(f)) fail('feature "$f" is not written explicitly');
    }
    for (final f in on) {
      final parent = rules.requires[f];
      if (parent != null && !on.contains(parent)) {
        fail('feature "$f" is on but its parent "$parent" is off');
      }
    }
  }

  // ── hours ──
  final rules0 = ws['booking_rules'];
  if (rules0 is Map) {
    final g = rules0['granularity'];
    if (g != null && !BookingGranularity.values.any((v) => v.wireName == g)) {
      fail('granularity "$g" is unknown');
    }
    final start = rules0['work_start_minutes'];
    final half = rules0['half_boundary_minutes'];
    final end = rules0['work_end_minutes'];
    if (start is int &&
        half is int &&
        end is int &&
        !(start < half && half < end && end <= 1440)) {
      fail('working hours $start / $half / $end are not in order');
    }
    final days = rules0['open_weekdays'];
    if (days is List && days.any((d) => d is! int || d < 1 || d > 7)) {
      fail('open_weekdays $days are not within 1..7');
    }
  }

  // ── prices ──
  void nonNegative(String where, Object? v) {
    if (v != null && (v is! int || v < 0)) {
      fail('$where price $v is not a non-negative integer');
    }
  }

  final bands = [
    for (final b in tables['fee_bands'] as List? ?? const [])
      Map<String, dynamic>.from(b as Map),
  ]..sort((a, b) => (a['from_pct'] as int).compareTo(b['from_pct'] as int));
  for (var i = 0; i < bands.length; i++) {
    nonNegative('fee band', bands[i]['fee_cents']);
    if (i > 0 &&
        (bands[i]['from_pct'] as int) < (bands[i - 1]['to_pct'] as int)) {
      fail(
        'fee bands ${bands[i - 1]['from_pct']}–${bands[i - 1]['to_pct']} '
        'and ${bands[i]['from_pct']}–${bands[i]['to_pct']} overlap',
      );
    }
  }
  final levels = ws['subscription_levels'];
  if (levels is Map && bands.isNotEmpty) {
    for (final pct in [
      ...?(levels['enabled_presets'] as List?),
      ...?(levels['extra_levels'] as List?),
    ]) {
      final covered = bands.any(
        (b) =>
            (b['from_pct'] as int) < (pct as int) &&
            pct <= (b['to_pct'] as int),
      );
      if (!covered) fail('subscription level $pct % falls in no fee band');
    }
  }
  for (final t in [
    'packages',
    'services',
    'plans',
    'accessories',
    'credit_products',
  ]) {
    for (final row in tables[t] as List? ?? const []) {
      final r = row as Map;
      for (final f in ['price_cents', 'base_fee_cents', 'supplement_cents']) {
        nonNegative('$t "${r['name']}" $f', r[f]);
      }
    }
  }
  void planPrices(Object? node, String path) {
    if (node is List) {
      for (final n in node) {
        planPrices(n, path);
      }
    } else if (node is Map) {
      final here = '$path/${node['name'] ?? ''}';
      nonNegative('plan $here', node['price_cents']);
      for (final child in ['offices', 'desks', 'seats']) {
        planPrices(node[child], here);
      }
    }
  }

  planPrices(template['floor_plan'], '');

  // ── VAT labels ──
  final vatLabels = {
    for (final r in tables['vat_rates'] as List? ?? const [])
      '${(r as Map)['label']}',
  };
  for (final t in ['packages', 'services', 'accessories', 'credit_products']) {
    for (final row in tables[t] as List? ?? const []) {
      final label = (row as Map)['vat_rate'];
      if (label != null && !vatLabels.contains('$label')) {
        fail(
          '$t "${row['name']}" names VAT rate "$label", which the template lacks',
        );
      }
    }
  }
  final subVat = ws['subscription_vat_rate'];
  if (subVat != null && !vatLabels.contains('$subVat')) {
    fail('subscription VAT rate "$subVat" is not in the template');
  }

  // ── lexicon ──
  final lexicon = ws['lexicon'];
  if (lexicon is Map) {
    for (final locale in lexicon.entries) {
      for (final term in (locale.value as Map).entries) {
        final termKey = '${term.key}';
        final allowed = rules.lexiconPlaceholders[termKey];
        if (allowed == null) {
          fail('lexicon "$termKey" (${locale.key}) is not overridable');
          continue;
        }
        final tokens = RegExp(r'\{(\w+)\}')
            .allMatches('${term.value}')
            .map((m) => m.group(1)!)
            .toSet();
        if (!tokens.containsAll(allowed) ||
            !allowed.toSet().containsAll(tokens)) {
          fail(
            'lexicon "$termKey" (${locale.key}) must carry exactly '
            '${allowed.map((t) => '{$t}').join(', ')}',
          );
        }
      }
    }
  }
  return out;
}
