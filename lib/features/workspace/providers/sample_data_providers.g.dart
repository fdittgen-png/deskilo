// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 0546 — sample data in the owner's test space.

@ProviderFor(sampleDataRepository)
final sampleDataRepositoryProvider = SampleDataRepositoryProvider._();

/// 0546 — sample data in the owner's test space.

final class SampleDataRepositoryProvider
    extends
        $FunctionalProvider<
          SampleDataRepository,
          SampleDataRepository,
          SampleDataRepository
        >
    with $Provider<SampleDataRepository> {
  /// 0546 — sample data in the owner's test space.
  SampleDataRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sampleDataRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sampleDataRepositoryHash();

  @$internal
  @override
  $ProviderElement<SampleDataRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SampleDataRepository create(Ref ref) {
    return sampleDataRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SampleDataRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SampleDataRepository>(value),
    );
  }
}

String _$sampleDataRepositoryHash() =>
    r'b50ab7a62da1fac4bdd79bde6523533a6f3df6ef';

/// The space's open sample batch, or null when it holds none.

@ProviderFor(sampleDataStatus)
final sampleDataStatusProvider = SampleDataStatusFamily._();

/// The space's open sample batch, or null when it holds none.

final class SampleDataStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SampleDataBatch?>,
          SampleDataBatch?,
          FutureOr<SampleDataBatch?>
        >
    with $FutureModifier<SampleDataBatch?>, $FutureProvider<SampleDataBatch?> {
  /// The space's open sample batch, or null when it holds none.
  SampleDataStatusProvider._({
    required SampleDataStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'sampleDataStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sampleDataStatusHash();

  @override
  String toString() {
    return r'sampleDataStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SampleDataBatch?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SampleDataBatch?> create(Ref ref) {
    final argument = this.argument as String;
    return sampleDataStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SampleDataStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sampleDataStatusHash() => r'c139432aeb2816cc903c8d549556ce1ba2ac0ec6';

/// The space's open sample batch, or null when it holds none.

final class SampleDataStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SampleDataBatch?>, String> {
  SampleDataStatusFamily._()
    : super(
        retry: _noRetry,
        name: r'sampleDataStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The space's open sample batch, or null when it holds none.

  SampleDataStatusProvider call(String workspaceId) =>
      SampleDataStatusProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'sampleDataStatusProvider';
}
