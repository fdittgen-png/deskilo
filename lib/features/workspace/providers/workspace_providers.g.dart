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

/// The persisted active-profile choice (#89). Falls back to the first
/// workspace when nothing was chosen yet or the choice no longer exists.

@ProviderFor(ActiveWorkspaceId)
final activeWorkspaceIdProvider = ActiveWorkspaceIdProvider._();

/// The persisted active-profile choice (#89). Falls back to the first
/// workspace when nothing was chosen yet or the choice no longer exists.
final class ActiveWorkspaceIdProvider
    extends $AsyncNotifierProvider<ActiveWorkspaceId, String?> {
  /// The persisted active-profile choice (#89). Falls back to the first
  /// workspace when nothing was chosen yet or the choice no longer exists.
  ActiveWorkspaceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkspaceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkspaceIdHash();

  @$internal
  @override
  ActiveWorkspaceId create() => ActiveWorkspaceId();
}

String _$activeWorkspaceIdHash() => r'e8db64d6d579326d7abb53e0c19a98cb679ebc4f';

/// The persisted active-profile choice (#89). Falls back to the first
/// workspace when nothing was chosen yet or the choice no longer exists.

abstract class _$ActiveWorkspaceId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The active workspace (profile).

@ProviderFor(currentWorkspace)
final currentWorkspaceProvider = CurrentWorkspaceProvider._();

/// The active workspace (profile).

final class CurrentWorkspaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Workspace?>,
          Workspace?,
          FutureOr<Workspace?>
        >
    with $FutureModifier<Workspace?>, $FutureProvider<Workspace?> {
  /// The active workspace (profile).
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

String _$currentWorkspaceHash() => r'e6a8c0bd37a3bab95967196d4286dfc44dc132a6';

/// All my membership rows across workspaces — one per profile (#89).

@ProviderFor(myMemberships)
final myMembershipsProvider = MyMembershipsProvider._();

/// All my membership rows across workspaces — one per profile (#89).

final class MyMembershipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Member>>,
          List<Member>,
          FutureOr<List<Member>>
        >
    with $FutureModifier<List<Member>>, $FutureProvider<List<Member>> {
  /// All my membership rows across workspaces — one per profile (#89).
  MyMembershipsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMembershipsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMembershipsHash();

  @$internal
  @override
  $FutureProviderElement<List<Member>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Member>> create(Ref ref) {
    return myMemberships(ref);
  }
}

String _$myMembershipsHash() => r'addc53f1469bfa1a4b4c485af129c830dd2b49c2';

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
