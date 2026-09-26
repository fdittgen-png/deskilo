// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(templateSearch)
final templateSearchProvider = TemplateSearchProvider._();

final class TemplateSearchProvider
    extends $FunctionalProvider<TemplateSearch, TemplateSearch, TemplateSearch>
    with $Provider<TemplateSearch> {
  TemplateSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateSearchHash();

  @$internal
  @override
  $ProviderElement<TemplateSearch> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TemplateSearch create(Ref ref) {
    return templateSearch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateSearch value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateSearch>(value),
    );
  }
}

String _$templateSearchHash() => r'4bdefa2e6385763c8ba5faf631d0aacb9cdf062b';
