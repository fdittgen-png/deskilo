// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nfc_uid_reader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable seam so widget tests drive taps without NFC hardware.

@ProviderFor(nfcUidReader)
final nfcUidReaderProvider = NfcUidReaderProvider._();

/// Injectable seam so widget tests drive taps without NFC hardware.

final class NfcUidReaderProvider
    extends $FunctionalProvider<NfcUidReader, NfcUidReader, NfcUidReader>
    with $Provider<NfcUidReader> {
  /// Injectable seam so widget tests drive taps without NFC hardware.
  NfcUidReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nfcUidReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nfcUidReaderHash();

  @$internal
  @override
  $ProviderElement<NfcUidReader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NfcUidReader create(Ref ref) {
    return nfcUidReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NfcUidReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NfcUidReader>(value),
    );
  }
}

String _$nfcUidReaderHash() => r'821024f7d55806118405ba841363041735485ff1';
