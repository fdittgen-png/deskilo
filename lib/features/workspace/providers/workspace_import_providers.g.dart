// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_import_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owner-only XML import boundary (#165); own file so the parallel
/// workspace features never contend on workspace_providers.dart.

@ProviderFor(workspaceImportRepository)
final workspaceImportRepositoryProvider = WorkspaceImportRepositoryProvider._();

/// Owner-only XML import boundary (#165); own file so the parallel
/// workspace features never contend on workspace_providers.dart.

final class WorkspaceImportRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceImportRepository,
          WorkspaceImportRepository,
          WorkspaceImportRepository
        >
    with $Provider<WorkspaceImportRepository> {
  /// Owner-only XML import boundary (#165); own file so the parallel
  /// workspace features never contend on workspace_providers.dart.
  WorkspaceImportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceImportRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceImportRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceImportRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceImportRepository create(Ref ref) {
    return workspaceImportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceImportRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceImportRepository>(value),
    );
  }
}

String _$workspaceImportRepositoryHash() =>
    r'0a5054866b0baf108c712e3994ee9e8a34e5b2e1';
