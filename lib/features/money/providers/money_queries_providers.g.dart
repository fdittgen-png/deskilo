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

String _$invoiceQueriesHash() => r'12784231a800773f8a19420dab202df9832352bb';

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
    r'd8c5a1021012aa5cb2c4dd95e317988a22b7ab45';

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
    r'3613b080cd2f35e9ef5fcd903edf2b9269d8d31c';
