// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vat_declaration_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The workspace's VAT declarations (0107), newest period first. Own
/// file so money_providers.dart stays at its file_length snapshot.

@ProviderFor(vatDeclarations)
final vatDeclarationsProvider = VatDeclarationsProvider._();

/// The workspace's VAT declarations (0107), newest period first. Own
/// file so money_providers.dart stays at its file_length snapshot.

final class VatDeclarationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VatDeclaration>>,
          List<VatDeclaration>,
          FutureOr<List<VatDeclaration>>
        >
    with
        $FutureModifier<List<VatDeclaration>>,
        $FutureProvider<List<VatDeclaration>> {
  /// The workspace's VAT declarations (0107), newest period first. Own
  /// file so money_providers.dart stays at its file_length snapshot.
  VatDeclarationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vatDeclarationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vatDeclarationsHash();

  @$internal
  @override
  $FutureProviderElement<List<VatDeclaration>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VatDeclaration>> create(Ref ref) {
    return vatDeclarations(ref);
  }
}

String _$vatDeclarationsHash() => r'00dd7b8463c8147ef26e527bb5e36f40f2bef799';

/// #2357 — saving the filing file of a return, for the space as it is.

@ProviderFor(saveVatFilingFile)
final saveVatFilingFileProvider = SaveVatFilingFileProvider._();

/// #2357 — saving the filing file of a return, for the space as it is.

final class SaveVatFilingFileProvider
    extends
        $FunctionalProvider<
          SaveVatFilingFile,
          SaveVatFilingFile,
          SaveVatFilingFile
        >
    with $Provider<SaveVatFilingFile> {
  /// #2357 — saving the filing file of a return, for the space as it is.
  SaveVatFilingFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveVatFilingFileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveVatFilingFileHash();

  @$internal
  @override
  $ProviderElement<SaveVatFilingFile> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveVatFilingFile create(Ref ref) {
    return saveVatFilingFile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveVatFilingFile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveVatFilingFile>(value),
    );
  }
}

String _$saveVatFilingFileHash() => r'e14d01d40fcc13481d1ddb973302f90236bf21b0';
