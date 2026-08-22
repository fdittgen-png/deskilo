// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(realtimeSync)
final realtimeSyncProvider = RealtimeSyncProvider._();

final class RealtimeSyncProvider
    extends $FunctionalProvider<RealtimeSync, RealtimeSync, RealtimeSync>
    with $Provider<RealtimeSync> {
  RealtimeSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeSyncHash();

  @$internal
  @override
  $ProviderElement<RealtimeSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RealtimeSync create(Ref ref) {
    return realtimeSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RealtimeSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RealtimeSync>(value),
    );
  }
}

String _$realtimeSyncHash() => r'15e9454f53dadd2fbc6739919a737ca3d8b855ca';

/// Subscribes to the active workspace's change feed and invalidates
/// exactly the providers that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.

@ProviderFor(RealtimeInvalidator)
final realtimeInvalidatorProvider = RealtimeInvalidatorProvider._();

/// Subscribes to the active workspace's change feed and invalidates
/// exactly the providers that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.
final class RealtimeInvalidatorProvider
    extends $AsyncNotifierProvider<RealtimeInvalidator, void> {
  /// Subscribes to the active workspace's change feed and invalidates
  /// exactly the providers that cache each table — so every device,
  /// INCLUDING the one that made the change, repaints without restarts or
  /// manual refreshes (#413). Watched from the shell and the kiosk, alive
  /// with the app. The table → providers map lives in
  /// [invalidationFor] (#577) and is shared with the manual mutation path.
  RealtimeInvalidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeInvalidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeInvalidatorHash();

  @$internal
  @override
  RealtimeInvalidator create() => RealtimeInvalidator();
}

String _$realtimeInvalidatorHash() =>
    r'0c3a01b59453ec001342af82f5b4677fca2557ae';

/// Subscribes to the active workspace's change feed and invalidates
/// exactly the providers that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.

abstract class _$RealtimeInvalidator extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
