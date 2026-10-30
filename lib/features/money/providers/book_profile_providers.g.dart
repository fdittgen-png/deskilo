// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1869 — where book profiles are read and saved.

@ProviderFor(bookProfileRepository)
final bookProfileRepositoryProvider = BookProfileRepositoryProvider._();

/// #1869 — where book profiles are read and saved.

final class BookProfileRepositoryProvider
    extends
        $FunctionalProvider<
          BookProfileRepository,
          BookProfileRepository,
          BookProfileRepository
        >
    with $Provider<BookProfileRepository> {
  /// #1869 — where book profiles are read and saved.
  BookProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookProfileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookProfileRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookProfileRepository create(Ref ref) {
    return bookProfileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookProfileRepository>(value),
    );
  }
}

String _$bookProfileRepositoryHash() =>
    r'88ac10b9be3205f7bbbe64ded17b0e5a88bc37e5';

/// Saving a book profile (the decision the sheet asks for).

@ProviderFor(bookProfileCommands)
final bookProfileCommandsProvider = BookProfileCommandsProvider._();

/// Saving a book profile (the decision the sheet asks for).

final class BookProfileCommandsProvider
    extends $FunctionalProvider<BookProfiles, BookProfiles, BookProfiles>
    with $Provider<BookProfiles> {
  /// Saving a book profile (the decision the sheet asks for).
  BookProfileCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookProfileCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookProfileCommandsHash();

  @$internal
  @override
  $ProviderElement<BookProfiles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookProfiles create(Ref ref) {
    return bookProfileCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookProfiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookProfiles>(value),
    );
  }
}

String _$bookProfileCommandsHash() =>
    r'5abb981f4cc021c488b4a73be3ed0580456bfb19';

/// Every version of every issuer's book profile in the current
/// workspace; invalidated after a save.

@ProviderFor(bookProfiles)
final bookProfilesProvider = BookProfilesProvider._();

/// Every version of every issuer's book profile in the current
/// workspace; invalidated after a save.

final class BookProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BookProfile>>,
          List<BookProfile>,
          FutureOr<List<BookProfile>>
        >
    with
        $FutureModifier<List<BookProfile>>,
        $FutureProvider<List<BookProfile>> {
  /// Every version of every issuer's book profile in the current
  /// workspace; invalidated after a save.
  BookProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookProfilesHash();

  @$internal
  @override
  $FutureProviderElement<List<BookProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BookProfile>> create(Ref ref) {
    return bookProfiles(ref);
  }
}

String _$bookProfilesHash() => r'07dd02e47d1738fb991f5f7df9d7a72635b7e336';

/// #1869 B — every issuer's accounts and role mappings in the current
/// workspace; invalidated after a save.

@ProviderFor(bookChart)
final bookChartProvider = BookChartProvider._();

/// #1869 B — every issuer's accounts and role mappings in the current
/// workspace; invalidated after a save.

final class BookChartProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            ({List<BookAccount> accounts, List<BookMapping> mappings})
          >,
          ({List<BookAccount> accounts, List<BookMapping> mappings}),
          FutureOr<({List<BookAccount> accounts, List<BookMapping> mappings})>
        >
    with
        $FutureModifier<
          ({List<BookAccount> accounts, List<BookMapping> mappings})
        >,
        $FutureProvider<
          ({List<BookAccount> accounts, List<BookMapping> mappings})
        > {
  /// #1869 B — every issuer's accounts and role mappings in the current
  /// workspace; invalidated after a save.
  BookChartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookChartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookChartHash();

  @$internal
  @override
  $FutureProviderElement<
    ({List<BookAccount> accounts, List<BookMapping> mappings})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({List<BookAccount> accounts, List<BookMapping> mappings})> create(
    Ref ref,
  ) {
    return bookChart(ref);
  }
}

String _$bookChartHash() => r'975cd6e18c476a84226bbc161354c24da6a3e02f';

/// #2571 — where retention holds are read, placed and released.

@ProviderFor(retentionHoldRepository)
final retentionHoldRepositoryProvider = RetentionHoldRepositoryProvider._();

/// #2571 — where retention holds are read, placed and released.

final class RetentionHoldRepositoryProvider
    extends
        $FunctionalProvider<
          RetentionHoldRepository,
          RetentionHoldRepository,
          RetentionHoldRepository
        >
    with $Provider<RetentionHoldRepository> {
  /// #2571 — where retention holds are read, placed and released.
  RetentionHoldRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionHoldRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldRepositoryHash();

  @$internal
  @override
  $ProviderElement<RetentionHoldRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RetentionHoldRepository create(Ref ref) {
    return retentionHoldRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetentionHoldRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetentionHoldRepository>(value),
    );
  }
}

String _$retentionHoldRepositoryHash() =>
    r'e5528a4a73118c2f5c07bd7a1d14f75cff9cf766';

/// Placing and releasing a hold (the decision the retention dialog asks for).

@ProviderFor(retentionHoldCommands)
final retentionHoldCommandsProvider = RetentionHoldCommandsProvider._();

/// Placing and releasing a hold (the decision the retention dialog asks for).

final class RetentionHoldCommandsProvider
    extends $FunctionalProvider<RetentionHolds, RetentionHolds, RetentionHolds>
    with $Provider<RetentionHolds> {
  /// Placing and releasing a hold (the decision the retention dialog asks for).
  RetentionHoldCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionHoldCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldCommandsHash();

  @$internal
  @override
  $ProviderElement<RetentionHolds> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RetentionHolds create(Ref ref) {
    return retentionHoldCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetentionHolds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetentionHolds>(value),
    );
  }
}

String _$retentionHoldCommandsHash() =>
    r'326bcb7278a054e9943b072574a98f53c144755e';

/// Every hold of the current workspace, the active ones first; invalidated
/// after a change.

@ProviderFor(retentionHolds)
final retentionHoldsProvider = RetentionHoldsProvider._();

/// Every hold of the current workspace, the active ones first; invalidated
/// after a change.

final class RetentionHoldsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RetentionHold>>,
          List<RetentionHold>,
          FutureOr<List<RetentionHold>>
        >
    with
        $FutureModifier<List<RetentionHold>>,
        $FutureProvider<List<RetentionHold>> {
  /// Every hold of the current workspace, the active ones first; invalidated
  /// after a change.
  RetentionHoldsProvider._()
    : super(
        from: null,
        argument: null,
        retry: _holdsNoRetry,
        name: r'retentionHoldsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionHoldsHash();

  @$internal
  @override
  $FutureProviderElement<List<RetentionHold>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RetentionHold>> create(Ref ref) {
    return retentionHolds(ref);
  }
}

String _$retentionHoldsHash() => r'4aa2260086fbd507ab36856c5babc788f6c52d0a';
