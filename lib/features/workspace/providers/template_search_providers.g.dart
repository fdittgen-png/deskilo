// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1659 — the server's paged template search (0283).

@ProviderFor(templateSearchRepository)
final templateSearchRepositoryProvider = TemplateSearchRepositoryProvider._();

/// #1659 — the server's paged template search (0283).

final class TemplateSearchRepositoryProvider
    extends
        $FunctionalProvider<
          TemplateSearchRepository,
          TemplateSearchRepository,
          TemplateSearchRepository
        >
    with $Provider<TemplateSearchRepository> {
  /// #1659 — the server's paged template search (0283).
  TemplateSearchRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateSearchRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateSearchRepositoryHash();

  @$internal
  @override
  $ProviderElement<TemplateSearchRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TemplateSearchRepository create(Ref ref) {
    return templateSearchRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateSearchRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateSearchRepository>(value),
    );
  }
}

String _$templateSearchRepositoryHash() =>
    r'7f5c7e498cba598df99d35aac57df1efcf736489';
