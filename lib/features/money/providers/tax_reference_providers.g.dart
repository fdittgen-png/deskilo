// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_reference_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2477 -- the tax reference store: read and (platform owners) written.

@ProviderFor(taxReferenceRepository)
final taxReferenceRepositoryProvider = TaxReferenceRepositoryProvider._();

/// #2477 -- the tax reference store: read and (platform owners) written.

final class TaxReferenceRepositoryProvider
    extends
        $FunctionalProvider<
          TaxReferenceStore,
          TaxReferenceStore,
          TaxReferenceStore
        >
    with $Provider<TaxReferenceStore> {
  /// #2477 -- the tax reference store: read and (platform owners) written.
  TaxReferenceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReferenceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReferenceRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaxReferenceStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaxReferenceStore create(Ref ref) {
    return taxReferenceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaxReferenceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaxReferenceStore>(value),
    );
  }
}

String _$taxReferenceRepositoryHash() =>
    r'fdefc1c3fc8f1c3037195a8338a2e7dbc36face3';

/// Creating a new version (the form's decision).

@ProviderFor(taxReferenceCommands)
final taxReferenceCommandsProvider = TaxReferenceCommandsProvider._();

/// Creating a new version (the form's decision).

final class TaxReferenceCommandsProvider
    extends
        $FunctionalProvider<
          TaxReferenceCommands,
          TaxReferenceCommands,
          TaxReferenceCommands
        >
    with $Provider<TaxReferenceCommands> {
  /// Creating a new version (the form's decision).
  TaxReferenceCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReferenceCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReferenceCommandsHash();

  @$internal
  @override
  $ProviderElement<TaxReferenceCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaxReferenceCommands create(Ref ref) {
    return taxReferenceCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaxReferenceCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaxReferenceCommands>(value),
    );
  }
}

String _$taxReferenceCommandsHash() =>
    r'6ab7ddb069673161fc2277636a7164009f1cfe77';

/// The store, falling back to the copy bundled with the app when the
/// installation cannot answer.

@ProviderFor(taxReferenceSource)
final taxReferenceSourceProvider = TaxReferenceSourceProvider._();

/// The store, falling back to the copy bundled with the app when the
/// installation cannot answer.

final class TaxReferenceSourceProvider
    extends
        $FunctionalProvider<
          TaxReferenceSource,
          TaxReferenceSource,
          TaxReferenceSource
        >
    with $Provider<TaxReferenceSource> {
  /// The store, falling back to the copy bundled with the app when the
  /// installation cannot answer.
  TaxReferenceSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReferenceSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReferenceSourceHash();

  @$internal
  @override
  $ProviderElement<TaxReferenceSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaxReferenceSource create(Ref ref) {
    return taxReferenceSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaxReferenceSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaxReferenceSource>(value),
    );
  }
}

String _$taxReferenceSourceHash() =>
    r'19ebcf8a687b3955d9160c7cf9d7633a5eb54952';

/// Every version of every reference value, for the signed-in person on the
/// installation they are connected to. A different person re-reads it (the
/// provider watches the session); a write invalidates it.

@ProviderFor(taxReferenceSet)
final taxReferenceSetProvider = TaxReferenceSetProvider._();

/// Every version of every reference value, for the signed-in person on the
/// installation they are connected to. A different person re-reads it (the
/// provider watches the session); a write invalidates it.

final class TaxReferenceSetProvider
    extends
        $FunctionalProvider<
          AsyncValue<TaxReferenceSet>,
          TaxReferenceSet,
          FutureOr<TaxReferenceSet>
        >
    with $FutureModifier<TaxReferenceSet>, $FutureProvider<TaxReferenceSet> {
  /// Every version of every reference value, for the signed-in person on the
  /// installation they are connected to. A different person re-reads it (the
  /// provider watches the session); a write invalidates it.
  TaxReferenceSetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReferenceSetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReferenceSetHash();

  @$internal
  @override
  $FutureProviderElement<TaxReferenceSet> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TaxReferenceSet> create(Ref ref) {
    return taxReferenceSet(ref);
  }
}

String _$taxReferenceSetHash() => r'61b820098fba461e0615d6a7e880ce77eeaf12bc';

/// #2478 -- the installation's rows become the snapshot the VAT functions run
/// on (the bundled copy stands until they arrive, and when they cannot).

@ProviderFor(activeTaxReference)
final activeTaxReferenceProvider = ActiveTaxReferenceProvider._();

/// #2478 -- the installation's rows become the snapshot the VAT functions run
/// on (the bundled copy stands until they arrive, and when they cannot).

final class ActiveTaxReferenceProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// #2478 -- the installation's rows become the snapshot the VAT functions run
  /// on (the bundled copy stands until they arrive, and when they cannot).
  ActiveTaxReferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTaxReferenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTaxReferenceHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return activeTaxReference(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$activeTaxReferenceHash() =>
    r'613e603623815c39013e01b5df8860623b22ccb1';
