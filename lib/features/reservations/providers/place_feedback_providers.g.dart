// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_feedback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(placeFeedbackRepository)
final placeFeedbackRepositoryProvider = PlaceFeedbackRepositoryProvider._();

final class PlaceFeedbackRepositoryProvider
    extends
        $FunctionalProvider<
          PlaceFeedbackRepository,
          PlaceFeedbackRepository,
          PlaceFeedbackRepository
        >
    with $Provider<PlaceFeedbackRepository> {
  PlaceFeedbackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeFeedbackRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeFeedbackRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlaceFeedbackRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaceFeedbackRepository create(Ref ref) {
    return placeFeedbackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaceFeedbackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaceFeedbackRepository>(value),
    );
  }
}

String _$placeFeedbackRepositoryHash() =>
    r'10ad06634f0d70b2b5ab9fd90811ee0133394a5a';

/// Whether the active workspace shows favourites and ratings to this
/// person: the feature is on and they may use reservations.

@ProviderFor(placeFeedbackAvailable)
final placeFeedbackAvailableProvider = PlaceFeedbackAvailableProvider._();

/// Whether the active workspace shows favourites and ratings to this
/// person: the feature is on and they may use reservations.

final class PlaceFeedbackAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the active workspace shows favourites and ratings to this
  /// person: the feature is on and they may use reservations.
  PlaceFeedbackAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeFeedbackAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeFeedbackAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return placeFeedbackAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$placeFeedbackAvailableHash() =>
    r'ec39115f5e65a8c84ef056975b431025e384f687';

/// One place's feedback, in the active workspace.

@ProviderFor(placeFeedback)
final placeFeedbackProvider = PlaceFeedbackFamily._();

/// One place's feedback, in the active workspace.

final class PlaceFeedbackProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaceFeedback>,
          PlaceFeedback,
          FutureOr<PlaceFeedback>
        >
    with $FutureModifier<PlaceFeedback>, $FutureProvider<PlaceFeedback> {
  /// One place's feedback, in the active workspace.
  PlaceFeedbackProvider._({
    required PlaceFeedbackFamily super.from,
    required (PlaceKind, String) super.argument,
  }) : super(
         retry: null,
         name: r'placeFeedbackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placeFeedbackHash();

  @override
  String toString() {
    return r'placeFeedbackProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PlaceFeedback> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlaceFeedback> create(Ref ref) {
    final argument = this.argument as (PlaceKind, String);
    return placeFeedback(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaceFeedbackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placeFeedbackHash() => r'c4cb61bfdcdf67a0ccca1d4c76c4f283873bf15e';

/// One place's feedback, in the active workspace.

final class PlaceFeedbackFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PlaceFeedback>,
          (PlaceKind, String)
        > {
  PlaceFeedbackFamily._()
    : super(
        retry: null,
        name: r'placeFeedbackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One place's feedback, in the active workspace.

  PlaceFeedbackProvider call(PlaceKind kind, String id) =>
      PlaceFeedbackProvider._(argument: (kind, id), from: this);

  @override
  String toString() => r'placeFeedbackProvider';
}

/// The favourites of the active workspace.

@ProviderFor(myFavoritePlaces)
final myFavoritePlacesProvider = MyFavoritePlacesProvider._();

/// The favourites of the active workspace.

final class MyFavoritePlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FavoritePlace>>,
          List<FavoritePlace>,
          FutureOr<List<FavoritePlace>>
        >
    with
        $FutureModifier<List<FavoritePlace>>,
        $FutureProvider<List<FavoritePlace>> {
  /// The favourites of the active workspace.
  MyFavoritePlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myFavoritePlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myFavoritePlacesHash();

  @$internal
  @override
  $FutureProviderElement<List<FavoritePlace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FavoritePlace>> create(Ref ref) {
    return myFavoritePlaces(ref);
  }
}

String _$myFavoritePlacesHash() => r'800d3ae82b909ebcca74e0c612db29e23793561c';
