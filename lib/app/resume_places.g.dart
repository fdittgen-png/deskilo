// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_places.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in account's places as the device kept them; null when there
/// are none, they are unreadable, or they are somebody else's.

@ProviderFor(storedResumePlaces)
final storedResumePlacesProvider = StoredResumePlacesProvider._();

/// The signed-in account's places as the device kept them; null when there
/// are none, they are unreadable, or they are somebody else's.

final class StoredResumePlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResumePlaces?>,
          ResumePlaces?,
          FutureOr<ResumePlaces?>
        >
    with $FutureModifier<ResumePlaces?>, $FutureProvider<ResumePlaces?> {
  /// The signed-in account's places as the device kept them; null when there
  /// are none, they are unreadable, or they are somebody else's.
  StoredResumePlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storedResumePlacesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storedResumePlacesHash();

  @$internal
  @override
  $FutureProviderElement<ResumePlaces?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ResumePlaces?> create(Ref ref) {
    return storedResumePlaces(ref);
  }
}

String _$storedResumePlacesHash() =>
    r'ee74a09ee35fcdf58e8f5854234d3acd9de23f13';

@ProviderFor(startPlace)
final startPlaceProvider = StartPlaceProvider._();

final class StartPlaceProvider
    extends $FunctionalProvider<StartPlace, StartPlace, StartPlace>
    with $Provider<StartPlace> {
  StartPlaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startPlaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startPlaceHash();

  @$internal
  @override
  $ProviderElement<StartPlace> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StartPlace create(Ref ref) {
    return startPlace(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartPlace value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartPlace>(value),
    );
  }
}

String _$startPlaceHash() => r'78b8f710c6eb1ff40c40e364dedd1bbd4881c672';

@ProviderFor(resumeKeeper)
final resumeKeeperProvider = ResumeKeeperProvider._();

final class ResumeKeeperProvider
    extends $FunctionalProvider<ResumeKeeper, ResumeKeeper, ResumeKeeper>
    with $Provider<ResumeKeeper> {
  ResumeKeeperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumeKeeperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumeKeeperHash();

  @$internal
  @override
  $ProviderElement<ResumeKeeper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ResumeKeeper create(Ref ref) {
    return resumeKeeper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResumeKeeper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResumeKeeper>(value),
    );
  }
}

String _$resumeKeeperHash() => r'1202321aff9c2f1e347360209ebf6c68bb0d588a';
