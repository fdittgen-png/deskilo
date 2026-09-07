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
