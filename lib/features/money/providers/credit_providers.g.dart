// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credit_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1279 — carnets.

@ProviderFor(creditRepository)
final creditRepositoryProvider = CreditRepositoryProvider._();

/// #1279 — carnets.

final class CreditRepositoryProvider
    extends
        $FunctionalProvider<
          CreditRepository,
          CreditRepository,
          CreditRepository
        >
    with $Provider<CreditRepository> {
  /// #1279 — carnets.
  CreditRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditRepositoryHash();

  @$internal
  @override
  $ProviderElement<CreditRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreditRepository create(Ref ref) {
    return creditRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreditRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreditRepository>(value),
    );
  }
}

String _$creditRepositoryHash() => r'184c6aec07a892a7689fbc1cbb739e1aceb7d095';

/// The current workspace's carnet catalogue, active and not.

@ProviderFor(creditProducts)
final creditProductsProvider = CreditProductsProvider._();

/// The current workspace's carnet catalogue, active and not.

final class CreditProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CreditProduct>>,
          List<CreditProduct>,
          FutureOr<List<CreditProduct>>
        >
    with
        $FutureModifier<List<CreditProduct>>,
        $FutureProvider<List<CreditProduct>> {
  /// The current workspace's carnet catalogue, active and not.
  CreditProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<CreditProduct>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CreditProduct>> create(Ref ref) {
    return creditProducts(ref);
  }
}

String _$creditProductsHash() => r'546d93463628fd946e0b414369bdbd619eea6697';

/// Half-days [memberId] can still spend.

@ProviderFor(memberCreditBalance)
final memberCreditBalanceProvider = MemberCreditBalanceFamily._();

/// Half-days [memberId] can still spend.

final class MemberCreditBalanceProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Half-days [memberId] can still spend.
  MemberCreditBalanceProvider._({
    required MemberCreditBalanceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberCreditBalanceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberCreditBalanceHash();

  @override
  String toString() {
    return r'memberCreditBalanceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return memberCreditBalance(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberCreditBalanceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberCreditBalanceHash() =>
    r'96f4d08798e9a382c8ceff1d9ae175b2bbcb6015';

/// Half-days [memberId] can still spend.

final class MemberCreditBalanceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  MemberCreditBalanceFamily._()
    : super(
        retry: null,
        name: r'memberCreditBalanceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Half-days [memberId] can still spend.

  MemberCreditBalanceProvider call(String memberId) =>
      MemberCreditBalanceProvider._(argument: memberId, from: this);

  @override
  String toString() => r'memberCreditBalanceProvider';
}
