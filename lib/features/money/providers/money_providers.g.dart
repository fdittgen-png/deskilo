// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(moneyRepository)
final moneyRepositoryProvider = MoneyRepositoryProvider._();

final class MoneyRepositoryProvider
    extends
        $FunctionalProvider<MoneyRepository, MoneyRepository, MoneyRepository>
    with $Provider<MoneyRepository> {
  MoneyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moneyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moneyRepositoryHash();

  @$internal
  @override
  $ProviderElement<MoneyRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MoneyRepository create(Ref ref) {
    return moneyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoneyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoneyRepository>(value),
    );
  }
}

String _$moneyRepositoryHash() => r'db19ef8c61f5e7ef3494784dfcae5ed1c82e378b';

/// The signed-in member's statement for a period ('yyyy-MM').

@ProviderFor(myStatement)
final myStatementProvider = MyStatementFamily._();

/// The signed-in member's statement for a period ('yyyy-MM').

final class MyStatementProvider
    extends
        $FunctionalProvider<
          AsyncValue<Statement?>,
          Statement?,
          FutureOr<Statement?>
        >
    with $FutureModifier<Statement?>, $FutureProvider<Statement?> {
  /// The signed-in member's statement for a period ('yyyy-MM').
  MyStatementProvider._({
    required MyStatementFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myStatementProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myStatementHash();

  @override
  String toString() {
    return r'myStatementProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Statement?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Statement?> create(Ref ref) {
    final argument = this.argument as String;
    return myStatement(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyStatementProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myStatementHash() => r'db155a00e5d29e799a74d9bfe1b9f544ea603523';

/// The signed-in member's statement for a period ('yyyy-MM').

final class MyStatementFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Statement?>, String> {
  MyStatementFamily._()
    : super(
        retry: null,
        name: r'myStatementProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The signed-in member's statement for a period ('yyyy-MM').

  MyStatementProvider call(String period) =>
      MyStatementProvider._(argument: period, from: this);

  @override
  String toString() => r'myStatementProvider';
}

/// The signed-in member's full ledger, newest first.

@ProviderFor(myLedger)
final myLedgerProvider = MyLedgerProvider._();

/// The signed-in member's full ledger, newest first.

final class MyLedgerProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerEntry>>,
          List<LedgerEntry>,
          FutureOr<List<LedgerEntry>>
        >
    with
        $FutureModifier<List<LedgerEntry>>,
        $FutureProvider<List<LedgerEntry>> {
  /// The signed-in member's full ledger, newest first.
  MyLedgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myLedgerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myLedgerHash();

  @$internal
  @override
  $FutureProviderElement<List<LedgerEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LedgerEntry>> create(Ref ref) {
    return myLedger(ref);
  }
}

String _$myLedgerHash() => r'5d8925eeb1aa748d7505849799c742c10e7e11d8';

/// Fee bands of the current workspace, ordered by from_pct (#128).

@ProviderFor(feeBands)
final feeBandsProvider = FeeBandsProvider._();

/// Fee bands of the current workspace, ordered by from_pct (#128).

final class FeeBandsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeeBand>>,
          List<FeeBand>,
          FutureOr<List<FeeBand>>
        >
    with $FutureModifier<List<FeeBand>>, $FutureProvider<List<FeeBand>> {
  /// Fee bands of the current workspace, ordered by from_pct (#128).
  FeeBandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feeBandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feeBandsHash();

  @$internal
  @override
  $FutureProviderElement<List<FeeBand>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FeeBand>> create(Ref ref) {
    return feeBands(ref);
  }
}

String _$feeBandsHash() => r'890f538fdbc1ecdb8a3ed467f858c6ca6ec07705';

/// Offered subscription levels of the current workspace (#128).

@ProviderFor(subscriptionLevels)
final subscriptionLevelsProvider = SubscriptionLevelsProvider._();

/// Offered subscription levels of the current workspace (#128).

final class SubscriptionLevelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SubscriptionLevels>,
          SubscriptionLevels,
          FutureOr<SubscriptionLevels>
        >
    with
        $FutureModifier<SubscriptionLevels>,
        $FutureProvider<SubscriptionLevels> {
  /// Offered subscription levels of the current workspace (#128).
  SubscriptionLevelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionLevelsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionLevelsHash();

  @$internal
  @override
  $FutureProviderElement<SubscriptionLevels> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SubscriptionLevels> create(Ref ref) {
    return subscriptionLevels(ref);
  }
}

String _$subscriptionLevelsHash() =>
    r'ed43338c2ac179bb8e793c3a9b7f6cc1d3da0bf3';

/// Active consumable services of the current workspace (#123).

@ProviderFor(services)
final servicesProvider = ServicesProvider._();

/// Active consumable services of the current workspace (#123).

final class ServicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceItem>>,
          List<ServiceItem>,
          FutureOr<List<ServiceItem>>
        >
    with
        $FutureModifier<List<ServiceItem>>,
        $FutureProvider<List<ServiceItem>> {
  /// Active consumable services of the current workspace (#123).
  ServicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'servicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$servicesHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceItem>> create(Ref ref) {
    return services(ref);
  }
}

String _$servicesHash() => r'35f3295248b134e975fa8fd5ea2d56f83c713b54';

/// Every service incl. deactivated ones — the owner's catalog editor (#123).

@ProviderFor(allServices)
final allServicesProvider = AllServicesProvider._();

/// Every service incl. deactivated ones — the owner's catalog editor (#123).

final class AllServicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServiceItem>>,
          List<ServiceItem>,
          FutureOr<List<ServiceItem>>
        >
    with
        $FutureModifier<List<ServiceItem>>,
        $FutureProvider<List<ServiceItem>> {
  /// Every service incl. deactivated ones — the owner's catalog editor (#123).
  AllServicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allServicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allServicesHash();

  @$internal
  @override
  $FutureProviderElement<List<ServiceItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ServiceItem>> create(Ref ref) {
    return allServices(ref);
  }
}

String _$allServicesHash() => r'7d69290d13259c4f3e0695c2de5a978939c5017c';
