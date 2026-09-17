// SPDX-License-Identifier: 0BSD
//
// #1451 — the Workspace settings Save as ONE command.
//
// Eight independent requests used to make one visible Save: a failure on
// the fifth left four committed. The server applies this payload in one
// transaction (`save_workspace_settings`, 0241) against the version the
// form was opened on.
import 'new_member_defaults.dart';

/// Everything the Workspace settings form saves at once.
class WorkspaceSettingsSave {
  const WorkspaceSettingsSave({
    required this.expectedModifiedAt,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.whatsappGroup,
    required this.address,
    required this.defaultLocale,
    required this.deskOpacity,
    required this.invitationTemplates,
    required this.newMemberDefaults,
  });

  /// The row's `modified_datetime` when the form was filled; null skips the
  /// comparison (a row the server never stamped).
  final DateTime? expectedModifiedAt;
  final String countryCode;
  final String currencyCode;
  final String timezone;
  final String whatsappGroup;
  final String address;
  final String defaultLocale;
  final int deskOpacity;

  /// Language → template; blank entries mean "built-in message".
  final Map<String, String> invitationTemplates;
  final NewMemberDefaults newMemberDefaults;

  /// The `p_settings` payload. Values are sent as typed; the server trims
  /// and drops blank templates, so a retry compares like with like.
  Map<String, Object?> toSettings() => {
        'country_code': countryCode.toUpperCase(),
        'currency_code': currencyCode.toUpperCase(),
        'timezone': timezone,
        'whatsapp_group': whatsappGroup,
        'address': address,
        'default_locale': defaultLocale,
        'desk_opacity': deskOpacity,
        'invitation_templates': invitationTemplates,
        newMemberDefaultsKey: newMemberDefaults.toValue(),
      };
}

/// The settings changed on the server since the form was opened; nothing
/// was written. The form keeps what was typed.
class WorkspaceSettingsConflict implements Exception {
  const WorkspaceSettingsConflict();

  /// The SQLSTATE `save_workspace_settings` raises.
  static const String sqlState = 'DK409';

  @override
  String toString() =>
      'WorkspaceSettingsConflict: the workspace settings changed since they were opened';
}
