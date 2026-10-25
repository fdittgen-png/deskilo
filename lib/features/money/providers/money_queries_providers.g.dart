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

/// Whether [workspaceId] has issued a document or recorded money, which
/// fixes its country and currency (0399). Not retried: a page that cannot
/// tell treats the values as open, and the server still refuses.

@ProviderFor(moneyRecorded)
final moneyRecordedProvider = MoneyRecordedFamily._();

/// Whether [workspaceId] has issued a document or recorded money, which
/// fixes its country and currency (0399). Not retried: a page that cannot
/// tell treats the values as open, and the server still refuses.

final class MoneyRecordedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether [workspaceId] has issued a document or recorded money, which
  /// fixes its country and currency (0399). Not retried: a page that cannot
  /// tell treats the values as open, and the server still refuses.
  MoneyRecordedProvider._({
    required MoneyRecordedFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'moneyRecordedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$moneyRecordedHash();

  @override
  String toString() {
    return r'moneyRecordedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return moneyRecorded(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MoneyRecordedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$moneyRecordedHash() => r'4ceeff00944d59d19ed891fb480e6f17f4fbdd94';

/// Whether [workspaceId] has issued a document or recorded money, which
/// fixes its country and currency (0399). Not retried: a page that cannot
/// tell treats the values as open, and the server still refuses.

final class MoneyRecordedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  MoneyRecordedFamily._()
    : super(
        retry: _noRetry,
        name: r'moneyRecordedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether [workspaceId] has issued a document or recorded money, which
  /// fixes its country and currency (0399). Not retried: a page that cannot
  /// tell treats the values as open, and the server still refuses.

  MoneyRecordedProvider call(String workspaceId) =>
      MoneyRecordedProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'moneyRecordedProvider';
}

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

/// #2585 C2 — void and refund under a request id, read back by it.

@ProviderFor(invoiceActionCommands)
final invoiceActionCommandsProvider = InvoiceActionCommandsProvider._();

/// #2585 C2 — void and refund under a request id, read back by it.

final class InvoiceActionCommandsProvider
    extends
        $FunctionalProvider<
          InvoiceActionCommands,
          InvoiceActionCommands,
          InvoiceActionCommands
        >
    with $Provider<InvoiceActionCommands> {
  /// #2585 C2 — void and refund under a request id, read back by it.
  InvoiceActionCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceActionCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceActionCommandsHash();

  @$internal
  @override
  $ProviderElement<InvoiceActionCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceActionCommands create(Ref ref) {
    return invoiceActionCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceActionCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceActionCommands>(value),
    );
  }
}

String _$invoiceActionCommandsHash() =>
    r'8ba93b0a284d5e9201a7014eaece8a0ea3e989ff';

/// #2585 C2 — void / refund exactly once, and look for the answer by the
/// attempt's request id.

@ProviderFor(invoiceReceiptActions)
final invoiceReceiptActionsProvider = InvoiceReceiptActionsProvider._();

/// #2585 C2 — void / refund exactly once, and look for the answer by the
/// attempt's request id.

final class InvoiceReceiptActionsProvider
    extends
        $FunctionalProvider<
          InvoiceReceiptActions,
          InvoiceReceiptActions,
          InvoiceReceiptActions
        >
    with $Provider<InvoiceReceiptActions> {
  /// #2585 C2 — void / refund exactly once, and look for the answer by the
  /// attempt's request id.
  InvoiceReceiptActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceReceiptActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceReceiptActionsHash();

  @$internal
  @override
  $ProviderElement<InvoiceReceiptActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceReceiptActions create(Ref ref) {
    return invoiceReceiptActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceReceiptActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceReceiptActions>(value),
    );
  }
}

String _$invoiceReceiptActionsHash() =>
    r'842a3d8e79c326b8f4dbf37d5b7a189b879c42d4';

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

/// #2591 — the dunning policy, its sweep and the holds on an invoice.

@ProviderFor(dunningRepository)
final dunningRepositoryProvider = DunningRepositoryProvider._();

/// #2591 — the dunning policy, its sweep and the holds on an invoice.

final class DunningRepositoryProvider
    extends
        $FunctionalProvider<
          DunningRepository,
          DunningRepository,
          DunningRepository
        >
    with $Provider<DunningRepository> {
  /// #2591 — the dunning policy, its sweep and the holds on an invoice.
  DunningRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dunningRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dunningRepositoryHash();

  @$internal
  @override
  $ProviderElement<DunningRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DunningRepository create(Ref ref) {
    return dunningRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DunningRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DunningRepository>(value),
    );
  }
}

String _$dunningRepositoryHash() => r'34e0bc7e1d71845ad7fa400c40163de4554cbeb0';

/// #2591 — when the invoice runs happen, the remembered repartition rule
/// and the workspace status the repartition wizard reads.

@ProviderFor(billingRulesRepository)
final billingRulesRepositoryProvider = BillingRulesRepositoryProvider._();

/// #2591 — when the invoice runs happen, the remembered repartition rule
/// and the workspace status the repartition wizard reads.

final class BillingRulesRepositoryProvider
    extends
        $FunctionalProvider<
          BillingRulesRepository,
          BillingRulesRepository,
          BillingRulesRepository
        >
    with $Provider<BillingRulesRepository> {
  /// #2591 — when the invoice runs happen, the remembered repartition rule
  /// and the workspace status the repartition wizard reads.
  BillingRulesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingRulesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingRulesRepositoryHash();

  @$internal
  @override
  $ProviderElement<BillingRulesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BillingRulesRepository create(Ref ref) {
    return billingRulesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BillingRulesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BillingRulesRepository>(value),
    );
  }
}

String _$billingRulesRepositoryHash() =>
    r'1ea322349411b5a9e760bb0392e45b5e0b419918';

/// #2591 — the number series and the invoice fingerprint check.

@ProviderFor(documentNumbering)
final documentNumberingProvider = DocumentNumberingProvider._();

/// #2591 — the number series and the invoice fingerprint check.

final class DocumentNumberingProvider
    extends
        $FunctionalProvider<
          DocumentNumbering,
          DocumentNumbering,
          DocumentNumbering
        >
    with $Provider<DocumentNumbering> {
  /// #2591 — the number series and the invoice fingerprint check.
  DocumentNumberingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentNumberingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentNumberingHash();

  @$internal
  @override
  $ProviderElement<DocumentNumbering> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DocumentNumbering create(Ref ref) {
    return documentNumbering(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentNumbering value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentNumbering>(value),
    );
  }
}

String _$documentNumberingHash() => r'64b1998f694cbce613eb07a7662c9e75fcb5fc71';

/// #2591 — payments, service charges, packages and usage requests
/// recorded against a member's account.

@ProviderFor(memberAccountCommands)
final memberAccountCommandsProvider = MemberAccountCommandsProvider._();

/// #2591 — payments, service charges, packages and usage requests
/// recorded against a member's account.

final class MemberAccountCommandsProvider
    extends
        $FunctionalProvider<
          MemberAccountCommands,
          MemberAccountCommands,
          MemberAccountCommands
        >
    with $Provider<MemberAccountCommands> {
  /// #2591 — payments, service charges, packages and usage requests
  /// recorded against a member's account.
  MemberAccountCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberAccountCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberAccountCommandsHash();

  @$internal
  @override
  $ProviderElement<MemberAccountCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberAccountCommands create(Ref ref) {
    return memberAccountCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberAccountCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberAccountCommands>(value),
    );
  }
}

String _$memberAccountCommandsHash() =>
    r'a35d33835638fd328f28796edc1569b72b62a72a';

/// #2591 — online payments: attempts, providers, credentials, checkout.

@ProviderFor(paymentGatewayRepository)
final paymentGatewayRepositoryProvider = PaymentGatewayRepositoryProvider._();

/// #2591 — online payments: attempts, providers, credentials, checkout.

final class PaymentGatewayRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentGatewayRepository,
          PaymentGatewayRepository,
          PaymentGatewayRepository
        >
    with $Provider<PaymentGatewayRepository> {
  /// #2591 — online payments: attempts, providers, credentials, checkout.
  PaymentGatewayRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentGatewayRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentGatewayRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentGatewayRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentGatewayRepository create(Ref ref) {
    return paymentGatewayRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentGatewayRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentGatewayRepository>(value),
    );
  }
}

String _$paymentGatewayRepositoryHash() =>
    r'82d8dd3b99b1f13a20499f35984a4054fc99e083';

/// #2591 — e-invoice transmission, its receipts and channel credentials.

@ProviderFor(eInvoiceTransmissions)
final eInvoiceTransmissionsProvider = EInvoiceTransmissionsProvider._();

/// #2591 — e-invoice transmission, its receipts and channel credentials.

final class EInvoiceTransmissionsProvider
    extends
        $FunctionalProvider<
          EInvoiceTransmissions,
          EInvoiceTransmissions,
          EInvoiceTransmissions
        >
    with $Provider<EInvoiceTransmissions> {
  /// #2591 — e-invoice transmission, its receipts and channel credentials.
  EInvoiceTransmissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eInvoiceTransmissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eInvoiceTransmissionsHash();

  @$internal
  @override
  $ProviderElement<EInvoiceTransmissions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EInvoiceTransmissions create(Ref ref) {
    return eInvoiceTransmissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EInvoiceTransmissions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EInvoiceTransmissions>(value),
    );
  }
}

String _$eInvoiceTransmissionsHash() =>
    r'b26994d7c9edb702b5039a27c589dc8561499dfd';
