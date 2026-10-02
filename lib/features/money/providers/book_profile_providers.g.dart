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
    r'00e1516d2fd1e88675d53742300a8daf6faaed69';

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
