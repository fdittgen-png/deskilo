// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_host_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceHostRepository)
final workspaceHostRepositoryProvider = WorkspaceHostRepositoryProvider._();

final class WorkspaceHostRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceHostRepository,
          WorkspaceHostRepository,
          WorkspaceHostRepository
        >
    with $Provider<WorkspaceHostRepository> {
  WorkspaceHostRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceHostRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceHostRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceHostRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceHostRepository create(Ref ref) {
    return workspaceHostRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceHostRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceHostRepository>(value),
    );
  }
}

String _$workspaceHostRepositoryHash() =>
    r'd169a537be0821e3204ef4cc34f11717fae8e71f';

/// The hosts offered when the person creates a space. A failed read says
/// so (no retries stacked behind a spinner, #2339).

@ProviderFor(workspaceHosts)
final workspaceHostsProvider = WorkspaceHostsProvider._();

/// The hosts offered when the person creates a space. A failed read says
/// so (no retries stacked behind a spinner, #2339).

final class WorkspaceHostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkspaceHosts>,
          WorkspaceHosts,
          FutureOr<WorkspaceHosts>
        >
    with $FutureModifier<WorkspaceHosts>, $FutureProvider<WorkspaceHosts> {
  /// The hosts offered when the person creates a space. A failed read says
  /// so (no retries stacked behind a spinner, #2339).
  WorkspaceHostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noWorkspaceHostRetry,
        name: r'workspaceHostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceHostsHash();

  @$internal
  @override
  $FutureProviderElement<WorkspaceHosts> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkspaceHosts> create(Ref ref) {
    return workspaceHosts(ref);
  }
}

String _$workspaceHostsHash() => r'48d1349de43ba557f5a5117ee3a9932abee26e54';

/// The host the next creation runs on; none means this server. A choice
/// belongs to the session that made it, and its pinned client is given
/// back when it is replaced, cleared or the session changes.

@ProviderFor(CreationHost)
final creationHostProvider = CreationHostProvider._();

/// The host the next creation runs on; none means this server. A choice
/// belongs to the session that made it, and its pinned client is given
/// back when it is replaced, cleared or the session changes.
final class CreationHostProvider
    extends $NotifierProvider<CreationHost, CreationHostLease?> {
  /// The host the next creation runs on; none means this server. A choice
  /// belongs to the session that made it, and its pinned client is given
  /// back when it is replaced, cleared or the session changes.
  CreationHostProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creationHostProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creationHostHash();

  @$internal
  @override
  CreationHost create() => CreationHost();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreationHostLease? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreationHostLease?>(value),
    );
  }
}

String _$creationHostHash() => r'd87505b334e964ec7848b9280077521ac2a6e96a';

/// The host the next creation runs on; none means this server. A choice
/// belongs to the session that made it, and its pinned client is given
/// back when it is replaced, cleared or the session changes.

abstract class _$CreationHost extends $Notifier<CreationHostLease?> {
  CreationHostLease? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CreationHostLease?, CreationHostLease?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CreationHostLease?, CreationHostLease?>,
              CreationHostLease?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Checks a chosen host again and, when it may be used, makes it the
/// creation's.

@ProviderFor(createOnHost)
final createOnHostProvider = CreateOnHostProvider._();

/// Checks a chosen host again and, when it may be used, makes it the
/// creation's.

final class CreateOnHostProvider
    extends $FunctionalProvider<CreateOnHost, CreateOnHost, CreateOnHost>
    with $Provider<CreateOnHost> {
  /// Checks a chosen host again and, when it may be used, makes it the
  /// creation's.
  CreateOnHostProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createOnHostProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createOnHostHash();

  @$internal
  @override
  $ProviderElement<CreateOnHost> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreateOnHost create(Ref ref) {
    return createOnHost(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateOnHost value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateOnHost>(value),
    );
  }
}

String _$createOnHostHash() => r'8b179fac1dc8746fb14365882e434e30fdf37faf';
