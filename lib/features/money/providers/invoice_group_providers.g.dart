// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_group_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(invoiceGroupRepository)
final invoiceGroupRepositoryProvider = InvoiceGroupRepositoryProvider._();

final class InvoiceGroupRepositoryProvider
    extends
        $FunctionalProvider<
          InvoiceGroupRepository,
          InvoiceGroupRepository,
          InvoiceGroupRepository
        >
    with $Provider<InvoiceGroupRepository> {
  InvoiceGroupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceGroupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceGroupRepositoryHash();

  @$internal
  @override
  $ProviderElement<InvoiceGroupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceGroupRepository create(Ref ref) {
    return invoiceGroupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceGroupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceGroupRepository>(value),
    );
  }
}

String _$invoiceGroupRepositoryHash() =>
    r'3b92dbb20602a9c1f37907cefdbe6ef691a22ec7';

/// My personal home's installation id. Unknown by default; the composition
/// root reads it from my personal account (`financeHomeFromMe`, lib/app),
/// as it does the hosts.

@ProviderFor(financeHomeInstallation)
final financeHomeInstallationProvider = FinanceHomeInstallationProvider._();

/// My personal home's installation id. Unknown by default; the composition
/// root reads it from my personal account (`financeHomeFromMe`, lib/app),
/// as it does the hosts.

final class FinanceHomeInstallationProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// My personal home's installation id. Unknown by default; the composition
  /// root reads it from my personal account (`financeHomeFromMe`, lib/app),
  /// as it does the hosts.
  FinanceHomeInstallationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeHomeInstallationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeHomeInstallationHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return financeHomeInstallation(ref);
  }
}

String _$financeHomeInstallationHash() =>
    r'43f766b27a1abd33c846432ddfdc661d39decbc8';

/// My groups, newest read; none while signed out. Each change is written,
/// then the groups are read again.

@ProviderFor(InvoiceGroups)
final invoiceGroupsProvider = InvoiceGroupsProvider._();

/// My groups, newest read; none while signed out. Each change is written,
/// then the groups are read again.
final class InvoiceGroupsProvider
    extends $AsyncNotifierProvider<InvoiceGroups, List<InvoiceGroup>> {
  /// My groups, newest read; none while signed out. Each change is written,
  /// then the groups are read again.
  InvoiceGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceGroupsHash();

  @$internal
  @override
  InvoiceGroups create() => InvoiceGroups();
}

String _$invoiceGroupsHash() => r'21c3dd8f1fd19f37a410d9c794c0b2e3afdf9448';

/// My groups, newest read; none while signed out. Each change is written,
/// then the groups are read again.

abstract class _$InvoiceGroups extends $AsyncNotifier<List<InvoiceGroup>> {
  FutureOr<List<InvoiceGroup>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<InvoiceGroup>>, List<InvoiceGroup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<InvoiceGroup>>, List<InvoiceGroup>>,
              AsyncValue<List<InvoiceGroup>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The reference of an invoice My finances shows, or null when its
/// installation cannot be told (then it is not offered for a group).

@ProviderFor(invoiceRefResolver)
final invoiceRefResolverProvider = InvoiceRefResolverProvider._();

/// The reference of an invoice My finances shows, or null when its
/// installation cannot be told (then it is not offered for a group).

final class InvoiceRefResolverProvider
    extends
        $FunctionalProvider<
          InvoiceRef? Function(FinanceInvoice),
          InvoiceRef? Function(FinanceInvoice),
          InvoiceRef? Function(FinanceInvoice)
        >
    with $Provider<InvoiceRef? Function(FinanceInvoice)> {
  /// The reference of an invoice My finances shows, or null when its
  /// installation cannot be told (then it is not offered for a group).
  InvoiceRefResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceRefResolverProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceRefResolverHash();

  @$internal
  @override
  $ProviderElement<InvoiceRef? Function(FinanceInvoice)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceRef? Function(FinanceInvoice) create(Ref ref) {
    return invoiceRefResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceRef? Function(FinanceInvoice) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<InvoiceRef? Function(FinanceInvoice)>(value),
    );
  }
}

String _$invoiceRefResolverHash() =>
    r'602de342d09821893bb319ae1ed5b7a2b1226ad4';

/// Each of my groups as the overview reads it now, by group id.

@ProviderFor(invoiceGroupViews)
final invoiceGroupViewsProvider = InvoiceGroupViewsProvider._();

/// Each of my groups as the overview reads it now, by group id.

final class InvoiceGroupViewsProvider
    extends
        $FunctionalProvider<
          Map<String, InvoiceGroupView>,
          Map<String, InvoiceGroupView>,
          Map<String, InvoiceGroupView>
        >
    with $Provider<Map<String, InvoiceGroupView>> {
  /// Each of my groups as the overview reads it now, by group id.
  InvoiceGroupViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceGroupViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceGroupViewsHash();

  @$internal
  @override
  $ProviderElement<Map<String, InvoiceGroupView>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, InvoiceGroupView> create(Ref ref) {
    return invoiceGroupViews(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, InvoiceGroupView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, InvoiceGroupView>>(
        value,
      ),
    );
  }
}

String _$invoiceGroupViewsHash() => r'8e89c3408c65f44c37c1734cea16b5fe9f4c1820';
