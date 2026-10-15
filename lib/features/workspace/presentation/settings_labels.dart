// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the words of the registry. A setting's name, its hint and its
// group are user-facing text, so they come from the ARB files; the registry
// row carries only the key. A key with no entry here still shows (as its
// key), so a missing label is visible, never blank -- and
// `settings_labels_test` fails until a seeded key has one.
import '../../../core/settings/settings.dart';
import '../../../l10n/app_localizations.dart';

String settingLabel(AppLocalizations l10n, String key) => switch (key) {
      'dunning.first_after_days' => l10n.settingLabelDunningFirstAfterDays,
      _ => key,
    };

String? settingHint(AppLocalizations l10n, String key) => switch (key) {
      'dunning.first_after_days' => l10n.settingHintDunningFirstAfterDays,
      _ => null,
    };

String settingGroupLabel(AppLocalizations l10n, String group) => switch (group) {
      'dunning' => l10n.settingGroupDunning,
      _ => group,
    };

String settingUnitLabel(AppLocalizations l10n, String unit) => switch (unit) {
      'seconds' => l10n.settingUnitSeconds,
      'minutes' => l10n.settingUnitMinutes,
      'hours' => l10n.settingUnitHours,
      'days' => l10n.settingUnitDays,
      _ => unit,
    };

String settingProblemLabel(AppLocalizations l10n, SettingProblem p) => switch (p) {
      SettingProblem.notANumber => l10n.settingProblemNotANumber,
      SettingProblem.belowMin => l10n.settingProblemBelowMin,
      SettingProblem.aboveMax => l10n.settingProblemAboveMax,
      SettingProblem.belowFloor => l10n.settingProblemBelowFloor,
      SettingProblem.wrongType => l10n.settingProblemWrongType,
      SettingProblem.notAChoice => l10n.settingProblemNotAChoice,
    };

String settingOriginLabel(AppLocalizations l10n, SettingOrigin o) => switch (o) {
      SettingOrigin.workspace => l10n.settingOriginWorkspace,
      SettingOrigin.platform => l10n.settingOriginPlatform,
      SettingOrigin.registryDefault => l10n.settingOriginDefault,
    };

/// "Between 1 and 365 days", "At least 1 day"... for a numeric definition.
String? settingRangeLabel(AppLocalizations l10n, SettingDefinition d) {
  if (d.type != SettingType.integer && d.type != SettingType.duration) return null;
  final unit = settingUnitLabel(l10n, d.unit);
  final min = d.min, max = d.max;
  if (min != null && max != null) return l10n.settingRange('$min', '$max', unit);
  if (min != null) return l10n.settingMinOnly('$min', unit);
  if (max != null) return l10n.settingMaxOnly('$max', unit);
  return null;
}
