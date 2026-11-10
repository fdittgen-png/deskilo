// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_kind_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessKindRepository)
final businessKindRepositoryProvider = BusinessKindRepositoryProvider._();

final class BusinessKindRepositoryProvider
    extends
        $FunctionalProvider<
          BusinessKindRepository,
          BusinessKindRepository,
          BusinessKindRepository
        >
    with $Provider<BusinessKindRepository> {
  BusinessKindRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessKindRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessKindRepositoryHash();

  @$internal
  @override
  $ProviderElement<BusinessKindRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessKindRepository create(Ref ref) {
    return businessKindRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessKindRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessKindRepository>(value),
    );
  }
}

String _$businessKindRepositoryHash() =>
    r'fcb1236a9b4edaf26cc59b5d5578712589747770';

/// The kinds of business, in their order.

@ProviderFor(businessKinds)
final businessKindsProvider = BusinessKindsProvider._();

/// The kinds of business, in their order.

final class BusinessKindsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BusinessKind>>,
          List<BusinessKind>,
          FutureOr<List<BusinessKind>>
        >
    with
        $FutureModifier<List<BusinessKind>>,
        $FutureProvider<List<BusinessKind>> {
  /// The kinds of business, in their order.
  BusinessKindsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessKindsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessKindsHash();

  @$internal
  @override
  $FutureProviderElement<List<BusinessKind>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BusinessKind>> create(Ref ref) {
    return businessKinds(ref);
  }
}

String _$businessKindsHash() => r'897f6918f424f411d2b020c58d5d258e7de9f97b';

/// What the selected workspace says it is (coworking until it says otherwise).

@ProviderFor(businessProfile)
final businessProfileProvider = BusinessProfileProvider._();

/// What the selected workspace says it is (coworking until it says otherwise).

final class BusinessProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessProfile>,
          BusinessProfile,
          FutureOr<BusinessProfile>
        >
    with $FutureModifier<BusinessProfile>, $FutureProvider<BusinessProfile> {
  /// What the selected workspace says it is (coworking until it says otherwise).
  BusinessProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessProfileHash();

  @$internal
  @override
  $FutureProviderElement<BusinessProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessProfile> create(Ref ref) {
    return businessProfile(ref);
  }
}

String _$businessProfileHash() => r'36f2482fa29c01b3892e1c0df5ccc48163f508c8';

/// What the kind chooser does.

@ProviderFor(businessKindCommands)
final businessKindCommandsProvider = BusinessKindCommandsProvider._();

/// What the kind chooser does.

final class BusinessKindCommandsProvider
    extends
        $FunctionalProvider<
          BusinessKindCommands,
          BusinessKindCommands,
          BusinessKindCommands
        >
    with $Provider<BusinessKindCommands> {
  /// What the kind chooser does.
  BusinessKindCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessKindCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessKindCommandsHash();

  @$internal
  @override
  $ProviderElement<BusinessKindCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessKindCommands create(Ref ref) {
    return businessKindCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessKindCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessKindCommands>(value),
    );
  }
}

String _$businessKindCommandsHash() =>
    r'2af1ec173c905963f443e2c0507542a616dfda0f';
