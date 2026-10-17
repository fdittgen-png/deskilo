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

String _$realtimeSyncHash() => r'28506283d0993cd2e85a83ccf4fef9583c8303b1';

/// #2564 O5 — the account target's feed, on the personal home's client.

@ProviderFor(accountRealtimeSync)
final accountRealtimeSyncProvider = AccountRealtimeSyncProvider._();

/// #2564 O5 — the account target's feed, on the personal home's client.

final class AccountRealtimeSyncProvider
    extends $FunctionalProvider<RealtimeSync, RealtimeSync, RealtimeSync>
    with $Provider<RealtimeSync> {
  /// #2564 O5 — the account target's feed, on the personal home's client.
  AccountRealtimeSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRealtimeSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRealtimeSyncHash();

  @$internal
  @override
  $ProviderElement<RealtimeSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RealtimeSync create(Ref ref) {
    return accountRealtimeSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RealtimeSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RealtimeSync>(value),
    );
  }
}

String _$accountRealtimeSyncHash() =>
    r'93f0bfcb9d9ae658b87877503d926cf4651ecbf2';

/// Subscribes to ONE target's change feed and invalidates
/// exactly the providers of that target's scope that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.

@ProviderFor(RealtimeInvalidator)
final realtimeInvalidatorProvider = RealtimeInvalidatorFamily._();

/// Subscribes to ONE target's change feed and invalidates
/// exactly the providers of that target's scope that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.
final class RealtimeInvalidatorProvider
    extends $AsyncNotifierProvider<RealtimeInvalidator, void> {
  /// Subscribes to ONE target's change feed and invalidates
  /// exactly the providers of that target's scope that cache each table — so every device,
  /// INCLUDING the one that made the change, repaints without restarts or
  /// manual refreshes (#413). Watched from the shell and the kiosk, alive
  /// with the app. The table → providers map lives in
  /// [invalidationFor] (#577) and is shared with the manual mutation path.
  RealtimeInvalidatorProvider._({
    required RealtimeInvalidatorFamily super.from,
    required RealtimeTarget super.argument,
  }) : super(
         retry: null,
         name: r'realtimeInvalidatorProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$realtimeInvalidatorHash();

  @override
  String toString() {
    return r'realtimeInvalidatorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RealtimeInvalidator create() => RealtimeInvalidator();

  @override
  bool operator ==(Object other) {
    return other is RealtimeInvalidatorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$realtimeInvalidatorHash() =>
    r'08ba4b98639daaa98e4a02d04ab385a309808aac';

/// Subscribes to ONE target's change feed and invalidates
/// exactly the providers of that target's scope that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.

final class RealtimeInvalidatorFamily extends $Family
    with
        $ClassFamilyOverride<
          RealtimeInvalidator,
          AsyncValue<void>,
          void,
          FutureOr<void>,
          RealtimeTarget
        > {
  RealtimeInvalidatorFamily._()
    : super(
        retry: null,
        name: r'realtimeInvalidatorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Subscribes to ONE target's change feed and invalidates
  /// exactly the providers of that target's scope that cache each table — so every device,
  /// INCLUDING the one that made the change, repaints without restarts or
  /// manual refreshes (#413). Watched from the shell and the kiosk, alive
  /// with the app. The table → providers map lives in
  /// [invalidationFor] (#577) and is shared with the manual mutation path.

  RealtimeInvalidatorProvider call(RealtimeTarget target) =>
      RealtimeInvalidatorProvider._(argument: target, from: this);

  @override
  String toString() => r'realtimeInvalidatorProvider';
}

/// Subscribes to ONE target's change feed and invalidates
/// exactly the providers of that target's scope that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.

abstract class _$RealtimeInvalidator extends $AsyncNotifier<void> {
  late final _$args = ref.$arg as RealtimeTarget;
  RealtimeTarget get target => _$args;

  FutureOr<void> build(RealtimeTarget target);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
