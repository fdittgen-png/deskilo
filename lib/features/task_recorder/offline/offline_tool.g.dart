// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_tool.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineTool)
final offlineToolProvider = OfflineToolProvider._();

final class OfflineToolProvider
    extends $FunctionalProvider<OfflineTool, OfflineTool, OfflineTool>
    with $Provider<OfflineTool> {
  OfflineToolProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineToolProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineToolHash();

  @$internal
  @override
  $ProviderElement<OfflineTool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OfflineTool create(Ref ref) {
    return offlineTool(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineTool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineTool>(value),
    );
  }
}

String _$offlineToolHash() => r'66a8a686cb1114cb32dcb81fe914b36b6ccf3ea5';
