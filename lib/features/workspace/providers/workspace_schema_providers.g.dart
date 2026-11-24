// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_schema_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the installation hosting the current workspace answered, or null
/// while there is no workspace or nothing answered yet.

@ProviderFor(currentWorkspaceInstallationSchema)
final currentWorkspaceInstallationSchemaProvider =
    CurrentWorkspaceInstallationSchemaProvider._();

/// What the installation hosting the current workspace answered, or null
/// while there is no workspace or nothing answered yet.

final class CurrentWorkspaceInstallationSchemaProvider
    extends
        $FunctionalProvider<
          InstallationSchema?,
          InstallationSchema?,
          InstallationSchema?
        >
    with $Provider<InstallationSchema?> {
  /// What the installation hosting the current workspace answered, or null
  /// while there is no workspace or nothing answered yet.
  CurrentWorkspaceInstallationSchemaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceInstallationSchemaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$currentWorkspaceInstallationSchemaHash();

  @$internal
  @override
  $ProviderElement<InstallationSchema?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallationSchema? create(Ref ref) {
    return currentWorkspaceInstallationSchema(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallationSchema? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallationSchema?>(value),
    );
  }
}

String _$currentWorkspaceInstallationSchemaHash() =>
    r'3b613cd7a37828d0ada65237008dc79b141f2346';

/// The number a feature's `since` is compared with: null when it is not
/// established.

@ProviderFor(currentWorkspaceSchema)
final currentWorkspaceSchemaProvider = CurrentWorkspaceSchemaProvider._();

/// The number a feature's `since` is compared with: null when it is not
/// established.

final class CurrentWorkspaceSchemaProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// The number a feature's `since` is compared with: null when it is not
  /// established.
  CurrentWorkspaceSchemaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceSchemaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWorkspaceSchemaHash();

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    return currentWorkspaceSchema(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$currentWorkspaceSchemaHash() =>
    r'9a3e79d275a67412ff9fae4b0d1e580bb016222e';
