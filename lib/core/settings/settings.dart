// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 (S1 of #2483) -- business values are settings: declared once in a
// registry (type, default, bounds, owner), resolved to one effective value
// per key, read through ONE typed reader. This is the pure side: the typed
// definitions, the resolved snapshot a calculation receives as a parameter
// and the interfaces the rest of the app depends on. The Supabase
// implementation lives beside the repositories (`features/workspace/data`).
//
// There is deliberately no `read(key, fallback)`: a caller never writes the
// fallback, the registry's default is the fallback.
import '../cache/cache_scope.dart';
import '../data/json_reader.dart';

/// The kinds of value a setting holds. A duration is a whole number of its
/// definition's [SettingDefinition.unit].
enum SettingType {
  integer('int'),
  duration('duration'),
  boolean('bool'),
  text('text'),
  choice('enum');

  const SettingType(this.wire);
  final String wire;

  static SettingType fromWire(String wire, {String context = 'setting'}) {
    for (final t in values) {
      if (t.wire == wire) return t;
    }
    throw JsonShapeException(context, 'type', 'a known setting type', wire);
  }
}

/// Where a value may be set: the whole installation, or one workspace.
enum SettingScope {
  platform('platform'),
  workspace('workspace');

  const SettingScope(this.wire);
  final String wire;

  static SettingScope fromWire(String wire, {String context = 'setting'}) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    throw JsonShapeException(context, 'scope', 'a known scope', wire);
  }
}

/// Where the effective value came from.
enum SettingOrigin { workspace, platform, registryDefault }

/// One row of the registry. [min]/[max] bound a number, [floor] is a
/// security bound a value may never go below (the server refuses it and the
/// editor explains it), and a row that is not [editable] is a documented
/// guardrail: shown read-only with its [note].
class SettingDefinition {
  const SettingDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.min,
    this.max,
    this.unit = '',
    required this.group,
    required this.scopes,
    this.editPermission = '',
    this.floor,
    this.editable = true,
    this.choices = const [],
    this.source = '',
    this.note = '',
  });

  factory SettingDefinition.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'setting_definitions');
    final type = SettingType.fromWire(r.string('type'));
    return SettingDefinition(
      key: r.string('key'),
      type: type,
      defaultValue: _value(type, r, 'default_value'),
      min: r.numOrNull('min'),
      max: r.numOrNull('max'),
      unit: r.stringOr('unit'),
      group: r.string('group_key'),
      scopes: {
        for (final s in r.strings('scopes')) SettingScope.fromWire(s),
      },
      editPermission: r.stringOr('edit_permission'),
      floor: r.numOrNull('floor_value'),
      editable: r.boolOr('editable', true),
      choices: r.listOrAbsent('choices').isEmpty ? const [] : r.strings('choices'),
      source: r.stringOr('source'),
      note: r.stringOr('note'),
    );
  }

  final String key;
  final SettingType type;
  final Object defaultValue;
  final num? min;
  final num? max;
  final String unit;
  final String group;
  final Set<SettingScope> scopes;
  final String editPermission;
  final num? floor;
  final bool editable;
  final List<String> choices;
  final String source;
  final String note;

  bool allows(SettingScope scope) => scopes.contains(scope);

  /// Why [value] is not acceptable, or null: the type, the bounds and the
  /// security floor -- the same rules `set_setting` enforces in SQL.
  SettingProblem? check(Object? value) {
    switch (type) {
      case SettingType.integer || SettingType.duration:
        if (value is! num || value != value.roundToDouble()) {
          return SettingProblem.notANumber;
        }
        if (floor != null && value < floor!) return SettingProblem.belowFloor;
        if (min != null && value < min!) return SettingProblem.belowMin;
        if (max != null && value > max!) return SettingProblem.aboveMax;
      case SettingType.boolean:
        if (value is! bool) return SettingProblem.wrongType;
      case SettingType.text:
        if (value is! String) return SettingProblem.wrongType;
      case SettingType.choice:
        if (value is! String || !choices.contains(value)) {
          return SettingProblem.notAChoice;
        }
    }
    return null;
  }

  static Object _value(SettingType type, JsonReader r, String key) =>
      switch (type) {
        SettingType.integer || SettingType.duration => r.integer(key),
        SettingType.boolean => switch (r.raw(key)) {
            final bool b => b,
            final other => throw JsonShapeException(r.context, key, 'bool', '${other.runtimeType}'),
          },
        SettingType.text || SettingType.choice => r.string(key),
      };
}

enum SettingProblem {
  notANumber,
  belowMin,
  aboveMax,
  belowFloor,
  wrongType,
  notAChoice,
}

/// One version of a stored value (history, newest first).
class SettingVersion {
  const SettingVersion({
    required this.scope,
    this.workspaceId,
    required this.key,
    required this.value,
    required this.validFrom,
    this.validTo,
    this.note = '',
    this.changedBy = '',
  });

  factory SettingVersion.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'setting_history');
    return SettingVersion(
      scope: SettingScope.fromWire(r.string('scope')),
      workspaceId: r.stringOrNull('workspace_id'),
      key: r.string('key'),
      value: r.raw('value') ?? (throw JsonShapeException(r.context, 'value', 'a value', 'null')),
      validFrom: r.string('valid_from'),
      validTo: r.stringOrNull('valid_to'),
      note: r.stringOr('note'),
      changedBy: r.stringOr('changed_by'),
    );
  }

  final SettingScope scope;
  final String? workspaceId;
  final String key;
  final Object value;
  final String validFrom;
  final String? validTo;
  final String note;
  final String changedBy;
}

/// An immutable snapshot: the registry and the EFFECTIVE value of every
/// key for one workspace (workspace override, else platform value, else the
/// registry default). A calculation takes one as a parameter.
class SettingsSet {
  const SettingsSet(this.definitions, this.effective,
      {this.origins = const {}, this.revision = ''});

  /// A set where every key has its registry default.
  factory SettingsSet.defaults(Iterable<SettingDefinition> definitions) =>
      SettingsSet(
        {for (final d in definitions) d.key: d},
        {for (final d in definitions) d.key: d.defaultValue},
        origins: {for (final d in definitions) d.key: SettingOrigin.registryDefault},
        revision: 'defaults',
      );

  factory SettingsSet.parse(Object? raw) {
    if (raw is! List) {
      throw JsonShapeException('my_settings', '', 'list', '${raw.runtimeType}');
    }
    final definitions = <String, SettingDefinition>{};
    final effective = <String, Object>{};
    final origins = <String, SettingOrigin>{};
    for (final item in raw) {
      final r = JsonReader.of(item, context: 'my_settings');
      final d = SettingDefinition.fromJson(item);
      definitions[d.key] = d;
      final value = r.raw('value');
      effective[d.key] = value ?? d.defaultValue;
      origins[d.key] = switch (r.stringOr('origin', 'default')) {
        'workspace' => SettingOrigin.workspace,
        'platform' => SettingOrigin.platform,
        _ => SettingOrigin.registryDefault,
      };
    }
    return SettingsSet(definitions, effective,
        origins: origins,
        revision: cacheDigest('settings-revision', [
          for (final k in effective.keys.toList()..sort()) '$k=${effective[k]}',
        ], 16));
  }

  final Map<String, SettingDefinition> definitions;
  final Map<String, Object> effective;
  final Map<String, SettingOrigin> origins;

  /// The data version: it changes whenever an effective value changes.
  final String revision;

  /// The effective value of [key] as a [T] (`int`, `bool`, `String`, or
  /// [Duration] for a duration setting). An unknown key or a wrong type is
  /// a defect and throws -- there is no caller-side fallback.
  T read<T>(String key) {
    final d = definitions[key];
    if (d == null) throw UnknownSetting(key);
    final v = effective[key] ?? d.defaultValue;
    if (T == Duration) {
      if (d.type != SettingType.duration || v is! num) throw SettingTypeMismatch(key, T);
      return _toDuration(d.unit, v.toInt()) as T;
    }
    if (v is T) return v as T;
    if (T == double && v is num) return v.toDouble() as T;
    throw SettingTypeMismatch(key, T);
  }

  SettingOrigin originOf(String key) => origins[key] ?? SettingOrigin.registryDefault;

  static Duration _toDuration(String unit, int n) => switch (unit) {
        'seconds' => Duration(seconds: n),
        'minutes' => Duration(minutes: n),
        'hours' => Duration(hours: n),
        'days' => Duration(days: n),
        _ => throw ArgumentError('a duration setting needs a time unit, not "$unit"'),
      };
}

class UnknownSetting implements Exception {
  const UnknownSetting(this.key);
  final String key;
  @override
  String toString() => 'UnknownSetting: $key is not in the registry';
}

class SettingTypeMismatch implements Exception {
  const SettingTypeMismatch(this.key, this.requested);
  final String key;
  final Type requested;
  @override
  String toString() => 'SettingTypeMismatch: $key cannot be read as $requested';
}

/// The installation could not give settings and no copy stands in.
class SettingsUnavailable implements Exception {
  const SettingsUnavailable(this.cause);
  final Object cause;
  @override
  String toString() => 'SettingsUnavailable: $cause';
}

/// Reading settings. Implementations live beside the repositories.
abstract class SettingsSource {
  /// The registry and the effective values for [workspaceId] (null: the
  /// platform's own view -- platform values over defaults).
  Future<SettingsSet> load(String? workspaceId);

  /// Every version of [key] stored for [scope] (and [workspaceId]), newest first.
  Future<List<SettingVersion>> history(String? workspaceId, String key);
}

/// Writing settings: the person the definition's permission names.
abstract class SettingsAdmin {
  /// Stores a new version of [key]; the version in force is closed, not edited.
  Future<void> setValue({
    String? workspaceId,
    required String key,
    required Object value,
    String note = '',
  });
}

abstract interface class SettingsStore implements SettingsSource, SettingsAdmin {}

/// A [SettingsSource] that falls back to the registry shipped in the app
/// (defaults only, no stored values) when the installation cannot answer.
class BundledFallbackSettingsSource implements SettingsSource {
  BundledFallbackSettingsSource(this.primary, this.bundledDefinitions);

  final SettingsSource primary;
  final Future<List<SettingDefinition>> Function() bundledDefinitions;

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) =>
      primary.history(workspaceId, key);

  @override
  Future<SettingsSet> load(String? workspaceId) async {
    try {
      return await primary.load(workspaceId);
    } on JsonShapeException {
      rethrow;
    } on Object catch (e, st) {
      // trace-exempt: answered from the bundled registry or rethrown typed.
      try {
        return SettingsSet.defaults(await bundledDefinitions());
      } on Object {
        // trace-exempt: rethrown as SettingsUnavailable with the cause.
        Error.throwWithStackTrace(SettingsUnavailable(e), st);
      }
    }
  }
}
