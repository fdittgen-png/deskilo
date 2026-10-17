// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_queries_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2591 C1 — the invoice reads on their own: a consumer that only reads
/// invoices depends on this and on nothing else of the money boundary.

@ProviderFor(invoiceQueries)
final invoiceQueriesProvider = InvoiceQueriesProvider._();

/// #2591 C1 — the invoice reads on their own: a consumer that only reads
/// invoices depends on this and on nothing else of the money boundary.

final class InvoiceQueriesProvider
    extends $FunctionalProvider<InvoiceQueries, InvoiceQueries, InvoiceQueries>
    with $Provider<InvoiceQueries> {
  /// #2591 C1 — the invoice reads on their own: a consumer that only reads
  /// invoices depends on this and on nothing else of the money boundary.
  InvoiceQueriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceQueriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceQueriesHash();

  @$internal
  @override
  $ProviderElement<InvoiceQueries> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InvoiceQueries create(Ref ref) {
    return invoiceQueries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceQueries value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceQueries>(value),
    );
  }
}

String _$invoiceQueriesHash() => r'fa30e92b6352911be8389f2ff83dfa011398d211';

/// #2591 C1 — the member's account, statement, ledger and usage reads.

@ProviderFor(memberAccountQueries)
final memberAccountQueriesProvider = MemberAccountQueriesProvider._();

/// #2591 C1 — the member's account, statement, ledger and usage reads.

final class MemberAccountQueriesProvider
    extends
        $FunctionalProvider<
          MemberAccountQueries,
          MemberAccountQueries,
          MemberAccountQueries
        >
    with $Provider<MemberAccountQueries> {
  /// #2591 C1 — the member's account, statement, ledger and usage reads.
  MemberAccountQueriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberAccountQueriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberAccountQueriesHash();

  @$internal
  @override
  $ProviderElement<MemberAccountQueries> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberAccountQueries create(Ref ref) {
    return memberAccountQueries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberAccountQueries value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberAccountQueries>(value),
    );
  }
}

String _$memberAccountQueriesHash() =>
    r'8c9565c2074e2144ca57eb073d3cc95f7bf9ad79';

/// #2591 C2 — the report template and image library: the preview and the
/// editor depend on this and on nothing else of the money boundary.

@ProviderFor(reportTemplateRepository)
final reportTemplateRepositoryProvider = ReportTemplateRepositoryProvider._();

/// #2591 C2 — the report template and image library: the preview and the
/// editor depend on this and on nothing else of the money boundary.

final class ReportTemplateRepositoryProvider
    extends
        $FunctionalProvider<
          ReportTemplateRepository,
          ReportTemplateRepository,
          ReportTemplateRepository
        >
    with $Provider<ReportTemplateRepository> {
  /// #2591 C2 — the report template and image library: the preview and the
  /// editor depend on this and on nothing else of the money boundary.
  ReportTemplateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportTemplateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportTemplateRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReportTemplateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReportTemplateRepository create(Ref ref) {
    return reportTemplateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportTemplateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportTemplateRepository>(value),
    );
  }
}

String _$reportTemplateRepositoryHash() =>
    r'b2ea07b1d54fc22f030ce0126e070d55472f7d8b';

/// #2591 C3 — what a person does to an invoice: issue, void, remind,
/// regroup, settle a credit note, match a payment.

@ProviderFor(invoiceCommands)
final invoiceCommandsProvider = InvoiceCommandsProvider._();

/// #2591 C3 — what a person does to an invoice: issue, void, remind,
/// regroup, settle a credit note, match a payment.

final class InvoiceCommandsProvider
    extends
        $FunctionalProvider<InvoiceCommands, InvoiceCommands, InvoiceCommands>
    with $Provider<InvoiceCommands> {
  /// #2591 C3 — what a person does to an invoice: issue, void, remind,
  /// regroup, settle a credit note, match a payment.
  InvoiceCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceCommandsHash();

  @$internal
  @override
  $ProviderElement<InvoiceCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InvoiceCommands create(Ref ref) {
    return invoiceCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceCommands>(value),
    );
  }
}

String _$invoiceCommandsHash() => r'888c8948b95c147d0261e62c60ae23e3463f746c';

/// #2591 C3 — the workspace's VAT rates and returns.

@ProviderFor(taxReportingRepository)
final taxReportingRepositoryProvider = TaxReportingRepositoryProvider._();

/// #2591 C3 — the workspace's VAT rates and returns.

final class TaxReportingRepositoryProvider
    extends
        $FunctionalProvider<
          TaxReportingRepository,
          TaxReportingRepository,
          TaxReportingRepository
        >
    with $Provider<TaxReportingRepository> {
  /// #2591 C3 — the workspace's VAT rates and returns.
  TaxReportingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReportingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReportingRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaxReportingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaxReportingRepository create(Ref ref) {
    return taxReportingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaxReportingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaxReportingRepository>(value),
    );
  }
}

String _$taxReportingRepositoryHash() =>
    r'5b6cac99aedbbd0a384ec4e97e6feda2786bcf1d';

/// #2591 C4 — fee bands, subscription levels, services, packages and a
/// member's negotiated deal.

@ProviderFor(commercialTerms)
final commercialTermsProvider = CommercialTermsProvider._();

/// #2591 C4 — fee bands, subscription levels, services, packages and a
/// member's negotiated deal.

final class CommercialTermsProvider
    extends
        $FunctionalProvider<
          CommercialTermsRepository,
          CommercialTermsRepository,
          CommercialTermsRepository
        >
    with $Provider<CommercialTermsRepository> {
  /// #2591 C4 — fee bands, subscription levels, services, packages and a
  /// member's negotiated deal.
  CommercialTermsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commercialTermsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commercialTermsHash();

  @$internal
  @override
  $ProviderElement<CommercialTermsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommercialTermsRepository create(Ref ref) {
    return commercialTerms(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommercialTermsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommercialTermsRepository>(value),
    );
  }
}

String _$commercialTermsHash() => r'2ac85708d8f61541447547900d417d010f087f7d';

/// #2591 C4 — the narrow legacy expense adapter (#2573 takes its source
/// bridge).

@ProviderFor(expenseRepository)
final expenseRepositoryProvider = ExpenseRepositoryProvider._();

/// #2591 C4 — the narrow legacy expense adapter (#2573 takes its source
/// bridge).

final class ExpenseRepositoryProvider
    extends
        $FunctionalProvider<
          ExpenseRepository,
          ExpenseRepository,
          ExpenseRepository
        >
    with $Provider<ExpenseRepository> {
  /// #2591 C4 — the narrow legacy expense adapter (#2573 takes its source
  /// bridge).
  ExpenseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExpenseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExpenseRepository create(Ref ref) {
    return expenseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExpenseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExpenseRepository>(value),
    );
  }
}

String _$expenseRepositoryHash() => r'd55c5311dda3b80caa457fba5cb8b84f72969440';

/// #2365 — the one fiscal source an accounting export reads.

@ProviderFor(accountingSourceQueries)
final accountingSourceQueriesProvider = AccountingSourceQueriesProvider._();

/// #2365 — the one fiscal source an accounting export reads.

final class AccountingSourceQueriesProvider
    extends
        $FunctionalProvider<
          AccountingSourceQueries,
          AccountingSourceQueries,
          AccountingSourceQueries
        >
    with $Provider<AccountingSourceQueries> {
  /// #2365 — the one fiscal source an accounting export reads.
  AccountingSourceQueriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountingSourceQueriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountingSourceQueriesHash();

  @$internal
  @override
  $ProviderElement<AccountingSourceQueries> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountingSourceQueries create(Ref ref) {
    return accountingSourceQueries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountingSourceQueries value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountingSourceQueries>(value),
    );
  }
}

String _$accountingSourceQueriesHash() =>
    r'edfe751038a4f51ea46405ca0b2ba451160a4203';
