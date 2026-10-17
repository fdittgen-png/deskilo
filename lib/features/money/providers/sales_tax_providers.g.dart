// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_tax_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salesTaxRepository)
final salesTaxRepositoryProvider = SalesTaxRepositoryProvider._();

final class SalesTaxRepositoryProvider
    extends
        $FunctionalProvider<
          SalesTaxRepository,
          SalesTaxRepository,
          SalesTaxRepository
        >
    with $Provider<SalesTaxRepository> {
  SalesTaxRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesTaxRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesTaxRepositoryHash();

  @$internal
  @override
  $ProviderElement<SalesTaxRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SalesTaxRepository create(Ref ref) {
    return salesTaxRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SalesTaxRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SalesTaxRepository>(value),
    );
  }
}

String _$salesTaxRepositoryHash() =>
    r'51bd70fcb249256349740df17f34ed03206520f8';

@ProviderFor(salesTaxCommands)
final salesTaxCommandsProvider = SalesTaxCommandsProvider._();

final class SalesTaxCommandsProvider
    extends
        $FunctionalProvider<
          SalesTaxCommands,
          SalesTaxCommands,
          SalesTaxCommands
        >
    with $Provider<SalesTaxCommands> {
  SalesTaxCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesTaxCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesTaxCommandsHash();

  @$internal
  @override
  $ProviderElement<SalesTaxCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SalesTaxCommands create(Ref ref) {
    return salesTaxCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SalesTaxCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SalesTaxCommands>(value),
    );
  }
}

String _$salesTaxCommandsHash() => r'e2dd31f6897ef54f5b2aaf134bf71b37f07e1e0b';

/// The exemption certificates of one customer, the newest first.

@ProviderFor(memberTaxCertificates)
final memberTaxCertificatesProvider = MemberTaxCertificatesFamily._();

/// The exemption certificates of one customer, the newest first.

final class MemberTaxCertificatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TaxExemptionCertificate>>,
          List<TaxExemptionCertificate>,
          FutureOr<List<TaxExemptionCertificate>>
        >
    with
        $FutureModifier<List<TaxExemptionCertificate>>,
        $FutureProvider<List<TaxExemptionCertificate>> {
  /// The exemption certificates of one customer, the newest first.
  MemberTaxCertificatesProvider._({
    required MemberTaxCertificatesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberTaxCertificatesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberTaxCertificatesHash();

  @override
  String toString() {
    return r'memberTaxCertificatesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TaxExemptionCertificate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TaxExemptionCertificate>> create(Ref ref) {
    final argument = this.argument as String;
    return memberTaxCertificates(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberTaxCertificatesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberTaxCertificatesHash() =>
    r'0c7afb7f4e87ea0ea15c3d8eb612807fb228bad2';

/// The exemption certificates of one customer, the newest first.

final class MemberTaxCertificatesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<TaxExemptionCertificate>>,
          String
        > {
  MemberTaxCertificatesFamily._()
    : super(
        retry: null,
        name: r'memberTaxCertificatesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The exemption certificates of one customer, the newest first.

  MemberTaxCertificatesProvider call(String memberId) =>
      MemberTaxCertificatesProvider._(argument: memberId, from: this);

  @override
  String toString() => r'memberTaxCertificatesProvider';
}
