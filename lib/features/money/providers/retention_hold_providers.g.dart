// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retention_hold_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where retention holds are read, placed and released.

@ProviderFor(retentionHoldRepository)
final retentionHoldRepositoryProvider = RetentionHoldRepositoryProvider._();

/// Where retention holds are read, placed and released.

final class RetentionHoldRepositoryProvider
    extends
        $FunctionalProvider<
          RetentionHoldRepository,
          RetentionHoldRepository,
          RetentionHoldRepository
        >
    with $Provider<RetentionHoldRepository> {
  /// Where retention holds are read, placed and released.
  RetentionHoldRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionHoldRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldRepositoryHash();

  @$internal
  @override
  $ProviderElement<RetentionHoldRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RetentionHoldRepository create(Ref ref) {
    return retentionHoldRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetentionHoldRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetentionHoldRepository>(value),
    );
  }
}

String _$retentionHoldRepositoryHash() =>
    r'e5528a4a73118c2f5c07bd7a1d14f75cff9cf766';

/// Placing and releasing a hold (the decision the retention dialog asks for).

@ProviderFor(retentionHoldCommands)
final retentionHoldCommandsProvider = RetentionHoldCommandsProvider._();

/// Placing and releasing a hold (the decision the retention dialog asks for).

final class RetentionHoldCommandsProvider
    extends $FunctionalProvider<RetentionHolds, RetentionHolds, RetentionHolds>
    with $Provider<RetentionHolds> {
  /// Placing and releasing a hold (the decision the retention dialog asks for).
  RetentionHoldCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionHoldCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldCommandsHash();

  @$internal
  @override
  $ProviderElement<RetentionHolds> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RetentionHolds create(Ref ref) {
    return retentionHoldCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetentionHolds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetentionHolds>(value),
    );
  }
}

String _$retentionHoldCommandsHash() =>
    r'326bcb7278a054e9943b072574a98f53c144755e';

/// Every hold of the current workspace, the active ones first; invalidated
/// after a change.

@ProviderFor(retentionHolds)
final retentionHoldsProvider = RetentionHoldsProvider._();

/// Every hold of the current workspace, the active ones first; invalidated
/// after a change.

final class RetentionHoldsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RetentionHold>>,
          List<RetentionHold>,
          FutureOr<List<RetentionHold>>
        >
    with
        $FutureModifier<List<RetentionHold>>,
        $FutureProvider<List<RetentionHold>> {
  /// Every hold of the current workspace, the active ones first; invalidated
  /// after a change.
  RetentionHoldsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionHoldsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldsHash();

  @$internal
  @override
  $FutureProviderElement<List<RetentionHold>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RetentionHold>> create(Ref ref) {
    return retentionHolds(ref);
  }
}

String _$retentionHoldsHash() => r'189a4d25985d06c96f3557a5b2ca087d27ac1fdd';
