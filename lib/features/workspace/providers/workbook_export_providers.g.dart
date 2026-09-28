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
    r'b8aa93c48babf1101f86fd02567f9f9eec7d349f';

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
