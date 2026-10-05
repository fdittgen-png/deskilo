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

/// Whether the directory can show a workspace's feedback: it lives on this
/// installation (a workspace of another server has no feedback here).

@ProviderFor(directorySourceIsLocal)
final directorySourceIsLocalProvider = DirectorySourceIsLocalProvider._();

/// Whether the directory can show a workspace's feedback: it lives on this
/// installation (a workspace of another server has no feedback here).

final class DirectorySourceIsLocalProvider
    extends
        $FunctionalProvider<
          bool Function(String source),
          bool Function(String source),
          bool Function(String source)
        >
    with $Provider<bool Function(String source)> {
  /// Whether the directory can show a workspace's feedback: it lives on this
  /// installation (a workspace of another server has no feedback here).
  DirectorySourceIsLocalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directorySourceIsLocalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directorySourceIsLocalHash();

  @$internal
  @override
  $ProviderElement<bool Function(String source)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  bool Function(String source) create(Ref ref) {
    return directorySourceIsLocal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool Function(String source) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool Function(String source)>(value),
    );
  }
}

String _$directorySourceIsLocalHash() =>
    r'20cc4004480562ccd3bfbdbdd204969d11a1a624';

@ProviderFor(placeFeedbackBatcher)
final placeFeedbackBatcherProvider = PlaceFeedbackBatcherProvider._();

final class PlaceFeedbackBatcherProvider
    extends
        $FunctionalProvider<
          PlaceFeedbackBatcher,
          PlaceFeedbackBatcher,
          PlaceFeedbackBatcher
        >
    with $Provider<PlaceFeedbackBatcher> {
  PlaceFeedbackBatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placeFeedbackBatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placeFeedbackBatcherHash();

  @$internal
  @override
  $ProviderElement<PlaceFeedbackBatcher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaceFeedbackBatcher create(Ref ref) {
    return placeFeedbackBatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaceFeedbackBatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaceFeedbackBatcher>(value),
    );
  }
}

String _$placeFeedbackBatcherHash() =>
    r'704cffd2ec52e8be943aac089a64a7c13fbba43e';

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

String _$placeFeedbackHash() => r'9a8894bd50029106805f7c20381dbc42761cedc1';

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
