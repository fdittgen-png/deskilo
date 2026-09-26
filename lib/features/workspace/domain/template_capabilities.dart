// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — finding templates by what they DO, not by the words they use.
//
// A capability is a stable id (`feature.carnets`, `policy.multi_approval`,
// `model.pay_as_you_go`) with the template fields that evidence it and a
// rule that reads those fields out of the #1655 inspection. Search maps the
// person's words onto capabilities through a vocabulary (labels in five
// languages, curated synonyms, the ids themselves) and then asks each
// template's INSPECTED configuration — a template whose description says
// "approval" but whose policies ask for one validator does not match "two
// approvals".
//
// Pure Dart: the catalog, the evaluator, the ranking and the comparison
// rows are argued with in unit tests, and the gallery, the comparison
// screen and the XLSX export (#1660/#1661) consume the same results.
import 'template_inspection.dart';
import 'template_preview.dart';
import 'workspace_feature.dart';

/// What a template's configuration says about one capability.
enum CapabilityState {
  /// Configured, and on.
  enabled,

  /// Configured, and explicitly off.
  disabled,

  /// On, but held back by a dependency that is off, or on only by a
  /// default the target decides.
  conditional,

  /// The template says nothing: the target's own value stays.
  unspecified,

  /// Present, but a value must be supplied locally before it works.
  localInputRequired,

  /// The template cannot be applied here at all.
  incompatible,

  /// The inspection could not say.
  unknown;

  /// Only [enabled] satisfies a requirement; nothing else is promoted.
  bool get satisfies => this == CapabilityState.enabled;
}

/// Why a template got the state it did: the field that decided it.
class CapabilityEvidence {
  const CapabilityEvidence(this.state, {this.path, this.value});
  final CapabilityState state;
  final String? path;
  final Object? value;
}

/// One capability: its id, the process it belongs to and its rule.
class TemplateCapability {
  const TemplateCapability({
    required this.id,
    required this.evaluate,
    this.synonyms = const {},
  });

  /// Stable: `feature.<flag>`, `policy.*`, `model.*`, `setting.*`.
  final String id;

  /// Curated words people search with, per locale, beyond the label.
  final Map<String, List<String>> synonyms;

  final CapabilityEvidence Function(TemplateFacts facts) evaluate;
}

/// The inspection's fields, indexed for the rules.
class TemplateFacts {
  TemplateFacts(this.inspection)
      : _byId = {
          for (final f in inspection.fields) ...{f.id: []},
        } {
    for (final f in inspection.fields) {
      _byId[f.id]!.add(f);
    }
    _inputs = {for (final r in inspection.requiredInputs) r.id};
  }

  final TemplateInspection inspection;
  final Map<String, List<TemplateFieldRecord>> _byId;
  late final Set<String> _inputs;

  List<TemplateFieldRecord> field(String id) => _byId[id] ?? const [];

  TemplateFieldRecord? first(String id) => field(id).firstOrNull;

  bool needsInput(String id) => _inputs.contains(id);

  bool get unusable =>
      inspection.status == TemplateInspectionStatus.rejected ||
      inspection.status == TemplateInspectionStatus.unsupportedVersion ||
      inspection.compatibility == TemplateCompatibility.notSupported;

  bool get unreadable => inspection.status == TemplateInspectionStatus.unknown;
}

String featureFieldId(WorkspaceFeature f) => 'workspace.feature_flags.${f.name}';

/// A feature flag's state in a template: the explicit value, its parent
/// chain (a child on under a parent off is conditional), and absence
/// meaning "the target's own value", never false.
CapabilityEvidence featureState(TemplateFacts facts, WorkspaceFeature feature) {
  if (facts.unusable) return const CapabilityEvidence(CapabilityState.incompatible);
  if (facts.unreadable) return const CapabilityEvidence(CapabilityState.unknown);
  final id = featureFieldId(feature);
  final record = facts.first(id);
  if (record == null || record.disposition == TemplateFieldDisposition.absent) {
    return CapabilityEvidence(CapabilityState.unspecified, path: id);
  }
  if (record.disposition != TemplateFieldDisposition.present || record.value is! bool) {
    return CapabilityEvidence(CapabilityState.unknown, path: record.path);
  }
  if (record.value == false) {
    return CapabilityEvidence(CapabilityState.disabled, path: record.path, value: false);
  }
  final parent = featureManifest[feature]?.requires;
  if (parent != null) {
    final up = featureState(facts, parent);
    if (up.state == CapabilityState.disabled ||
        up.state == CapabilityState.conditional) {
      return CapabilityEvidence(CapabilityState.conditional,
          path: up.path ?? featureFieldId(parent), value: false);
    }
  }
  return CapabilityEvidence(CapabilityState.enabled, path: record.path, value: true);
}

CapabilityEvidence _guard(TemplateFacts facts, CapabilityEvidence Function() rule) {
  if (facts.unusable) return const CapabilityEvidence(CapabilityState.incompatible);
  if (facts.unreadable) return const CapabilityEvidence(CapabilityState.unknown);
  return rule();
}

/// Validation rows asking for at least two distinct validators.
CapabilityEvidence _multiApproval(TemplateFacts facts, {Set<String>? eventTypes}) =>
    _guard(facts, () {
      final counts = facts.field('tables.validation_policies[].required_count');
      final types = facts.field('tables.validation_policies[].event_type');
      if (counts.isEmpty) {
        return const CapabilityEvidence(CapabilityState.unspecified,
            path: 'tables.validation_policies[]');
      }
      bool inScope(TemplateFieldRecord count) {
        if (eventTypes == null) return true;
        final row = count.path.substring(0, count.path.lastIndexOf('.'));
        final type = types.where((t) => t.path.startsWith(row)).firstOrNull?.value;
        return eventTypes.contains(type);
      }
      final scoped = counts.where(inScope).toList();
      if (scoped.isEmpty) {
        return const CapabilityEvidence(CapabilityState.unspecified,
            path: 'tables.validation_policies[]');
      }
      final two = scoped.where((c) => c.value is num && (c.value as num) >= 2).firstOrNull;
      if (two != null) {
        return CapabilityEvidence(CapabilityState.enabled, path: two.path, value: two.value);
      }
      return CapabilityEvidence(CapabilityState.disabled,
          path: scoped.first.path, value: scoped.first.value);
    });

/// A boolean setting: explicit true / false, absent = the target's own.
CapabilityEvidence _boolSetting(TemplateFacts facts, String id) => _guard(facts, () {
      final r = facts.first(id);
      if (r == null || r.disposition == TemplateFieldDisposition.absent) {
        return CapabilityEvidence(CapabilityState.unspecified, path: id);
      }
      if (r.value is! bool) return CapabilityEvidence(CapabilityState.unknown, path: r.path);
      return CapabilityEvidence(
          r.value == true ? CapabilityState.enabled : CapabilityState.disabled,
          path: r.path, value: r.value);
    });

/// Rows of a table exist with `active` true; gated by [feature] when set.
CapabilityEvidence _activeRows(TemplateFacts facts, String table,
        {WorkspaceFeature? feature}) =>
    _guard(facts, () {
      if (feature != null) {
        final f = featureState(facts, feature);
        if (f.state == CapabilityState.disabled || f.state == CapabilityState.conditional) {
          return f;
        }
      }
      final active = facts.field('tables.$table[].active');
      final on = active.where((a) => a.value == true).firstOrNull;
      if (on != null) return CapabilityEvidence(CapabilityState.enabled, path: on.path, value: true);
      if (active.isNotEmpty) {
        return CapabilityEvidence(CapabilityState.disabled, path: active.first.path, value: false);
      }
      return CapabilityEvidence(CapabilityState.unspecified, path: 'tables.$table[]');
    });

/// Several fields that must all be present for the setting to be defined.
CapabilityEvidence _defined(TemplateFacts facts, List<String> ids) => _guard(facts, () {
      for (final id in ids) {
        if (facts.needsInput(id)) {
          return CapabilityEvidence(CapabilityState.localInputRequired, path: id);
        }
      }
      final present = [
        for (final id in ids)
          if (facts.first(id)?.disposition == TemplateFieldDisposition.present) id,
      ];
      if (present.length == ids.length) {
        return CapabilityEvidence(CapabilityState.enabled, path: ids.first);
      }
      return CapabilityEvidence(CapabilityState.unspecified, path: ids.first);
    });

/// The curated capabilities: outcomes people search for that no single
/// flag names. Every feature flag is a capability too (see [capabilityCatalog]).
final List<TemplateCapability> curatedCapabilities = [
  TemplateCapability(
    id: 'policy.multi_approval',
    synonyms: const {
      'en': ['two approvals', 'two validators', 'four eyes', 'dual approval', 'double validation'],
      'fr': ['deux validations', 'double validation', 'deux validateurs', 'quatre yeux'],
      'de': ['zwei freigaben', 'vier augen', 'doppelte freigabe', 'zwei prufer'],
      'es': ['dos aprobaciones', 'doble validacion', 'cuatro ojos', 'dos validadores'],
      'it': ['due approvazioni', 'doppia validazione', 'quattro occhi', 'due validatori'],
    },
    evaluate: (f) => _multiApproval(f),
  ),
  TemplateCapability(
    id: 'policy.multi_approval_refunds',
    synonyms: const {
      'en': ['two approvals for refunds', 'refund approval', 'refunds need two'],
      'fr': ['deux validations pour les remboursements', 'validation des remboursements'],
      'de': ['zwei freigaben fur erstattungen', 'erstattung freigabe'],
      'es': ['dos aprobaciones para reembolsos', 'aprobacion de reembolsos'],
      'it': ['due approvazioni per i rimborsi', 'approvazione rimborsi'],
    },
    evaluate: (f) => _multiApproval(f, eventTypes: const {'refund'}),
  ),
  TemplateCapability(
    id: 'model.pay_as_you_go',
    synonyms: const {
      'en': ['pay as you go', 'pay per use', 'usage billing', 'metered'],
      'fr': ['paiement a l usage', 'a l usage', 'facturation a l usage', 'sans abonnement'],
      'de': ['nutzungsbasiert', 'pay per use', 'abrechnung nach nutzung'],
      'es': ['pago por uso', 'facturacion por uso'],
      'it': ['pagamento a consumo', 'a consumo', 'fatturazione a consumo'],
    },
    evaluate: (f) => _boolSetting(f, 'workspace.billing_rules.usage_auto'),
  ),
  TemplateCapability(
    id: 'model.credit_packs',
    synonyms: const {
      'en': ['credit packs', 'credit pack', 'punch card', 'carnet', 'prepaid'],
      'fr': ['carnets', 'carnet', 'carte a points', 'prepaye'],
      'de': ['guthabenpakete', 'zehnerkarte', 'prepaid', 'karnet'],
      'es': ['bonos', 'bono', 'paquetes de creditos', 'prepago'],
      'it': ['carnet', 'pacchetti di crediti', 'prepagato'],
    },
    evaluate: (f) => _activeRows(f, 'credit_products', feature: WorkspaceFeature.carnets),
  ),
  TemplateCapability(
    id: 'model.subscription_plans',
    synonyms: const {
      'en': ['subscription', 'membership plans', 'monthly plan', 'plans'],
      'fr': ['abonnement', 'formules', 'forfait mensuel', 'adhesion'],
      'de': ['abonnement', 'mitgliedschaft', 'monatsplan', 'tarife'],
      'es': ['suscripcion', 'planes', 'cuota mensual', 'membresia'],
      'it': ['abbonamento', 'piani', 'mensile', 'tessera'],
    },
    evaluate: (f) => _activeRows(f, 'plans'),
  ),
  TemplateCapability(
    id: 'setting.opening_hours',
    synonyms: const {
      'en': ['opening hours', 'open days', 'business hours'],
      'fr': ['horaires d ouverture', 'heures d ouverture', 'jours d ouverture'],
      'de': ['offnungszeiten', 'geschaftszeiten', 'offnungstage'],
      'es': ['horario de apertura', 'dias de apertura'],
      'it': ['orari di apertura', 'giorni di apertura'],
    },
    evaluate: (f) => _defined(f, const [
      'workspace.booking_rules.open_weekdays',
      'workspace.booking_rules.work_start_minutes',
      'workspace.booking_rules.work_end_minutes',
    ]),
  ),
  TemplateCapability(
    id: 'setting.custom_member_form',
    synonyms: const {
      'en': ['custom membership form', 'custom fields', 'member form'],
      'fr': ['formulaire d adhesion', 'champs personnalises', 'formulaire membre'],
      'de': ['eigene felder', 'mitgliedsformular', 'benutzerdefinierte felder'],
      'es': ['campos personalizados', 'formulario de socio'],
      'it': ['campi personalizzati', 'modulo socio'],
    },
    evaluate: (f) => _activeRows(f, 'workspace_field_definitions',
        feature: WorkspaceFeature.customFields),
  ),
];

/// Every capability: the curated outcomes, then one per feature flag.
final List<TemplateCapability> capabilityCatalog = [
  ...curatedCapabilities,
  for (final feature in WorkspaceFeature.values)
    TemplateCapability(
      id: 'feature.${feature.name}',
      evaluate: (f) => featureState(f, feature),
    ),
];

final Map<String, TemplateCapability> capabilityById = {
  for (final c in capabilityCatalog) c.id: c,
};

// ── words → capabilities ─────────────────────────────────────────────

const _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'ç': 'c', 'è': 'e', 'é': 'e',
  'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o',
  'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ß': 'ss', 'œ': 'oe', 'æ': 'ae',
};

/// Lower case, accents folded, punctuation to spaces, spaces collapsed.
String normalizeSearch(String raw) {
  final lower = raw.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_fold[ch] ?? ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r"[^a-z0-9._ ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Capability ids a search vocabulary knows words for: localized labels
/// (from the app's own ARB, supplied by the caller) plus the synonyms
/// above, in every locale — someone typing German in a French app still
/// finds what they mean.
class CapabilityVocabulary {
  CapabilityVocabulary(Map<String, List<String>> labels) {
    void add(String id, String phrase) {
      final n = normalizeSearch(phrase);
      if (n.isNotEmpty) _phrases.add((id: id, phrase: n));
    }
    for (final c in capabilityCatalog) {
      add(c.id, c.id);
      for (final list in c.synonyms.values) {
        for (final p in list) {
          add(c.id, p);
        }
      }
    }
    for (final entry in labels.entries) {
      for (final p in entry.value) {
        add(entry.key, p);
      }
    }
    // Longest phrases first: "two approvals for refunds" before "two approvals".
    _phrases.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
  }

  final List<({String id, String phrase})> _phrases = [];

  /// What [query] asks for: the capabilities whose phrases it contains,
  /// longest first, a phrase consumed once. The rest are free words.
  ({List<String> capabilities, List<String> freeWords}) parse(String query) {
    var rest = ' ${normalizeSearch(query)} ';
    final ids = <String>[];
    for (final p in _phrases) {
      final needle = ' ${p.phrase} ';
      if (rest.contains(needle)) {
        if (!ids.contains(p.id)) ids.add(p.id);
        rest = rest.replaceAll(needle, ' ');
      }
    }
    final free = rest.split(' ').where((w) => w.isNotEmpty).toList();
    return (capabilities: ids, freeWords: free);
  }

  /// The nearest known phrase to an unrecognised [word], for a "did you
  /// mean" line. Never applied to the query by itself.
  String? suggest(String word) {
    final w = normalizeSearch(word);
    if (w.length < 4) return null;
    String? best;
    var bestDistance = 3;
    for (final p in _phrases) {
      for (final token in p.phrase.split(' ')) {
        if (token.length < 4) continue;
        final d = _levenshtein(w, token, bestDistance);
        if (d < bestDistance && d > 0) {
          bestDistance = d;
          best = token;
        }
      }
    }
    return best;
  }
}

int _levenshtein(String a, String b, int cap) {
  if ((a.length - b.length).abs() >= cap) return cap;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

// ── search ───────────────────────────────────────────────────────────

/// A search: required (AND), preferred (ranking only), excluded, and the
/// free words matched against the template's own name and description.
class CapabilityQuery {
  const CapabilityQuery({
    this.required = const [],
    this.preferred = const [],
    this.excluded = const [],
    this.freeWords = const [],
  });

  final List<String> required, preferred, excluded, freeWords;

  /// A capability both required and excluded can match nothing.
  List<String> get contradictions =>
      required.where(excluded.contains).toList();
}

class TemplateMatch {
  const TemplateMatch({
    required this.inspection,
    required this.evidence,
    required this.unmet,
    required this.score,
  });

  final TemplateInspection inspection;

  /// Every capability the query named, and what this template says.
  final Map<String, CapabilityEvidence> evidence;

  /// Required capabilities this template does not satisfy — with their
  /// state, so "disabled" and "unspecified" read differently.
  final List<String> unmet;
  final int score;

  bool get satisfiesAll => unmet.isEmpty;
}

/// Each template against [query]. Templates failing a requirement or
/// satisfying an exclusion are dropped; the rest are ranked by preferred
/// capabilities, then free-word hits, then name and id for stability.
List<TemplateMatch> matchTemplates(
    Iterable<TemplateInspection> inspections, CapabilityQuery query) {
  if (query.contradictions.isNotEmpty) return const [];
  final named = {...query.required, ...query.preferred, ...query.excluded};
  final out = <TemplateMatch>[];
  for (final inspection in inspections) {
    final facts = TemplateFacts(inspection);
    final evidence = <String, CapabilityEvidence>{
      for (final id in named)
        id: capabilityById[id]?.evaluate(facts) ??
            const CapabilityEvidence(CapabilityState.unknown),
    };
    final unmet = [for (final id in query.required) if (!evidence[id]!.state.satisfies) id];
    if (unmet.isNotEmpty) continue;
    if (query.excluded.any((id) => evidence[id]!.state.satisfies)) continue;
    final text = normalizeSearch('${inspection.name} ${inspection.description}');
    final words = query.freeWords.where(text.contains).length;
    if (query.freeWords.isNotEmpty && words == 0 && query.required.isEmpty &&
        query.preferred.isEmpty) {
      continue;
    }
    final preferred = query.preferred.where((id) => evidence[id]!.state.satisfies).length;
    out.add(TemplateMatch(
      inspection: inspection,
      evidence: evidence,
      unmet: unmet,
      score: preferred * 10 + words,
    ));
  }
  out.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    final n = a.inspection.name.toLowerCase().compareTo(b.inspection.name.toLowerCase());
    return n != 0 ? n : a.inspection.templateId.compareTo(b.inspection.templateId);
  });
  return out;
}

// ── comparison ───────────────────────────────────────────────────────

enum ComparisonDifference { same, different, missing, unknown, notComparable }

/// One template's cell: its value, or why there is none.
class ComparisonCell {
  const ComparisonCell({this.value, required this.disposition, this.absent});
  final Object? value;
  final TemplateFieldDisposition disposition;
  final TemplateAbsentMeaning? absent;

  static const none = ComparisonCell(disposition: TemplateFieldDisposition.absent);
}

class ComparisonRow {
  const ComparisonRow({
    required this.path,
    required this.id,
    required this.cells,
    required this.difference,
  });

  /// Natural path (rows by their natural key) and the registry id.
  final String path, id;
  final List<ComparisonCell> cells;
  final ComparisonDifference difference;
}

/// The union of every field of [inspections], one row per concrete path,
/// in the inspections' order. A missing row is `missing`, not false; an
/// unreadable one is `unknown`; money in different currencies is
/// `notComparable` however equal the numbers look.
List<ComparisonRow> compareTemplates(List<TemplateInspection> inspections) {
  final byPath = <String, Map<int, TemplateFieldRecord>>{};
  final idOf = <String, String>{};
  for (var i = 0; i < inspections.length; i++) {
    for (final f in inspections[i].fields) {
      (byPath[f.path] ??= {})[i] = f;
      idOf[f.path] = f.id;
    }
  }
  final currencies = [
    for (final t in inspections)
      t.fields.where((f) => f.id == 'workspace.currency_code').firstOrNull?.value,
  ];
  final paths = byPath.keys.toList()..sort();
  return [
    for (final path in paths)
      () {
        final cells = [
          for (var i = 0; i < inspections.length; i++)
            byPath[path]![i] == null
                ? ComparisonCell.none
                : ComparisonCell(
                    value: byPath[path]![i]!.value,
                    disposition: byPath[path]![i]!.disposition,
                    absent: byPath[path]![i]!.absent,
                  ),
        ];
        final id = idOf[path]!;
        ComparisonDifference diff;
        if (cells.any((c) => c.disposition == TemplateFieldDisposition.unknown)) {
          diff = ComparisonDifference.unknown;
        } else if (cells.any((c) => c.disposition != TemplateFieldDisposition.present)) {
          diff = cells.every((c) => c.disposition == cells.first.disposition)
              ? ComparisonDifference.same
              : ComparisonDifference.missing;
        } else if (id.endsWith('_cents') && currencies.toSet().length > 1) {
          diff = ComparisonDifference.notComparable;
        } else {
          final first = '${cells.first.value}';
          diff = cells.every((c) => '${c.value}' == first)
              ? ComparisonDifference.same
              : ComparisonDifference.different;
        }
        return ComparisonRow(path: path, id: id, cells: cells, difference: diff);
      }(),
  ];
}
