// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_levels.freezed.dart';

/// The owner-curated set of subscription levels members may pick from
/// (ADR 0008, `workspaces.subscription_levels` jsonb): the 25/50/75/100
/// presets each individually enabled, extra owner-defined levels, and an
/// optional negotiated free value.
@freezed
sealed class SubscriptionLevels with _$SubscriptionLevels {
  const SubscriptionLevels._();

  const factory SubscriptionLevels({
    @Default([25, 50, 75, 100]) List<int> enabledPresets,
    @Default([]) List<int> extraLevels,
    @Default(false) bool allowCustom,
  }) = _SubscriptionLevels;

  /// The preset steps the owner can enable or hide.
  static const presets = [25, 50, 75, 100];

  /// Maps the raw `subscription_levels` jsonb column value. (Named fromDb,
  /// not fromJson, so freezed does not expect a json_serializable part.)
  factory SubscriptionLevels.fromDb(Map<String, dynamic> json) =>
      SubscriptionLevels(
        enabledPresets: [
          ...?(json['enabled_presets'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()),
        ],
        extraLevels: [
          ...?(json['extra_levels'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()),
        ],
        allowCustom: json['allow_custom'] as bool? ?? false,
      );

  /// Wire format for writing the jsonb column back.
  Map<String, dynamic> toDb() => {
        'enabled_presets': enabledPresets,
        'extra_levels': extraLevels,
        'allow_custom': allowCustom,
      };

  /// Sorted union of enabled presets and extra levels — what the picker
  /// offers for new assignments.
  List<int> get offeredLevels =>
      {...enabledPresets, ...extraLevels}.toList()..sort();
}
