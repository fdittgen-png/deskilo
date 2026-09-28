// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/profile/domain/personal_preferences.dart';

class FakePersonalPreferencesRepository implements PersonalPreferencesRepository {
  final Map<String, String> defaults = {};
  final Map<String, Map<String, String>> overrides = {};

  @override
  Future<PersonalPreferences> read({String? workspaceId}) async =>
      PersonalPreferences(defaults: defaults, overrides: overrides[workspaceId] ?? {});

  @override
  Future<void> patch(Map<String, String?> values, {String? workspaceId}) async {
    final target = workspaceId == null ? defaults : overrides.putIfAbsent(workspaceId, () => {});
    for (final entry in values.entries) {
      if (entry.value == null) { target.remove(entry.key); }
      else { target[entry.key] = entry.value!; }
    }
  }
}
