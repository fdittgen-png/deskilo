// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workbook_export_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workbookOriginRepository)
final workbookOriginRepositoryProvider = WorkbookOriginRepositoryProvider._();

final class WorkbookOriginRepositoryProvider
    extends
        $FunctionalProvider<
          WorkbookOriginRepository,
          WorkbookOriginRepository,
          WorkbookOriginRepository
        >
    with $Provider<WorkbookOriginRepository> {
  WorkbookOriginRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workbookOriginRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workbookOriginRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkbookOriginRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkbookOriginRepository create(Ref ref) {
    return workbookOriginRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkbookOriginRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkbookOriginRepository>(value),
    );
  }
}

String _$workbookOriginRepositoryHash() =>
    r'411ac026e5bd1acaccefa5dff85997c4aa873d59';

/// Keep an imperative export alive without widget listeners, but invalidate
/// it permanently when its account or repository changes, including A→B→A.

@ProviderFor(templateWorkbookExport)
final templateWorkbookExportProvider = TemplateWorkbookExportProvider._();

/// Keep an imperative export alive without widget listeners, but invalidate
/// it permanently when its account or repository changes, including A→B→A.

final class TemplateWorkbookExportProvider
    extends
        $FunctionalProvider<
          TemplateWorkbookExport,
          TemplateWorkbookExport,
          TemplateWorkbookExport
        >
    with $Provider<TemplateWorkbookExport> {
  /// Keep an imperative export alive without widget listeners, but invalidate
  /// it permanently when its account or repository changes, including A→B→A.
  TemplateWorkbookExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateWorkbookExportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateWorkbookExportHash();

  @$internal
  @override
  $ProviderElement<TemplateWorkbookExport> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TemplateWorkbookExport create(Ref ref) {
    return templateWorkbookExport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateWorkbookExport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateWorkbookExport>(value),
    );
  }
}

String _$templateWorkbookExportHash() =>
    r'53c84b9b45510c310474a9f8814875714e51d916';

/// #2581 — the export read of a report's figures.

@ProviderFor(biExportRepository)
final biExportRepositoryProvider = BiExportRepositoryProvider._();

/// #2581 — the export read of a report's figures.

final class BiExportRepositoryProvider
    extends
        $FunctionalProvider<
          BiExportRepository,
          BiExportRepository,
          BiExportRepository
        >
    with $Provider<BiExportRepository> {
  /// #2581 — the export read of a report's figures.
  BiExportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biExportRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biExportRepositoryHash();

  @$internal
  @override
  $ProviderElement<BiExportRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BiExportRepository create(Ref ref) {
    return biExportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiExportRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiExportRepository>(value),
    );
  }
}

String _$biExportRepositoryHash() =>
    r'6fe018f6c1907f43e311b9af6dbca430ccfcedd0';

/// #2581 — one export's snapshot, dropped when its account is no longer the
/// one signed in (the same fence as the template workbook's).

@ProviderFor(biSnapshotExport)
final biSnapshotExportProvider = BiSnapshotExportProvider._();

/// #2581 — one export's snapshot, dropped when its account is no longer the
/// one signed in (the same fence as the template workbook's).

final class BiSnapshotExportProvider
    extends
        $FunctionalProvider<
          BiSnapshotExport,
          BiSnapshotExport,
          BiSnapshotExport
        >
    with $Provider<BiSnapshotExport> {
  /// #2581 — one export's snapshot, dropped when its account is no longer the
  /// one signed in (the same fence as the template workbook's).
  BiSnapshotExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biSnapshotExportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biSnapshotExportHash();

  @$internal
  @override
  $ProviderElement<BiSnapshotExport> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiSnapshotExport create(Ref ref) {
    return biSnapshotExport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiSnapshotExport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiSnapshotExport>(value),
    );
  }
}

String _$biSnapshotExportHash() => r'11dce8fdcc9fa1e58aedc9eb301c7c73c2fd30cb';
