// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the platform settings of the personal home (P), which hosts no
// workspace. They are the existing registry's platform scope read with a
// null workspace (`my_settings(null)`, 0428): no dummy workspace, and
// nothing taken from the workspace somebody selected last. The identity is
// fixed before the read awaits, so a later switch cannot retarget it.
import 'settings.dart';
import 'settings_capture.dart';

/// Reads the platform scope of one installation for one signed-in person.
class PlatformSettingsReader {
  const PlatformSettingsReader({
    required this.source,
    required this.installation,
  });

  /// The registry on the personal home's own client.
  final SettingsSource source;

  /// The personal home's origin.
  final String installation;

  /// The platform settings for [principal] (the signed-in person at the
  /// personal home) as an immutable capture with no workspace, or null
  /// signed out: no other person's values stand in.
  Future<SettingsCapture?> read(String? principal) async {
    final who = principal;
    if (who == null) return null;
    return captureSettings(
      source,
      SettingsIdentity(
        installation: installation,
        workspaceId: null,
        principal: who,
      ),
    );
  }
}
