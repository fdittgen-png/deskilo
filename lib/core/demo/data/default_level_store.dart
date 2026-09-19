// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/plan/providers/default_level_controller.dart';

/// In-memory [DefaultLevelStore] so tests never touch SharedPreferences
/// platform channels (fakes over mocks).
class InMemoryDefaultLevelStore implements DefaultLevelStore {
  /// workspaceId → stored level id.
  final values = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String workspaceId) async => values[workspaceId];

  @override
  Future<void> write(String workspaceId, String levelId) async {
    values[workspaceId] = levelId;
    writes++;
  }
}
