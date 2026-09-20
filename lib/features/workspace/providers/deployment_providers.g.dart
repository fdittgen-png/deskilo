// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #988 — the deployment boundary; its own file so the pair features
/// never contend on workspace_providers.dart.

@ProviderFor(deploymentRepository)
final deploymentRepositoryProvider = DeploymentRepositoryProvider._();

/// #988 — the deployment boundary; its own file so the pair features
/// never contend on workspace_providers.dart.

final class DeploymentRepositoryProvider
    extends
        $FunctionalProvider<
          DeploymentRepository,
          DeploymentRepository,
          DeploymentRepository
        >
    with $Provider<DeploymentRepository> {
  /// #988 — the deployment boundary; its own file so the pair features
  /// never contend on workspace_providers.dart.
  DeploymentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deploymentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deploymentRepositoryHash();

  @$internal
  @override
  $ProviderElement<DeploymentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeploymentRepository create(Ref ref) {
    return deploymentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeploymentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeploymentRepository>(value),
    );
  }
}

String _$deploymentRepositoryHash() =>
    r'1481d14e5696b8eeeed8910ebf3e2b352261f087';

/// #1449 — the deployment's own decisions: the closed selection, and a
/// deploy that can only write what a preview described.

@ProviderFor(deployments)
final deploymentsProvider = DeploymentsProvider._();

/// #1449 — the deployment's own decisions: the closed selection, and a
/// deploy that can only write what a preview described.

final class DeploymentsProvider
    extends $FunctionalProvider<Deployments, Deployments, Deployments>
    with $Provider<Deployments> {
  /// #1449 — the deployment's own decisions: the closed selection, and a
  /// deploy that can only write what a preview described.
  DeploymentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deploymentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deploymentsHash();

  @$internal
  @override
  $ProviderElement<Deployments> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Deployments create(Ref ref) {
    return deployments(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Deployments value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Deployments>(value),
    );
  }
}

String _$deploymentsHash() => r'5d5e2536568d6a585b0dc71d05f72d90639a1941';
