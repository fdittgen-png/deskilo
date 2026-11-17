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
    r'9c2287dfaaefaf93b77ecf48ab713a92de513bce';

/// My own documents at the SELECTED workspace, read on that workspace's own
/// installation: `my_finance_overview` runs there under the person's session
/// on that host, so a connected installation's invoices never travel through
/// the personal home's client and are never answered by it.

@ProviderFor(selectedWorkspaceAccountActivityRepository)
final selectedWorkspaceAccountActivityRepositoryProvider =
    SelectedWorkspaceAccountActivityRepositoryProvider._();

/// My own documents at the SELECTED workspace, read on that workspace's own
/// installation: `my_finance_overview` runs there under the person's session
/// on that host, so a connected installation's invoices never travel through
/// the personal home's client and are never answered by it.

final class SelectedWorkspaceAccountActivityRepositoryProvider
    extends
        $FunctionalProvider<
          AccountActivityRepository,
          AccountActivityRepository,
          AccountActivityRepository
        >
    with $Provider<AccountActivityRepository> {
  /// My own documents at the SELECTED workspace, read on that workspace's own
  /// installation: `my_finance_overview` runs there under the person's session
  /// on that host, so a connected installation's invoices never travel through
  /// the personal home's client and are never answered by it.
  SelectedWorkspaceAccountActivityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedWorkspaceAccountActivityRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$selectedWorkspaceAccountActivityRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountActivityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountActivityRepository create(Ref ref) {
    return selectedWorkspaceAccountActivityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountActivityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountActivityRepository>(value),
    );
  }
}

String _$selectedWorkspaceAccountActivityRepositoryHash() =>
    r'a21c82cd6b8946d0cf22746b4268dd22708ea3dd';

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
