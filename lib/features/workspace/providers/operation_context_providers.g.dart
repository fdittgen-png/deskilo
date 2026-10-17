// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_context_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Who is signed in at the personal home, or null when nobody is.

@ProviderFor(personalContext)
final personalContextProvider = PersonalContextProvider._();

/// Who is signed in at the personal home, or null when nobody is.

final class PersonalContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersonalContext?>,
          PersonalContext?,
          FutureOr<PersonalContext?>
        >
    with $FutureModifier<PersonalContext?>, $FutureProvider<PersonalContext?> {
  /// Who is signed in at the personal home, or null when nobody is.
  PersonalContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalContextHash();

  @$internal
  @override
  $FutureProviderElement<PersonalContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersonalContext?> create(Ref ref) {
    return personalContext(ref);
  }
}

String _$personalContextHash() => r'a553c3de390357ee6d095aad96353e6bd4aad92c';

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings and time zone. Null while
/// nobody is signed in or no workspace is selected.

@ProviderFor(workspaceContext)
final workspaceContextProvider = WorkspaceContextProvider._();

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings and time zone. Null while
/// nobody is signed in or no workspace is selected.

final class WorkspaceContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkspaceContext?>,
          WorkspaceContext?,
          FutureOr<WorkspaceContext?>
        >
    with
        $FutureModifier<WorkspaceContext?>,
        $FutureProvider<WorkspaceContext?> {
  /// The context of the selected workspace, captured whole: person, verified
  /// target, local account, both epochs, settings and time zone. Null while
  /// nobody is signed in or no workspace is selected.
  WorkspaceContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceContextHash();

  @$internal
  @override
  $FutureProviderElement<WorkspaceContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkspaceContext?> create(Ref ref) {
    return workspaceContext(ref);
  }
}

String _$workspaceContextHash() => r'ad885bd3716d4d96960045defdc542ed5226f76e';

/// #2564 O1 -- the client the selected workspace's operations run on: the
/// verified host client of the captured [WorkspaceContext]'s installation.
/// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
/// selected, still resolving) it is the root client -- the combined
/// deployment's one installation, where the two are the same object; a split
/// deployment's resolver (#2562) never yields the root client for a W target.

@ProviderFor(selectedWorkspaceClient)
final selectedWorkspaceClientProvider = SelectedWorkspaceClientProvider._();

/// #2564 O1 -- the client the selected workspace's operations run on: the
/// verified host client of the captured [WorkspaceContext]'s installation.
/// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
/// selected, still resolving) it is the root client -- the combined
/// deployment's one installation, where the two are the same object; a split
/// deployment's resolver (#2562) never yields the root client for a W target.

final class SelectedWorkspaceClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  /// #2564 O1 -- the client the selected workspace's operations run on: the
  /// verified host client of the captured [WorkspaceContext]'s installation.
  /// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
  /// selected, still resolving) it is the root client -- the combined
  /// deployment's one installation, where the two are the same object; a split
  /// deployment's resolver (#2562) never yields the root client for a W target.
  SelectedWorkspaceClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedWorkspaceClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedWorkspaceClientHash();

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    return selectedWorkspaceClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }
}

String _$selectedWorkspaceClientHash() =>
    r'15bbe315c2cb0542bf76d97d443e1a81cf8b3c81';
