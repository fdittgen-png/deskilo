// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';

/// Rules for the owner-set WhatsApp group link (#231). The prefix is
/// enforced twice with this single constant: the settings-form validator
/// and the 0029 column check (`whatsapp_group ~
/// '^https://chat\.whatsapp\.com/'`) — cross-pinned by test.
abstract final class WhatsappGroupRules {
  /// Every WhatsApp group invite link starts with this — anything else
  /// is not a group invite and is rejected client- AND server-side.
  static const String linkPrefix = 'https://chat.whatsapp.com/';

  /// '' (no group) or a real chat.whatsapp.com invite link.
  static bool isValid(String link) =>
      link.isEmpty || link.startsWith(linkPrefix);
}

/// One coworking community (spec §3). Currency defaults from the country;
/// the owner may override it (decided 2026-07-07).
@freezed
sealed class Workspace with _$Workspace {
  const Workspace._();

  const factory Workspace({
    required String id,
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    required String inviteCode,

    /// Per-workspace feature overrides (#146): WorkspaceFeature.name →
    /// bool. Absent key = the feature's registry default (ON); resolve
    /// with [resolveEnabledFeatures].
    @Default(<String, dynamic>{}) Map<String, dynamic> featureFlags,

    /// Owner-configured payment instructions (#155) as stored — decode
    /// with [PaymentInstructions.fromDb]. Empty = none configured.
    @Default(<String, dynamic>{}) Map<String, dynamic> paymentInstructions,

    /// Owner-set WhatsApp group invite link (#231), shown to members in
    /// the directory (#232); '' = no group configured. Shape-checked
    /// against [WhatsappGroupRules.linkPrefix] (0029 column check).
    @Default('') String whatsappGroup,
  }) = _Workspace;

  /// The group link as a launchable https URI for the directory (#232),
  /// or null when no group is configured.
  Uri? get whatsappGroupUri =>
      whatsappGroup.isEmpty ? null : Uri.tryParse(whatsappGroup);
}
