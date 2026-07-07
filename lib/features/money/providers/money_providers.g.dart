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
