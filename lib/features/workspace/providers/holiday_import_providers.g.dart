// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holiday_import_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(holidaySource)
final holidaySourceProvider = HolidaySourceProvider._();

final class HolidaySourceProvider
    extends $FunctionalProvider<HolidaySource, HolidaySource, HolidaySource>
    with $Provider<HolidaySource> {
  HolidaySourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'holidaySourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$holidaySourceHash();

  @$internal
  @override
  $ProviderElement<HolidaySource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HolidaySource create(Ref ref) {
    return holidaySource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HolidaySource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HolidaySource>(value),
    );
  }
}

String _$holidaySourceHash() => r'd3613efe04b575a381ef5ba54285dcaca1a4a2b1';

/// The import decision the sheet is handed (ADR 0024): the source and the
/// repository, resolved here rather than in a widget.

@ProviderFor(publicHolidayImport)
final publicHolidayImportProvider = PublicHolidayImportProvider._();

/// The import decision the sheet is handed (ADR 0024): the source and the
/// repository, resolved here rather than in a widget.

final class PublicHolidayImportProvider
    extends
        $FunctionalProvider<
          PublicHolidayImport,
          PublicHolidayImport,
          PublicHolidayImport
        >
    with $Provider<PublicHolidayImport> {
  /// The import decision the sheet is handed (ADR 0024): the source and the
  /// repository, resolved here rather than in a widget.
  PublicHolidayImportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicHolidayImportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicHolidayImportHash();

  @$internal
  @override
  $ProviderElement<PublicHolidayImport> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PublicHolidayImport create(Ref ref) {
    return publicHolidayImport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublicHolidayImport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublicHolidayImport>(value),
    );
  }
}

String _$publicHolidayImportHash() =>
    r'5087722e3db477eebf1a7abe31aacd3c85c79b6d';
