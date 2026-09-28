// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_personal_preferences_repository.dart';
import '../domain/personal_preferences.dart';
import 'profile_providers.dart';

part 'personal_preferences_providers.g.dart';

@Riverpod(keepAlive: true)
PersonalPreferencesRepository personalPreferencesRepository(Ref ref) =>
    SupabasePersonalPreferencesRepository(Supabase.instance.client);

/// Editing defaults remains the initial behavior. An explicit, optional switch
/// scopes edits to this workspace; account/workspace changes reset that choice.
@Riverpod(keepAlive: true)
class WorkspacePreferenceEditing extends _$WorkspacePreferenceEditing {
  @override
  bool build() {
    ref.watch(personalPreferenceContextProvider);
    return false;
  }
  void set(bool value) => state = value;
}

@Riverpod(keepAlive: true)
class PersonalSettings extends _$PersonalSettings {
  String? _account;
  String? _workspace;

  @override
  Future<PersonalPreferences> build() {
    final context = ref.watch(personalPreferenceContextProvider);
    _account = context.account;
    _workspace = context.workspace;
    if (_account == null) return Future.value(PersonalPreferences());
    return ref.watch(personalPreferencesRepositoryProvider).read(workspaceId: _workspace);
  }

  Future<void> save(Map<String, String?> patch, {bool? workspaceOnly}) async {
    final account = _account;
    final workspace = _workspace;
    if (account == null) throw StateError('not signed in');
    final bool scoped = workspaceOnly ?? ref.read(workspacePreferenceEditingProvider);
    if (scoped && workspace == null) throw StateError('workspace unavailable');
    final repository = ref.read(personalPreferencesRepositoryProvider);
    await repository.patch(patch, workspaceId: scoped ? workspace : null);
    // A completion for an old context cannot invalidate the new person's data.
    if (!ref.mounted || account != _account || workspace != _workspace) return;
    ref.invalidateSelf();
    invalidatePersonalPreferenceConsumers(ref);
  }

  Future<void> resetWorkspace() => save(
    {for (final key in PersonalPreference.keys) key: null}, workspaceOnly: true);
}
