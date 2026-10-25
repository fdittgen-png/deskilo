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

/// The full history's reads of my connected hosts: at most
/// `personal.read_concurrency` at once, as on Me › Finances. Closed with
/// the last page that uses it, so nothing waits behind a gone view.

@ProviderFor(financeHistoryReads)
final financeHistoryReadsProvider = FinanceHistoryReadsProvider._();

/// The full history's reads of my connected hosts: at most
/// `personal.read_concurrency` at once, as on Me › Finances. Closed with
/// the last page that uses it, so nothing waits behind a gone view.

final class FinanceHistoryReadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BoundedReads>,
          BoundedReads,
          FutureOr<BoundedReads>
        >
    with $FutureModifier<BoundedReads>, $FutureProvider<BoundedReads> {
  /// The full history's reads of my connected hosts: at most
  /// `personal.read_concurrency` at once, as on Me › Finances. Closed with
  /// the last page that uses it, so nothing waits behind a gone view.
  FinanceHistoryReadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: financeLimitsRetry,
        name: r'financeHistoryReadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeHistoryReadsHash();

  @$internal
  @override
  $FutureProviderElement<BoundedReads> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BoundedReads> create(Ref ref) {
    return financeHistoryReads(ref);
  }
}

String _$financeHistoryReadsHash() =>
    r'74fedfb466d1809fa5691cb1ef05055aa829f396';

/// #2557 C7 — one page of my [kind] history on the connected host [host],
/// through that host's own verified client ([financeHostReader]), waited
/// for `personal.read_timeout_seconds`. Signed out there is none; a new
/// account rebuilds the page, so an answer for the previous one is
/// dropped. A failure is this host's alone and is not retried behind the
/// person's back: the page offers its own Try again.

@ProviderFor(hostAccountActivity)
final hostAccountActivityProvider = HostAccountActivityFamily._();

/// #2557 C7 — one page of my [kind] history on the connected host [host],
/// through that host's own verified client ([financeHostReader]), waited
/// for `personal.read_timeout_seconds`. Signed out there is none; a new
/// account rebuilds the page, so an answer for the previous one is
/// dropped. A failure is this host's alone and is not retried behind the
/// person's back: the page offers its own Try again.

final class HostAccountActivityProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountActivity>>,
          List<AccountActivity>,
          FutureOr<List<AccountActivity>>
        >
    with
        $FutureModifier<List<AccountActivity>>,
        $FutureProvider<List<AccountActivity>> {
  /// #2557 C7 — one page of my [kind] history on the connected host [host],
  /// through that host's own verified client ([financeHostReader]), waited
  /// for `personal.read_timeout_seconds`. Signed out there is none; a new
  /// account rebuilds the page, so an answer for the previous one is
  /// dropped. A failure is this host's alone and is not retried behind the
  /// person's back: the page offers its own Try again.
  HostAccountActivityProvider._({
    required HostAccountActivityFamily super.from,
    required (FinanceHost, AccountActivityKind, {ActivityCursor? before})
    super.argument,
  }) : super(
         retry: financeLimitsRetry,
         name: r'hostAccountActivityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hostAccountActivityHash();

  @override
  String toString() {
    return r'hostAccountActivityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<AccountActivity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AccountActivity>> create(Ref ref) {
    final argument =
        this.argument
            as (FinanceHost, AccountActivityKind, {ActivityCursor? before});
    return hostAccountActivity(
      ref,
      argument.$1,
      argument.$2,
      before: argument.before,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostAccountActivityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hostAccountActivityHash() =>
    r'5db477ec13d63f60439c97d3bc03cc0f18a2f9c0';

/// #2557 C7 — one page of my [kind] history on the connected host [host],
/// through that host's own verified client ([financeHostReader]), waited
/// for `personal.read_timeout_seconds`. Signed out there is none; a new
/// account rebuilds the page, so an answer for the previous one is
/// dropped. A failure is this host's alone and is not retried behind the
/// person's back: the page offers its own Try again.

final class HostAccountActivityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<AccountActivity>>,
          (FinanceHost, AccountActivityKind, {ActivityCursor? before})
        > {
  HostAccountActivityFamily._()
    : super(
        retry: financeLimitsRetry,
        name: r'hostAccountActivityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #2557 C7 — one page of my [kind] history on the connected host [host],
  /// through that host's own verified client ([financeHostReader]), waited
  /// for `personal.read_timeout_seconds`. Signed out there is none; a new
  /// account rebuilds the page, so an answer for the previous one is
  /// dropped. A failure is this host's alone and is not retried behind the
  /// person's back: the page offers its own Try again.

  HostAccountActivityProvider call(
    FinanceHost host,
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) => HostAccountActivityProvider._(
    argument: (host, kind, before: before),
    from: this,
  );

  @override
  String toString() => r'hostAccountActivityProvider';
}
