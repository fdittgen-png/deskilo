// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_saver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Every export
/// lands in the user's DOWNLOADS: Android via the MediaStore channel,
/// desktop/iOS via the Downloads directory, falling back to app storage.

@ProviderFor(fileSaver)
final fileSaverProvider = FileSaverProvider._();

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Every export
/// lands in the user's DOWNLOADS: Android via the MediaStore channel,
/// desktop/iOS via the Downloads directory, falling back to app storage.

final class FileSaverProvider
    extends $FunctionalProvider<FileSaver, FileSaver, FileSaver>
    with $Provider<FileSaver> {
  /// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
  /// tests capture the write instead of touching the filesystem. Every export
  /// lands in the user's DOWNLOADS: Android via the MediaStore channel,
  /// desktop/iOS via the Downloads directory, falling back to app storage.
  FileSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSaverHash();

  @$internal
  @override
  $ProviderElement<FileSaver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileSaver create(Ref ref) {
    return fileSaver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSaver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSaver>(value),
    );
  }
}

String _$fileSaverHash() => r'464b62cf65f5cda05a2b8a92270340b30422b310';
