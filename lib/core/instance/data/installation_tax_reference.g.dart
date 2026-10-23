// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installation_tax_reference.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The installation's rows; the bundled copy when it cannot answer or holds
/// none.

@ProviderFor(workspaceTaxReferenceReader)
final workspaceTaxReferenceReaderProvider =
    WorkspaceTaxReferenceReaderProvider._();

/// The installation's rows; the bundled copy when it cannot answer or holds
/// none.

final class WorkspaceTaxReferenceReaderProvider
    extends
        $FunctionalProvider<
          WorkspaceTaxReferenceReader,
          WorkspaceTaxReferenceReader,
          WorkspaceTaxReferenceReader
        >
    with $Provider<WorkspaceTaxReferenceReader> {
  /// The installation's rows; the bundled copy when it cannot answer or holds
  /// none.
  WorkspaceTaxReferenceReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceTaxReferenceReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceTaxReferenceReaderHash();

  @$internal
  @override
  $ProviderElement<WorkspaceTaxReferenceReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceTaxReferenceReader create(Ref ref) {
    return workspaceTaxReferenceReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceTaxReferenceReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceTaxReferenceReader>(value),
    );
  }
}

String _$workspaceTaxReferenceReaderHash() =>
    r'702f88ae81e07f0269232ec06a76f437800e4cea';
