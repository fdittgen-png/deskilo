// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_scan_widget.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(qrScanWidgetBuilder)
final qrScanWidgetBuilderProvider = QrScanWidgetBuilderProvider._();

final class QrScanWidgetBuilderProvider
    extends
        $FunctionalProvider<
          QrScanWidgetBuilder,
          QrScanWidgetBuilder,
          QrScanWidgetBuilder
        >
    with $Provider<QrScanWidgetBuilder> {
  QrScanWidgetBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrScanWidgetBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrScanWidgetBuilderHash();

  @$internal
  @override
  $ProviderElement<QrScanWidgetBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  QrScanWidgetBuilder create(Ref ref) {
    return qrScanWidgetBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrScanWidgetBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrScanWidgetBuilder>(value),
    );
  }
}

String _$qrScanWidgetBuilderHash() =>
    r'295132976ac27b171026105f274300fcefc39476';
