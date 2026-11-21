// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the Demo's answer to "which kind did each of my businesses set": the
// kind kept in the Demo's settings, as the server keeps it, for the businesses
// the session lists.
import '../../../features/workspace/domain/business_profile.dart';
import '../../../features/workspace/domain/my_business_kinds.dart';
import '../../settings/settings.dart';

class DemoMyBusinessKinds implements MyBusinessKindsReader {
  const DemoMyBusinessKinds(this._settings, this._workspaceIds);

  final SettingsStore _settings;
  final Future<Iterable<String>> Function() _workspaceIds;

  @override
  Future<Map<String, String>> read() async {
    final out = <String, String>{};
    for (final id in await _workspaceIds()) {
      final set = await _settings.load(id);
      // Only a kind the business SET: the registry default says nothing of it.
      if (set.origins[businessKindKey] != SettingOrigin.workspace) continue;
      final kind = set.read<String>(businessKindKey);
      if (kind.isNotEmpty) out[id] = kind;
    }
    return out;
  }
}
