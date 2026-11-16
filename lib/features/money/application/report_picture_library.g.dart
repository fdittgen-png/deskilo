// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_picture_library.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The picture library's writes.

@ProviderFor(reportPictureLibrary)
final reportPictureLibraryProvider = ReportPictureLibraryProvider._();

/// The picture library's writes.

final class ReportPictureLibraryProvider
    extends
        $FunctionalProvider<
          ReportPictureLibrary,
          ReportPictureLibrary,
          ReportPictureLibrary
        >
    with $Provider<ReportPictureLibrary> {
  /// The picture library's writes.
  ReportPictureLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportPictureLibraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportPictureLibraryHash();

  @$internal
  @override
  $ProviderElement<ReportPictureLibrary> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReportPictureLibrary create(Ref ref) {
    return reportPictureLibrary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportPictureLibrary value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportPictureLibrary>(value),
    );
  }
}

String _$reportPictureLibraryHash() =>
    r'42109f2524aa4620fef929eb434ecd4d232ae4c5';
