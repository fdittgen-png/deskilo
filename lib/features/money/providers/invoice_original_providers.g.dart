// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_original_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(invoiceOriginalRepository)
final invoiceOriginalRepositoryProvider = InvoiceOriginalRepositoryProvider._();

final class InvoiceOriginalRepositoryProvider
    extends
        $FunctionalProvider<
          InvoiceOriginalRepository,
          InvoiceOriginalRepository,
          InvoiceOriginalRepository
        >
    with $Provider<InvoiceOriginalRepository> {
  InvoiceOriginalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceOriginalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceOriginalRepositoryHash();

  @$internal
  @override
  $ProviderElement<InvoiceOriginalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceOriginalRepository create(Ref ref) {
    return invoiceOriginalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceOriginalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceOriginalRepository>(value),
    );
  }
}

String _$invoiceOriginalRepositoryHash() =>
    r'112f0e1b5268a50ec5508490a50b3c18f3396385';

/// The document of an invoice, from its stored original.

@ProviderFor(invoiceOriginals)
final invoiceOriginalsProvider = InvoiceOriginalsProvider._();

/// The document of an invoice, from its stored original.

final class InvoiceOriginalsProvider
    extends
        $FunctionalProvider<
          InvoiceOriginals,
          InvoiceOriginals,
          InvoiceOriginals
        >
    with $Provider<InvoiceOriginals> {
  /// The document of an invoice, from its stored original.
  InvoiceOriginalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceOriginalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceOriginalsHash();

  @$internal
  @override
  $ProviderElement<InvoiceOriginals> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InvoiceOriginals create(Ref ref) {
    return invoiceOriginals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceOriginals value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceOriginals>(value),
    );
  }
}

String _$invoiceOriginalsHash() => r'2daa917e012b809b59e8ef646eea5ef252cb43aa';

/// #3853 — the record of the stored original of the invoice [invoiceId] of
/// [workspaceId], or null when none is kept yet.

@ProviderFor(invoiceOriginal)
final invoiceOriginalProvider = InvoiceOriginalFamily._();

/// #3853 — the record of the stored original of the invoice [invoiceId] of
/// [workspaceId], or null when none is kept yet.

final class InvoiceOriginalProvider
    extends
        $FunctionalProvider<
          AsyncValue<InvoiceOriginal?>,
          InvoiceOriginal?,
          FutureOr<InvoiceOriginal?>
        >
    with $FutureModifier<InvoiceOriginal?>, $FutureProvider<InvoiceOriginal?> {
  /// #3853 — the record of the stored original of the invoice [invoiceId] of
  /// [workspaceId], or null when none is kept yet.
  InvoiceOriginalProvider._({
    required InvoiceOriginalFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'invoiceOriginalProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$invoiceOriginalHash();

  @override
  String toString() {
    return r'invoiceOriginalProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<InvoiceOriginal?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InvoiceOriginal?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return invoiceOriginal(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is InvoiceOriginalProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$invoiceOriginalHash() => r'698126a71fced0e9d98539094487367190b6e300';

/// #3853 — the record of the stored original of the invoice [invoiceId] of
/// [workspaceId], or null when none is kept yet.

final class InvoiceOriginalFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<InvoiceOriginal?>,
          (String, String)
        > {
  InvoiceOriginalFamily._()
    : super(
        retry: null,
        name: r'invoiceOriginalProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #3853 — the record of the stored original of the invoice [invoiceId] of
  /// [workspaceId], or null when none is kept yet.

  InvoiceOriginalProvider call(String workspaceId, String invoiceId) =>
      InvoiceOriginalProvider._(argument: (workspaceId, invoiceId), from: this);

  @override
  String toString() => r'invoiceOriginalProvider';
}
