// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_saver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Picks a
/// device-local directory: the app's external files dir on Android (visible
/// in a file manager, no runtime permission), the Downloads dir on
/// desktop/iOS, falling back to the app documents dir.

@ProviderFor(fileSaver)
final fileSaverProvider = FileSaverProvider._();

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Picks a
/// device-local directory: the app's external files dir on Android (visible
/// in a file manager, no runtime permission), the Downloads dir on
/// desktop/iOS, falling back to the app documents dir.

final class FileSaverProvider
    extends $FunctionalProvider<FileSaver, FileSaver, FileSaver>
    with $Provider<FileSaver> {
  /// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
  /// tests capture the write instead of touching the filesystem. Picks a
  /// device-local directory: the app's external files dir on Android (visible
  /// in a file manager, no runtime permission), the Downloads dir on
  /// desktop/iOS, falling back to the app documents dir.
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

String _$fileSaverHash() => r'b6e5d171c8caae899706a92ebe3547bb9581b821';
