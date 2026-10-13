// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/settings/settings.dart';

/// #2484 -- changing a setting: the text a person typed becomes the value
/// of the definition's type, is checked against its bounds and floor BEFORE
/// anything is sent (the server checks again), then stored as a new version.
class SettingsCommands {
  const SettingsCommands(this._admin);

  final SettingsAdmin _admin;

  /// The value [text] stands for under [definition], or null when it is not
  /// of the type at all.
  Object? parse(SettingDefinition definition, String text) {
    final t = text.trim();
    return switch (definition.type) {
      SettingType.integer || SettingType.duration => int.tryParse(t),
      SettingType.boolean => switch (t) {
          'true' => true,
          'false' => false,
          _ => null,
        },
      SettingType.text || SettingType.choice => t.isEmpty ? null : t,
    };
  }

  /// Why [text] is not acceptable for [definition], or null.
  SettingProblem? problemOf(SettingDefinition definition, String text) {
    final value = parse(definition, text);
    if (value == null) {
      return switch (definition.type) {
        SettingType.integer || SettingType.duration => SettingProblem.notANumber,
        SettingType.choice => SettingProblem.notAChoice,
        _ => SettingProblem.wrongType,
      };
    }
    return definition.check(value);
  }

  /// Throws whatever the repository throws; the caller reports it.
  Future<void> save({
    String? workspaceId,
    required SettingDefinition definition,
    required String text,
    String note = '',
  }) {
    final value = parse(definition, text);
    final problem = value == null ? SettingProblem.wrongType : definition.check(value);
    if (problem != null) throw ArgumentError('${definition.key} refused: ${problem.name}');
    return _admin.setValue(
      workspaceId: workspaceId,
      key: definition.key,
      value: value!,
      note: note,
    );
  }
}
