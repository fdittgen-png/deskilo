// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desk_frame.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The router navigator's window watch, one per app.

@ProviderFor(deskModalObserver)
final deskModalObserverProvider = DeskModalObserverProvider._();

/// The router navigator's window watch, one per app.

final class DeskModalObserverProvider
    extends
        $FunctionalProvider<
          DeskModalObserver,
          DeskModalObserver,
          DeskModalObserver
        >
    with $Provider<DeskModalObserver> {
  /// The router navigator's window watch, one per app.
  DeskModalObserverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deskModalObserverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deskModalObserverHash();

  @$internal
  @override
  $ProviderElement<DeskModalObserver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeskModalObserver create(Ref ref) {
    return deskModalObserver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeskModalObserver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeskModalObserver>(value),
    );
  }
}

String _$deskModalObserverHash() => r'e1363dbadf18a66a2e04f81bcbf8819486f085d3';
