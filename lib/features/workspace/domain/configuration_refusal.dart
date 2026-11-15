// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4028 — what a configuration applied to this business left out, and
// why: its prices when the configuration counts in another currency, its
// tax rates when it comes from another country. The server names each
// refused entity (`refused`: entity, code, source, target); a person reads
// one line per reason.

/// Why an entity was left out.
enum ConfigurationRefusalCode {
  /// The configuration counts in another currency: its amounts stay out.
  currency,

  /// The configuration comes from another country: its tax rates stay out.
  country;

  static ConfigurationRefusalCode? parse(Object? wire) => switch (wire) {
    'currency' => ConfigurationRefusalCode.currency,
    'country' => ConfigurationRefusalCode.country,
    _ => null,
  };
}

/// One entity the import left out: [source] is the configuration's
/// currency or country, [target] this business's.
class ConfigurationRefusal {
  const ConfigurationRefusal({
    required this.entity,
    required this.code,
    required this.source,
    required this.target,
  });

  final String entity;
  final ConfigurationRefusalCode code;
  final String source;
  final String target;

  /// The `refused` list of an import's or a template apply's answer; an
  /// answer without one refused nothing.
  static List<ConfigurationRefusal> listFrom(Object? result) => [
    if (result is Map && result['refused'] is List)
      for (final e in result['refused'] as List)
        if (e is Map)
          if (ConfigurationRefusalCode.parse(e['code']) case final code?)
            ConfigurationRefusal(
              entity: '${e['entity'] ?? ''}',
              code: code,
              source: '${e['source'] ?? ''}',
              target: '${e['target'] ?? ''}',
            ),
  ];

  /// One refusal per reason, in the order the reasons first appear: every
  /// priced entity left out for the same two currencies is one sentence.
  static List<ConfigurationRefusal> perReason(List<ConfigurationRefusal> all) {
    final seen = <ConfigurationRefusalCode>{};
    return [
      for (final r in all)
        if (seen.add(r.code)) r,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ConfigurationRefusal &&
      other.entity == entity &&
      other.code == code &&
      other.source == source &&
      other.target == target;

  @override
  int get hashCode => Object.hash(entity, code, source, target);

  @override
  String toString() =>
      'ConfigurationRefusal($entity, ${code.name}, $source → $target)';
}
