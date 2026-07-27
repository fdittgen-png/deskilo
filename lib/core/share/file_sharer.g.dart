// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_sharer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileSharer)
final fileSharerProvider = FileSharerProvider._();

final class FileSharerProvider
    extends $FunctionalProvider<FileSharer, FileSharer, FileSharer>
    with $Provider<FileSharer> {
  FileSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSharerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSharerHash();

  @$internal
  @override
  $ProviderElement<FileSharer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileSharer create(Ref ref) {
    return fileSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSharer>(value),
    );
  }
}

String _$fileSharerHash() => r'8fc3ead61c08576f36aa8846ab0f75deb1c70ce6';
