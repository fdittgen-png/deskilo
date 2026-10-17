// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_files_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1310 — the workspace's stored files, for the export.

@ProviderFor(workspaceFilesRepository)
final workspaceFilesRepositoryProvider = WorkspaceFilesRepositoryProvider._();

/// #1310 — the workspace's stored files, for the export.

final class WorkspaceFilesRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceFilesRepository,
          WorkspaceFilesRepository,
          WorkspaceFilesRepository
        >
    with $Provider<WorkspaceFilesRepository> {
  /// #1310 — the workspace's stored files, for the export.
  WorkspaceFilesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceFilesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceFilesRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceFilesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceFilesRepository create(Ref ref) {
    return workspaceFilesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceFilesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceFilesRepository>(value),
    );
  }
}

String _$workspaceFilesRepositoryHash() =>
    r'd2fd29dad1f033c480aaa43cbee52cc3cd42d72b';
