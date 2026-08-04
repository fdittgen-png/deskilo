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

/// Current period key in workspace terms ('yyyy-MM').
/// Active consumable services of the current workspace (#123).

@ProviderFor(services)
final servicesProvider = ServicesProvider._();

/// Current period key in workspace terms ('yyyy-MM').
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
  /// Current period key in workspace terms ('yyyy-MM').
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

/// Active day packages of the current workspace — the member buy sheet
/// (migration 0042).

@ProviderFor(packages)
final packagesProvider = PackagesProvider._();

/// Active day packages of the current workspace — the member buy sheet
/// (migration 0042).

final class PackagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Package>>,
          List<Package>,
          FutureOr<List<Package>>
        >
    with $FutureModifier<List<Package>>, $FutureProvider<List<Package>> {
  /// Active day packages of the current workspace — the member buy sheet
  /// (migration 0042).
  PackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packagesHash();

  @$internal
  @override
  $FutureProviderElement<List<Package>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Package>> create(Ref ref) {
    return packages(ref);
  }
}

String _$packagesHash() => r'c963187492353e53cdaed749c53e4c7e9b53e89e';

/// Every package incl. deactivated ones — the owner's package editor.

@ProviderFor(allPackages)
final allPackagesProvider = AllPackagesProvider._();

/// Every package incl. deactivated ones — the owner's package editor.

final class AllPackagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Package>>,
          List<Package>,
          FutureOr<List<Package>>
        >
    with $FutureModifier<List<Package>>, $FutureProvider<List<Package>> {
  /// Every package incl. deactivated ones — the owner's package editor.
  AllPackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allPackagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allPackagesHash();

  @$internal
  @override
  $FutureProviderElement<List<Package>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Package>> create(Ref ref) {
    return allPackages(ref);
  }
}

String _$allPackagesHash() => r'9d0f934aac44c544d100dcca18203008e973c47e';

/// The workspace's VAT rates (0072). Member-readable: the rate is on the
/// bill and on every invoice, so it is not owner-only data.
///
/// Empty means VAT is off — every amount is then whatever the workspace's
/// regime says it is, and nothing about the bill changes.

@ProviderFor(vatRates)
final vatRatesProvider = VatRatesProvider._();

/// The workspace's VAT rates (0072). Member-readable: the rate is on the
/// bill and on every invoice, so it is not owner-only data.
///
/// Empty means VAT is off — every amount is then whatever the workspace's
/// regime says it is, and nothing about the bill changes.

final class VatRatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VatRate>>,
          List<VatRate>,
          FutureOr<List<VatRate>>
        >
    with $FutureModifier<List<VatRate>>, $FutureProvider<List<VatRate>> {
  /// The workspace's VAT rates (0072). Member-readable: the rate is on the
  /// bill and on every invoice, so it is not owner-only data.
  ///
  /// Empty means VAT is off — every amount is then whatever the workspace's
  /// regime says it is, and nothing about the bill changes.
  VatRatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vatRatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vatRatesHash();

  @$internal
  @override
  $FutureProviderElement<List<VatRate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VatRate>> create(Ref ref) {
    return vatRates(ref);
  }
}

String _$vatRatesHash() => r'df4434126bc231e40ce949776c6a544c3dcd55cc';

/// The percentage an item with no rate of its own is taxed at — the mirror
/// of `workspace_default_vat_percent`, for previews only. The server is
/// still what stamps the ledger.

@ProviderFor(defaultVatPercent)
final defaultVatPercentProvider = DefaultVatPercentProvider._();

/// The percentage an item with no rate of its own is taxed at — the mirror
/// of `workspace_default_vat_percent`, for previews only. The server is
/// still what stamps the ledger.

final class DefaultVatPercentProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The percentage an item with no rate of its own is taxed at — the mirror
  /// of `workspace_default_vat_percent`, for previews only. The server is
  /// still what stamps the ledger.
  DefaultVatPercentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultVatPercentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultVatPercentHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return defaultVatPercent(ref);
  }
}

String _$defaultVatPercentHash() => r'03c79715bfe2c78330ab759b724dd15d5a707005';

/// The invoice archive (0060): RLS scopes rows — members their own,
/// admins the whole workspace.

@ProviderFor(invoices)
final invoicesProvider = InvoicesProvider._();

/// The invoice archive (0060): RLS scopes rows — members their own,
/// admins the whole workspace.

final class InvoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Invoice>>,
          List<Invoice>,
          FutureOr<List<Invoice>>
        >
    with $FutureModifier<List<Invoice>>, $FutureProvider<List<Invoice>> {
  /// The invoice archive (0060): RLS scopes rows — members their own,
  /// admins the whole workspace.
  InvoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoicesHash();

  @$internal
  @override
  $FutureProviderElement<List<Invoice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Invoice>> create(Ref ref) {
    return invoices(ref);
  }
}

String _$invoicesHash() => r'1750a78bf092e310a8b152b40bc7f4facd84c06d';

/// Invoice-PDF template of the active workspace (#454); empty while no
/// workspace is selected. The renderer additionally gates on the
/// invoicePdfTemplate feature flag at the call site.

@ProviderFor(invoicePdfTemplate)
final invoicePdfTemplateProvider = InvoicePdfTemplateProvider._();

/// Invoice-PDF template of the active workspace (#454); empty while no
/// workspace is selected. The renderer additionally gates on the
/// invoicePdfTemplate feature flag at the call site.

final class InvoicePdfTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvoicePdfTemplate>,
          InvoicePdfTemplate,
          FutureOr<InvoicePdfTemplate>
        >
    with
        $FutureModifier<InvoicePdfTemplate>,
        $FutureProvider<InvoicePdfTemplate> {
  /// Invoice-PDF template of the active workspace (#454); empty while no
  /// workspace is selected. The renderer additionally gates on the
  /// invoicePdfTemplate feature flag at the call site.
  InvoicePdfTemplateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoicePdfTemplateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoicePdfTemplateHash();

  @$internal
  @override
  $FutureProviderElement<InvoicePdfTemplate> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvoicePdfTemplate> create(Ref ref) {
    return invoicePdfTemplate(ref);
  }
}

String _$invoicePdfTemplateHash() =>
    r'1b8881ae90b31cd2a288f773b931b553ca1ee079';

/// invoiceId → its payment match (0067) — the invoice lifecycle state.

@ProviderFor(invoiceMatches)
final invoiceMatchesProvider = InvoiceMatchesProvider._();

/// invoiceId → its payment match (0067) — the invoice lifecycle state.

final class InvoiceMatchesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, InvoiceMatch>>,
          Map<String, InvoiceMatch>,
          FutureOr<Map<String, InvoiceMatch>>
        >
    with
        $FutureModifier<Map<String, InvoiceMatch>>,
        $FutureProvider<Map<String, InvoiceMatch>> {
  /// invoiceId → its payment match (0067) — the invoice lifecycle state.
  InvoiceMatchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceMatchesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceMatchesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, InvoiceMatch>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, InvoiceMatch>> create(Ref ref) {
    return invoiceMatches(ref);
  }
}

String _$invoiceMatchesHash() => r'3d539ac3cb33fb5c67caa92edc50d1d4d14cbffb';

/// invoiceId → reminder count + last instant (0066), for the archive
/// badges.

@ProviderFor(invoiceReminders)
final invoiceRemindersProvider = InvoiceRemindersProvider._();

/// invoiceId → reminder count + last instant (0066), for the archive
/// badges.

final class InvoiceRemindersProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ({int count, DateTime last})>>,
          Map<String, ({int count, DateTime last})>,
          FutureOr<Map<String, ({int count, DateTime last})>>
        >
    with
        $FutureModifier<Map<String, ({int count, DateTime last})>>,
        $FutureProvider<Map<String, ({int count, DateTime last})>> {
  /// invoiceId → reminder count + last instant (0066), for the archive
  /// badges.
  InvoiceRemindersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceRemindersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceRemindersHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, ({int count, DateTime last})>>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, ({int count, DateTime last})>> create(Ref ref) {
    return invoiceReminders(ref);
  }
}

String _$invoiceRemindersHash() => r'5528bee535a265ed0f9ba1da6ee36544cc3a428c';

/// Whether this workspace can SEND an e-invoice (0073) — the affordance
/// only shows when the owner has configured a platform and the function is
/// deployed.

@ProviderFor(eInvoiceGateway)
final eInvoiceGatewayProvider = EInvoiceGatewayProvider._();

/// Whether this workspace can SEND an e-invoice (0073) — the affordance
/// only shows when the owner has configured a platform and the function is
/// deployed.

final class EInvoiceGatewayProvider
    extends
        $FunctionalProvider<
          AsyncValue<EInvoiceGatewayConfig>,
          EInvoiceGatewayConfig,
          FutureOr<EInvoiceGatewayConfig>
        >
    with
        $FutureModifier<EInvoiceGatewayConfig>,
        $FutureProvider<EInvoiceGatewayConfig> {
  /// Whether this workspace can SEND an e-invoice (0073) — the affordance
  /// only shows when the owner has configured a platform and the function is
  /// deployed.
  EInvoiceGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eInvoiceGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eInvoiceGatewayHash();

  @$internal
  @override
  $FutureProviderElement<EInvoiceGatewayConfig> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EInvoiceGatewayConfig> create(Ref ref) {
    return eInvoiceGateway(ref);
  }
}

String _$eInvoiceGatewayHash() => r'92f62c9e97f81e9a65f6ce84a83fe9958829651f';

/// The owner-visible state of the platform credentials (0071): non-secret
/// fields plus the NAMES of the secrets that are set.

@ProviderFor(eInvoiceStatus)
final eInvoiceStatusProvider = EInvoiceStatusProvider._();

/// The owner-visible state of the platform credentials (0071): non-secret
/// fields plus the NAMES of the secrets that are set.

final class EInvoiceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<EInvoiceProviderStatus>,
          EInvoiceProviderStatus,
          FutureOr<EInvoiceProviderStatus>
        >
    with
        $FutureModifier<EInvoiceProviderStatus>,
        $FutureProvider<EInvoiceProviderStatus> {
  /// The owner-visible state of the platform credentials (0071): non-secret
  /// fields plus the NAMES of the secrets that are set.
  EInvoiceStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eInvoiceStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eInvoiceStatusHash();

  @$internal
  @override
  $FutureProviderElement<EInvoiceProviderStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EInvoiceProviderStatus> create(Ref ref) {
    return eInvoiceStatus(ref);
  }
}

String _$eInvoiceStatusHash() => r'3003ae3fe1a9d6dc1dc7d13cd5ab0c675cb27557';

/// invoiceId → its latest transmission (0071), for the detail sheet's
/// "sent on / accepted by" line.

@ProviderFor(invoiceTransmissions)
final invoiceTransmissionsProvider = InvoiceTransmissionsProvider._();

/// invoiceId → its latest transmission (0071), for the detail sheet's
/// "sent on / accepted by" line.

final class InvoiceTransmissionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, InvoiceTransmission>>,
          Map<String, InvoiceTransmission>,
          FutureOr<Map<String, InvoiceTransmission>>
        >
    with
        $FutureModifier<Map<String, InvoiceTransmission>>,
        $FutureProvider<Map<String, InvoiceTransmission>> {
  /// invoiceId → its latest transmission (0071), for the detail sheet's
  /// "sent on / accepted by" line.
  InvoiceTransmissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceTransmissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceTransmissionsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, InvoiceTransmission>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, InvoiceTransmission>> create(Ref ref) {
    return invoiceTransmissions(ref);
  }
}

String _$invoiceTransmissionsHash() =>
    r'14674c21ad83c1552830a9c8a4d19a680b33c689';

/// The invoicing overview (issuers only — callers gate on canIssue).
///
///  * TO INVOICE: every active non-kiosk member whose PREVIOUS month
///    derives positions and has no non-voided invoice covering it.
///  * OPEN: non-voided, non-replaced invoices whose month's LIVE solde
///    (re-derived) is still positive; the live amount is what is shown
///    as outstanding. Legacy invoices without a period fall back to
///    their stored total.
///
/// Derivations run in parallel; the provider re-evaluates when the
/// archive changes (issue/void/replace all invalidate invoicesProvider).

@ProviderFor(invoicingOverview)
final invoicingOverviewProvider = InvoicingOverviewProvider._();

/// The invoicing overview (issuers only — callers gate on canIssue).
///
///  * TO INVOICE: every active non-kiosk member whose PREVIOUS month
///    derives positions and has no non-voided invoice covering it.
///  * OPEN: non-voided, non-replaced invoices whose month's LIVE solde
///    (re-derived) is still positive; the live amount is what is shown
///    as outstanding. Legacy invoices without a period fall back to
///    their stored total.
///
/// Derivations run in parallel; the provider re-evaluates when the
/// archive changes (issue/void/replace all invalidate invoicesProvider).

final class InvoicingOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvoicingOverview>,
          InvoicingOverview,
          FutureOr<InvoicingOverview>
        >
    with
        $FutureModifier<InvoicingOverview>,
        $FutureProvider<InvoicingOverview> {
  /// The invoicing overview (issuers only — callers gate on canIssue).
  ///
  ///  * TO INVOICE: every active non-kiosk member whose PREVIOUS month
  ///    derives positions and has no non-voided invoice covering it.
  ///  * OPEN: non-voided, non-replaced invoices whose month's LIVE solde
  ///    (re-derived) is still positive; the live amount is what is shown
  ///    as outstanding. Legacy invoices without a period fall back to
  ///    their stored total.
  ///
  /// Derivations run in parallel; the provider re-evaluates when the
  /// archive changes (issue/void/replace all invalidate invoicesProvider).
  InvoicingOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoicingOverviewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoicingOverviewHash();

  @$internal
  @override
  $FutureProviderElement<InvoicingOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvoicingOverview> create(Ref ref) {
    return invoicingOverview(ref);
  }
}

String _$invoicingOverviewHash() => r'99cf1fa7e6bc09c6fda5662a59779a748b8c5666';
