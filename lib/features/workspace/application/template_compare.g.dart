// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_compare.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The rows comparing [templateIds] (comma-joined, in shortlist order).

@ProviderFor(templateComparison)
final templateComparisonProvider = TemplateComparisonFamily._();

/// The rows comparing [templateIds] (comma-joined, in shortlist order).

final class TemplateComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComparisonRow>>,
          List<ComparisonRow>,
          FutureOr<List<ComparisonRow>>
        >
    with
        $FutureModifier<List<ComparisonRow>>,
        $FutureProvider<List<ComparisonRow>> {
  /// The rows comparing [templateIds] (comma-joined, in shortlist order).
  TemplateComparisonProvider._({
    required TemplateComparisonFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateComparisonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateComparisonHash();

  @override
  String toString() {
    return r'templateComparisonProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ComparisonRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ComparisonRow>> create(Ref ref) {
    final argument = this.argument as String;
    return templateComparison(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateComparisonProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateComparisonHash() =>
    r'23941f68aba7a5f870a0c82f539ecb03ad65ca23';

/// The rows comparing [templateIds] (comma-joined, in shortlist order).

final class TemplateComparisonFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ComparisonRow>>, String> {
  TemplateComparisonFamily._()
    : super(
        retry: null,
        name: r'templateComparisonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The rows comparing [templateIds] (comma-joined, in shortlist order).

  TemplateComparisonProvider call(String templateIds) =>
      TemplateComparisonProvider._(argument: templateIds, from: this);

  @override
  String toString() => r'templateComparisonProvider';
}

/// #1660 — one template's inspection, for its detail screen.

@ProviderFor(templateInspection)
final templateInspectionProvider = TemplateInspectionFamily._();

/// #1660 — one template's inspection, for its detail screen.

final class TemplateInspectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<TemplateInspection>,
          TemplateInspection,
          FutureOr<TemplateInspection>
        >
    with
        $FutureModifier<TemplateInspection>,
        $FutureProvider<TemplateInspection> {
  /// #1660 — one template's inspection, for its detail screen.
  TemplateInspectionProvider._({
    required TemplateInspectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateInspectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateInspectionHash();

  @override
  String toString() {
    return r'templateInspectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TemplateInspection> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TemplateInspection> create(Ref ref) {
    final argument = this.argument as String;
    return templateInspection(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateInspectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateInspectionHash() =>
    r'727f176221a729582173c46b285c40ce904f6ecb';

/// #1660 — one template's inspection, for its detail screen.

final class TemplateInspectionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TemplateInspection>, String> {
  TemplateInspectionFamily._()
    : super(
        retry: null,
        name: r'templateInspectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1660 — one template's inspection, for its detail screen.

  TemplateInspectionProvider call(String templateId) =>
      TemplateInspectionProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateInspectionProvider';
}

/// #1661 — the workbook export of a shortlist.

@ProviderFor(templateWorkbookExport)
final templateWorkbookExportProvider = TemplateWorkbookExportProvider._();

/// #1661 — the workbook export of a shortlist.

final class TemplateWorkbookExportProvider
    extends
        $FunctionalProvider<
          TemplateWorkbookExport,
          TemplateWorkbookExport,
          TemplateWorkbookExport
        >
    with $Provider<TemplateWorkbookExport> {
  /// #1661 — the workbook export of a shortlist.
  TemplateWorkbookExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateWorkbookExportProvider',
        isAutoDispose: true,
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
    r'11dad0f8e111149762c4ec7e1008461c9d8d9b7b';
