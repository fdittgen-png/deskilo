// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_roles_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1528 — the roles a workspace defined itself.

@ProviderFor(workspaceRolesRepository)
final workspaceRolesRepositoryProvider = WorkspaceRolesRepositoryProvider._();

/// #1528 — the roles a workspace defined itself.

final class WorkspaceRolesRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceRolesRepository,
          WorkspaceRolesRepository,
          WorkspaceRolesRepository
        >
    with $Provider<WorkspaceRolesRepository> {
  /// #1528 — the roles a workspace defined itself.
  WorkspaceRolesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRolesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRolesRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceRolesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceRolesRepository create(Ref ref) {
    return workspaceRolesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceRolesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceRolesRepository>(value),
    );
  }
}

String _$workspaceRolesRepositoryHash() =>
    r'f48d591ea1dfe82f1685dd6caca34dcbff18a851';

/// The active workspace's own roles, or none while the feature is off.
///
/// The flag is read here rather than on each surface, so a space that
/// never turned it on makes no request at all.

@ProviderFor(workspaceRoles)
final workspaceRolesProvider = WorkspaceRolesProvider._();

/// The active workspace's own roles, or none while the feature is off.
///
/// The flag is read here rather than on each surface, so a space that
/// never turned it on makes no request at all.

final class WorkspaceRolesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceRole>>,
          List<WorkspaceRole>,
          FutureOr<List<WorkspaceRole>>
        >
    with
        $FutureModifier<List<WorkspaceRole>>,
        $FutureProvider<List<WorkspaceRole>> {
  /// The active workspace's own roles, or none while the feature is off.
  ///
  /// The flag is read here rather than on each surface, so a space that
  /// never turned it on makes no request at all.
  WorkspaceRolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRolesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRolesHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceRole>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceRole>> create(Ref ref) {
    return workspaceRoles(ref);
  }
}

String _$workspaceRolesHash() => r'48a5f3749b483f26205b1b1bf33ec39bf2aee6ad';

/// Who holds one role.

@ProviderFor(roleMembers)
final roleMembersProvider = RoleMembersFamily._();

/// Who holds one role.

final class RoleMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Who holds one role.
  RoleMembersProvider._({
    required RoleMembersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'roleMembersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roleMembersHash();

  @override
  String toString() {
    return r'roleMembersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return roleMembers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoleMembersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roleMembersHash() => r'e18b1db28cbb553ad462446c51503d744a83faeb';

/// Who holds one role.

final class RoleMembersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  RoleMembersFamily._()
    : super(
        retry: null,
        name: r'roleMembersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Who holds one role.

  RoleMembersProvider call(String roleId) =>
      RoleMembersProvider._(argument: roleId, from: this);

  @override
  String toString() => r'roleMembersProvider';
}
