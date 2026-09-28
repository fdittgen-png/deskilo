// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_preferences_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalPreferencesRepository)
final personalPreferencesRepositoryProvider =
    PersonalPreferencesRepositoryProvider._();

final class PersonalPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          PersonalPreferencesRepository,
          PersonalPreferencesRepository,
          PersonalPreferencesRepository
        >
    with $Provider<PersonalPreferencesRepository> {
  PersonalPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalPreferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalPreferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PersonalPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalPreferencesRepository create(Ref ref) {
    return personalPreferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalPreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalPreferencesRepository>(
        value,
      ),
    );
  }
}

String _$personalPreferencesRepositoryHash() =>
    r'ddc4049ac7e1b34aa0800e087d2c528236a1549a';

/// Editing defaults remains the initial behavior. An explicit, optional switch
/// scopes edits to this workspace; account/workspace changes reset that choice.

@ProviderFor(WorkspacePreferenceEditing)
final workspacePreferenceEditingProvider =
    WorkspacePreferenceEditingProvider._();

/// Editing defaults remains the initial behavior. An explicit, optional switch
/// scopes edits to this workspace; account/workspace changes reset that choice.
final class WorkspacePreferenceEditingProvider
    extends $NotifierProvider<WorkspacePreferenceEditing, bool> {
  /// Editing defaults remains the initial behavior. An explicit, optional switch
  /// scopes edits to this workspace; account/workspace changes reset that choice.
  WorkspacePreferenceEditingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspacePreferenceEditingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspacePreferenceEditingHash();

  @$internal
  @override
  WorkspacePreferenceEditing create() => WorkspacePreferenceEditing();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$workspacePreferenceEditingHash() =>
    r'382ad2a7ceda5753ab7bcaaaf023720ea13ea0e8';

/// Editing defaults remains the initial behavior. An explicit, optional switch
/// scopes edits to this workspace; account/workspace changes reset that choice.

abstract class _$WorkspacePreferenceEditing extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PersonalSettings)
final personalSettingsProvider = PersonalSettingsProvider._();

final class PersonalSettingsProvider
    extends $AsyncNotifierProvider<PersonalSettings, PersonalPreferences> {
  PersonalSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalSettingsHash();

  @$internal
  @override
  PersonalSettings create() => PersonalSettings();
}

String _$personalSettingsHash() => r'33239c53ef08f1cca97f7d309e10e9396a4ecf65';

abstract class _$PersonalSettings extends $AsyncNotifier<PersonalPreferences> {
  FutureOr<PersonalPreferences> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PersonalPreferences>, PersonalPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PersonalPreferences>, PersonalPreferences>,
              AsyncValue<PersonalPreferences>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
