// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2472 (P) — the directory reader, always at the personal home; a new
/// account is a new reader.

@ProviderFor(personalMessageDirectoryRepository)
final personalMessageDirectoryRepositoryProvider =
    PersonalMessageDirectoryRepositoryProvider._();

/// #2472 (P) — the directory reader, always at the personal home; a new
/// account is a new reader.

final class PersonalMessageDirectoryRepositoryProvider
    extends
        $FunctionalProvider<
          PersonalMessageDirectoryRepository,
          PersonalMessageDirectoryRepository,
          PersonalMessageDirectoryRepository
        >
    with $Provider<PersonalMessageDirectoryRepository> {
  /// #2472 (P) — the directory reader, always at the personal home; a new
  /// account is a new reader.
  PersonalMessageDirectoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalMessageDirectoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$personalMessageDirectoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<PersonalMessageDirectoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalMessageDirectoryRepository create(Ref ref) {
    return personalMessageDirectoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalMessageDirectoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalMessageDirectoryRepository>(
        value,
      ),
    );
  }
}

String _$personalMessageDirectoryRepositoryHash() =>
    r'017fce210cbcfe46f58f4754d6dffdec3b11d3ac';

/// What the new discussion lists before any search: every workspace I hold
/// a relationship with, the first page of each one's people, and every
/// group I am in. A home without the reader fails with
/// [DirectoryFailure.unsupported], which the screen answers with the
/// per-server directory; any other failure is shown, never read as empty.

@ProviderFor(PersonalDirectoryController)
final personalDirectoryControllerProvider =
    PersonalDirectoryControllerProvider._();

/// What the new discussion lists before any search: every workspace I hold
/// a relationship with, the first page of each one's people, and every
/// group I am in. A home without the reader fails with
/// [DirectoryFailure.unsupported], which the screen answers with the
/// per-server directory; any other failure is shown, never read as empty.
final class PersonalDirectoryControllerProvider
    extends
        $AsyncNotifierProvider<PersonalDirectoryController, PersonalDirectory> {
  /// What the new discussion lists before any search: every workspace I hold
  /// a relationship with, the first page of each one's people, and every
  /// group I am in. A home without the reader fails with
  /// [DirectoryFailure.unsupported], which the screen answers with the
  /// per-server directory; any other failure is shown, never read as empty.
  PersonalDirectoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: personalDirectoryRetry,
        name: r'personalDirectoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalDirectoryControllerHash();

  @$internal
  @override
  PersonalDirectoryController create() => PersonalDirectoryController();
}

String _$personalDirectoryControllerHash() =>
    r'347d3ee446c8e4d1447de725dceefd7708073f6c';

/// What the new discussion lists before any search: every workspace I hold
/// a relationship with, the first page of each one's people, and every
/// group I am in. A home without the reader fails with
/// [DirectoryFailure.unsupported], which the screen answers with the
/// per-server directory; any other failure is shown, never read as empty.

abstract class _$PersonalDirectoryController
    extends $AsyncNotifier<PersonalDirectory> {
  FutureOr<PersonalDirectory> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PersonalDirectory>, PersonalDirectory>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PersonalDirectory>, PersonalDirectory>,
              AsyncValue<PersonalDirectory>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
