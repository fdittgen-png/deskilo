// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_host_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The workspace hosts my personal account names. None by default (the
/// personal home and the selected workspace answer alone); the composition
/// root replaces it with every host my personal account names
/// (`financeHostsFromMe`, lib/app).

@ProviderFor(financeHosts)
final financeHostsProvider = FinanceHostsProvider._();

/// The workspace hosts my personal account names. None by default (the
/// personal home and the selected workspace answer alone); the composition
/// root replaces it with every host my personal account names
/// (`financeHostsFromMe`, lib/app).

final class FinanceHostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FinanceHost>>,
          List<FinanceHost>,
          FutureOr<List<FinanceHost>>
        >
    with
        $FutureModifier<List<FinanceHost>>,
        $FutureProvider<List<FinanceHost>> {
  /// The workspace hosts my personal account names. None by default (the
  /// personal home and the selected workspace answer alone); the composition
  /// root replaces it with every host my personal account names
  /// (`financeHostsFromMe`, lib/app).
  FinanceHostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeHostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeHostsHash();

  @$internal
  @override
  $FutureProviderElement<List<FinanceHost>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FinanceHost>> create(Ref ref) {
    return financeHosts(ref);
  }
}

String _$financeHostsHash() => r'3fde4c4cb3a5bf7fb6940afa5f7b858a5f69aad5';

/// One host read through its own verified client. Demo overrides it with
/// the fixture's spaces.

@ProviderFor(financeHostReader)
final financeHostReaderProvider = FinanceHostReaderProvider._();

/// One host read through its own verified client. Demo overrides it with
/// the fixture's spaces.

final class FinanceHostReaderProvider
    extends
        $FunctionalProvider<
          FinanceHostReader,
          FinanceHostReader,
          FinanceHostReader
        >
    with $Provider<FinanceHostReader> {
  /// One host read through its own verified client. Demo overrides it with
  /// the fixture's spaces.
  FinanceHostReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeHostReaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeHostReaderHash();

  @$internal
  @override
  $ProviderElement<FinanceHostReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinanceHostReader create(Ref ref) {
    return financeHostReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceHostReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceHostReader>(value),
    );
  }
}

String _$financeHostReaderHash() => r'bb9e66b778360131940ee72a11176bd068f9e340';

/// How many hosts are read at once and how long one is waited for: the
/// personal home's `personal.read_concurrency` and
/// `personal.read_timeout_seconds`, the same limits My reservations reads
/// under. A registry without the rows fails typed, once.

@ProviderFor(financeReadLimits)
final financeReadLimitsProvider = FinanceReadLimitsProvider._();

/// How many hosts are read at once and how long one is waited for: the
/// personal home's `personal.read_concurrency` and
/// `personal.read_timeout_seconds`, the same limits My reservations reads
/// under. A registry without the rows fails typed, once.

final class FinanceReadLimitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<FinanceReadLimits>,
          FinanceReadLimits,
          FutureOr<FinanceReadLimits>
        >
    with
        $FutureModifier<FinanceReadLimits>,
        $FutureProvider<FinanceReadLimits> {
  /// How many hosts are read at once and how long one is waited for: the
  /// personal home's `personal.read_concurrency` and
  /// `personal.read_timeout_seconds`, the same limits My reservations reads
  /// under. A registry without the rows fails typed, once.
  FinanceReadLimitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: financeLimitsRetry,
        name: r'financeReadLimitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeReadLimitsHash();

  @$internal
  @override
  $FutureProviderElement<FinanceReadLimits> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FinanceReadLimits> create(Ref ref) {
    return financeReadLimits(ref);
  }
}

String _$financeReadLimitsHash() => r'4e0a7f2bb0413cb13f43b3153f4a7f3f8e03e51f';
