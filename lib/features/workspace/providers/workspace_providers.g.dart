// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceRepository,
          WorkspaceRepository,
          WorkspaceRepository
        >
    with $Provider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceRepository create(Ref ref) {
    return workspaceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceRepository>(value),
    );
  }
}

String _$workspaceRepositoryHash() =>
    r'e68d1435a2549d439fd19d30e8249162f7849608';

@ProviderFor(myWorkspaces)
final myWorkspacesProvider = MyWorkspacesProvider._();

final class MyWorkspacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Workspace>>,
          List<Workspace>,
          FutureOr<List<Workspace>>
        >
    with $FutureModifier<List<Workspace>>, $FutureProvider<List<Workspace>> {
  MyWorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myWorkspacesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myWorkspacesHash();

  @$internal
  @override
  $FutureProviderElement<List<Workspace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Workspace>> create(Ref ref) {
    return myWorkspaces(ref);
  }
}

String _$myWorkspacesHash() => r'198c8d5a8c8478df79f3177df2af39d009d2c760';

/// The active workspace. Multi-workspace switching arrives later; until
/// then the first (usually only) workspace is active (spec §2).

@ProviderFor(currentWorkspace)
final currentWorkspaceProvider = CurrentWorkspaceProvider._();

/// The active workspace. Multi-workspace switching arrives later; until
/// then the first (usually only) workspace is active (spec §2).

final class CurrentWorkspaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Workspace?>,
          Workspace?,
          FutureOr<Workspace?>
        >
    with $FutureModifier<Workspace?>, $FutureProvider<Workspace?> {
  /// The active workspace. Multi-workspace switching arrives later; until
  /// then the first (usually only) workspace is active (spec §2).
  CurrentWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWorkspaceHash();

  @$internal
  @override
  $FutureProviderElement<Workspace?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Workspace?> create(Ref ref) {
    return currentWorkspace(ref);
  }
}

String _$currentWorkspaceHash() => r'2988c05a34c9464c47e9d1e7b4246d44a46021a8';

/// The signed-in user's membership (roles!) in the active workspace.

@ProviderFor(myMember)
final myMemberProvider = MyMemberProvider._();

/// The signed-in user's membership (roles!) in the active workspace.

final class MyMemberProvider
    extends $FunctionalProvider<AsyncValue<Member?>, Member?, FutureOr<Member?>>
    with $FutureModifier<Member?>, $FutureProvider<Member?> {
  /// The signed-in user's membership (roles!) in the active workspace.
  MyMemberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMemberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMemberHash();

  @$internal
  @override
  $FutureProviderElement<Member?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Member?> create(Ref ref) {
    return myMember(ref);
  }
}

String _$myMemberHash() => r'4490381a6cf73ba9a3eb496d8d705538aaddcc41';
