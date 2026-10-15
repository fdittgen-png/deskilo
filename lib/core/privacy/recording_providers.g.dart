// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True while the workspace is showing invented people in place of its
/// own (#1514).

@ProviderFor(recordingPrivacy)
final recordingPrivacyProvider = RecordingPrivacyProvider._();

/// True while the workspace is showing invented people in place of its
/// own (#1514).

final class RecordingPrivacyProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True while the workspace is showing invented people in place of its
  /// own (#1514).
  RecordingPrivacyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingPrivacyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingPrivacyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return recordingPrivacy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$recordingPrivacyHash() => r'45bdc0b04d332abee5c4fbd667068d2840096215';
