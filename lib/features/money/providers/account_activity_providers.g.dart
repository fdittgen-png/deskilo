// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_activity_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountActivityRepository)
final accountActivityRepositoryProvider = AccountActivityRepositoryProvider._();

final class AccountActivityRepositoryProvider
    extends
        $FunctionalProvider<
          AccountActivityRepository,
          AccountActivityRepository,
          AccountActivityRepository
        >
    with $Provider<AccountActivityRepository> {
  AccountActivityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountActivityRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountActivityRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountActivityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountActivityRepository create(Ref ref) {
    return accountActivityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountActivityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountActivityRepository>(value),
    );
  }
}

String _$accountActivityRepositoryHash() =>
    r'2140dd4f05a119a61312956cc851afd711fa73b6';

@ProviderFor(accountActivity)
final accountActivityProvider = AccountActivityFamily._();

final class AccountActivityProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountActivity>>,
          List<AccountActivity>,
          FutureOr<List<AccountActivity>>
        >
    with
        $FutureModifier<List<AccountActivity>>,
        $FutureProvider<List<AccountActivity>> {
  AccountActivityProvider._({
    required AccountActivityFamily super.from,
    required (AccountActivityKind, {ActivityCursor? before}) super.argument,
  }) : super(
         retry: null,
         name: r'accountActivityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountActivityHash();

  @override
  String toString() {
    return r'accountActivityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<AccountActivity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AccountActivity>> create(Ref ref) {
    final argument =
        this.argument as (AccountActivityKind, {ActivityCursor? before});
    return accountActivity(ref, argument.$1, before: argument.before);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountActivityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountActivityHash() => r'0ada926e228d5281f60fafc85f906c171e4f40d0';

final class AccountActivityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<AccountActivity>>,
          (AccountActivityKind, {ActivityCursor? before})
        > {
  AccountActivityFamily._()
    : super(
        retry: null,
        name: r'accountActivityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountActivityProvider call(
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) => AccountActivityProvider._(argument: (kind, before: before), from: this);

  @override
  String toString() => r'accountActivityProvider';
}

@ProviderFor(connectedAccountActivity)
final connectedAccountActivityProvider = ConnectedAccountActivityFamily._();

final class ConnectedAccountActivityProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountActivity>>,
          List<AccountActivity>,
          FutureOr<List<AccountActivity>>
        >
    with
        $FutureModifier<List<AccountActivity>>,
        $FutureProvider<List<AccountActivity>> {
  ConnectedAccountActivityProvider._({
    required ConnectedAccountActivityFamily super.from,
    required (String, AccountActivityKind, {ActivityCursor? before})
    super.argument,
  }) : super(
         retry: null,
         name: r'connectedAccountActivityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectedAccountActivityHash();

  @override
  String toString() {
    return r'connectedAccountActivityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<AccountActivity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AccountActivity>> create(Ref ref) {
    final argument =
        this.argument
            as (String, AccountActivityKind, {ActivityCursor? before});
    return connectedAccountActivity(
      ref,
      argument.$1,
      argument.$2,
      before: argument.before,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectedAccountActivityProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectedAccountActivityHash() =>
    r'4508c0c7d9ed2272328103bed4844a2fdcaec8f0';

final class ConnectedAccountActivityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<AccountActivity>>,
          (String, AccountActivityKind, {ActivityCursor? before})
        > {
  ConnectedAccountActivityFamily._()
    : super(
        retry: null,
        name: r'connectedAccountActivityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConnectedAccountActivityProvider call(
    String source,
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) => ConnectedAccountActivityProvider._(
    argument: (source, kind, before: before),
    from: this,
  );

  @override
  String toString() => r'connectedAccountActivityProvider';
}
