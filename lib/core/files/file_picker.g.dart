// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_picker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable seam over `file_selector`'s [openFile] so widget tests can
/// hand the flow a canned file — the same pattern [shareLauncher] uses
/// for the share sheet (#133). file_selector rides the Storage Access
/// Framework on Android: GMS-free, F-Droid clean.

@ProviderFor(filePicker)
final filePickerProvider = FilePickerProvider._();

/// Injectable seam over `file_selector`'s [openFile] so widget tests can
/// hand the flow a canned file — the same pattern [shareLauncher] uses
/// for the share sheet (#133). file_selector rides the Storage Access
/// Framework on Android: GMS-free, F-Droid clean.

final class FilePickerProvider
    extends $FunctionalProvider<FilePicker, FilePicker, FilePicker>
    with $Provider<FilePicker> {
  /// Injectable seam over `file_selector`'s [openFile] so widget tests can
  /// hand the flow a canned file — the same pattern [shareLauncher] uses
  /// for the share sheet (#133). file_selector rides the Storage Access
  /// Framework on Android: GMS-free, F-Droid clean.
  FilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filePickerHash();

  @$internal
  @override
  $ProviderElement<FilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FilePicker create(Ref ref) {
    return filePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilePicker>(value),
    );
  }
}

String _$filePickerHash() => r'1cc248cf347ecc0e13fe9059a4860ff841d583fb';
