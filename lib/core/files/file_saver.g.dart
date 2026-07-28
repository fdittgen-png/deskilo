// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_saver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem.
///
/// Which implementation answers depends on where the app runs: on a device
/// the export lands in the user's Downloads (MediaStore on Android, the
/// Downloads directory elsewhere); in a browser it goes through the
/// download machinery, since a page has no folder to write to. Both return
/// a handle the UI can name in a snackbar.

@ProviderFor(fileSaver)
final fileSaverProvider = FileSaverProvider._();

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem.
///
/// Which implementation answers depends on where the app runs: on a device
/// the export lands in the user's Downloads (MediaStore on Android, the
/// Downloads directory elsewhere); in a browser it goes through the
/// download machinery, since a page has no folder to write to. Both return
/// a handle the UI can name in a snackbar.

final class FileSaverProvider
    extends $FunctionalProvider<FileSaver, FileSaver, FileSaver>
    with $Provider<FileSaver> {
  /// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
  /// tests capture the write instead of touching the filesystem.
  ///
  /// Which implementation answers depends on where the app runs: on a device
  /// the export lands in the user's Downloads (MediaStore on Android, the
  /// Downloads directory elsewhere); in a browser it goes through the
  /// download machinery, since a page has no folder to write to. Both return
  /// a handle the UI can name in a snackbar.
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

String _$fileSaverHash() => r'607a5d2bab40420d0f9ff46a41cc2ef4eed2c382';
